# Isolated HTTP integration checks. Requires PowerShell 7+.
$ErrorActionPreference = 'Stop'
$plannerRuntime = Join-Path $PSScriptRoot '..\task_planner\.tools\swipl\bin\swipl.exe'
if (-not (Test-Path -LiteralPath $plannerRuntime)) { $plannerRuntime = (Get-Command swipl -ErrorAction Stop).Source }
$plannerTestDir = Join-Path ([IO.Path]::GetTempPath()) ('daywise-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $plannerTestDir | Out-Null
$plannerStateFile = Join-Path $plannerTestDir 'state.json'
$plannerOutput = Join-Path $plannerTestDir 'stdout.log'
$plannerErrors = Join-Path $plannerTestDir 'stderr.log'
$plannerOldEnv = $env:PLANNER_STATE
$plannerListener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$plannerListener.Start()
$plannerPort = $plannerListener.LocalEndpoint.Port
$plannerListener.Stop()
$plannerBase = "http://127.0.0.1:$plannerPort"
$plannerProcess = $null
$plannerChecks = 0

function Assert-Planner($Condition, $Message) {
    if (-not $Condition) { throw $Message }
    $script:plannerChecks++
}
function Start-TestPlanner {
    $env:PLANNER_STATE = $plannerStateFile
    try {
        $plannerServerFile = Join-Path $PSScriptRoot 'server.pl'
        $script:plannerProcess = Start-Process -FilePath $plannerRuntime -ArgumentList @('-q', '-s', ('"' + $plannerServerFile + '"'), '--', $plannerPort) -WindowStyle Hidden -PassThru -RedirectStandardOutput $plannerOutput -RedirectStandardError $plannerErrors
    } finally { $env:PLANNER_STATE = $plannerOldEnv }
    for ($plannerAttempt = 0; $plannerAttempt -lt 10; $plannerAttempt++) {
        if ($script:plannerProcess.HasExited) { throw (Get-Content -LiteralPath $plannerErrors -Raw) }
        try { Invoke-RestMethod "$plannerBase/api/state" -TimeoutSec 3 | Out-Null; return } catch { $plannerStartupError = $_.Exception.Message; Start-Sleep -Milliseconds 100 }
    }
    throw "Test server did not start: $plannerStartupError`n$(Get-Content -LiteralPath $plannerOutput -Raw)`n$(Get-Content -LiteralPath $plannerErrors -Raw)"
}
function Post-Planner($Path, $Body, $Expected = 200, $Headers = @{}) {
    $plannerResponse = Invoke-WebRequest ($plannerBase + $Path) -Method Post -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 10 -Compress) -Headers $Headers -SkipHttpErrorCheck
    Assert-Planner ($plannerResponse.StatusCode -eq $Expected) "$Path expected $Expected, got $($plannerResponse.StatusCode): $($plannerResponse.Content)"
}
try {
    Start-TestPlanner
    $plannerState = Invoke-RestMethod "$plannerBase/api/state"
    Assert-Planner ($plannerState.tasks.Count -eq 0 -and $plannerState.classes.Count -eq 0) 'Initial user data must be blank.'
    Assert-Planner ($plannerState.system_fact_count -eq 120 -and $plannerState.types.Count -eq 20) 'Knowledge count mismatch.'
    foreach ($plannerExample in @(@{title='Finish AI Assignment';type='assignment';days_left=1;minutes=60},@{title='Read Research Paper';type='reading';days_left=4;minutes=30},@{title='Clean project files';type='cleaning';days_left=10;minutes=45})) {
        Post-Planner '/api/tasks' $plannerExample 201
    }
    Post-Planner '/api/classes' @{subject='Computer Networks';day='monday';start=480;end=600} 201
    $plannerState = Invoke-RestMethod "$plannerBase/api/state?minutes=30"
    Assert-Planner (($plannerState.tasks.bucket -join ',') -eq 'do_first,do_next,do_later') 'Specification grouping failed.'
    Assert-Planner (-not $plannerState.tasks[0].fits_time -and $plannerState.tasks[1].fits_time) 'Time-fit boundary failed.'
    $plannerTaskId = $plannerState.tasks[0].id
    $plannerClassId = $plannerState.classes[0].id
    Post-Planner '/api/task_status' @{id=$plannerTaskId;status='completed'}
    $plannerState = Invoke-RestMethod "$plannerBase/api/state"
    Assert-Planner ($plannerState.tasks[0].bucket -eq 'completed') 'Completion failed.'
    Post-Planner '/api/task_status' @{id=$plannerTaskId;status='pending'}
    Post-Planner '/api/tasks' @{title='Bad';type='unknown';days_left=1;minutes=20} 400
    Post-Planner '/api/classes' @{subject='Bad';day='monday';start=600;end=480} 400
    Post-Planner '/api/task_status' @{id='missing';status='completed'} 400
    Post-Planner '/api/tasks' @{} 403 @{Origin='https://untrusted.example'}
    $plannerBadQuery = Invoke-WebRequest "$plannerBase/api/state?minutes=abc" -SkipHttpErrorCheck
    Assert-Planner ($plannerBadQuery.StatusCode -eq 400) 'Invalid query should be 400.'
    $plannerBadJSON = Invoke-WebRequest "$plannerBase/api/tasks" -Method Post -ContentType 'application/json' -Body '{' -SkipHttpErrorCheck
    Assert-Planner ($plannerBadJSON.StatusCode -eq 400) 'Malformed JSON should be 400.'
    Stop-Process -Id $plannerProcess.Id
    $plannerProcess.WaitForExit()
    Start-TestPlanner
    $plannerReloaded = Invoke-RestMethod "$plannerBase/api/state"
    Assert-Planner ($plannerReloaded.tasks.Count -eq 3 -and $plannerReloaded.classes.Count -eq 1) 'Restart persistence failed.'
    Assert-Planner ($plannerReloaded.tasks[0].id -eq $plannerTaskId) 'Saved IDs changed.'
    Post-Planner '/api/delete_task' @{id=$plannerTaskId}
    Post-Planner '/api/delete_class' @{id=$plannerClassId}
    $plannerDeleted = Invoke-RestMethod "$plannerBase/api/state"
    Assert-Planner ($plannerDeleted.tasks.Count -eq 2 -and $plannerDeleted.classes.Count -eq 0) 'Delete failed.'
    Post-Planner '/api/classes' @{subject='Weekly Networks';days=@('monday','wednesday','friday');start=480;end=600} 201
    $plannerMultiDay = Invoke-RestMethod "$plannerBase/api/state"
    Assert-Planner (($plannerMultiDay.classes.day -join ',') -eq 'monday,wednesday,friday') 'Multiple class days were not saved.'
    Post-Planner '/api/classes' @{subject='Weekly Networks';days=@('tuesday','wednesday');start=480;end=600} 400
    Post-Planner '/api/classes' @{subject='Bad';days=@();start=480;end=600} 400
    Post-Planner '/api/classes' @{subject='Bad';days=@('tuesday','noday');start=480;end=600} 400
    $plannerUnchanged = Invoke-RestMethod "$plannerBase/api/state"
    Assert-Planner ($plannerUnchanged.classes.Count -eq 3 -and 'tuesday' -notin $plannerUnchanged.classes.day) 'Failed multi-day addition left partial records.'
    # Reproduce a future day's class -> class -> review -> class -> review order.
    foreach ($plannerTask in $plannerUnchanged.tasks) { Post-Planner '/api/delete_task' @{id=$plannerTask.id} }
    foreach ($plannerClass in $plannerUnchanged.classes) { Post-Planner '/api/delete_class' @{id=$plannerClass.id} }
    $plannerToday = [datetime]::ParseExact($plannerUnchanged.today,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture)
    $plannerTomorrow = $plannerToday.AddDays(1)
    $plannerSelected = $plannerTomorrow.ToString('yyyy-MM-dd')
    Post-Planner '/api/planning' @{day_start=480;day_end=1320}
    Post-Planner '/api/classes' @{subject='Busy today';day=$plannerToday.DayOfWeek.ToString().ToLowerInvariant();start=480;end=1320} 201
    foreach ($plannerClass in @(@{subject='Networks';start=480;end=540},@{subject='AI';start=540;end=600},@{subject='Software';start=660;end=720})) {
        Post-Planner '/api/classes' @{subject=$plannerClass.subject;day=$plannerTomorrow.DayOfWeek.ToString().ToLowerInvariant();start=$plannerClass.start;end=$plannerClass.end} 201
    }
    Post-Planner '/api/tasks' @{title='Review Networks quiz';type='exam_review';subject='Networks';days_left=2;deadline_time=0;minutes=180} 201
    $plannerSequence = Invoke-RestMethod "$plannerBase/api/state?date=$plannerSelected"
    Assert-Planner (($plannerSequence.timeline.events.kind -join ',') -eq 'class,class,task,class,task,free') 'Selected date timeline is not chronological.'
    Assert-Planner ($plannerSequence.plan.sessions.Count -eq 2 -and $plannerSequence.plan.sessions[0].start -eq 600 -and $plannerSequence.plan.sessions[0].end -eq 660 -and $plannerSequence.plan.sessions[1].start -eq 720 -and $plannerSequence.plan.sessions[1].end -eq 840) 'Three-hour review did not split around classes.'
    Post-Planner '/api/planning' @{day_start=480;day_end=780}
    $plannerShort = Invoke-RestMethod "$plannerBase/api/state?date=$plannerSelected"
    Assert-Planner ($plannerShort.plan.tasks[0].unscheduled_minutes -eq 60) 'Missing review time was not reported.'
    Post-Planner '/api/planning' @{day_start=1320;day_end=480} 400
    Post-Planner '/api/tasks' @{title='Bad time';type='exam_review';days_left=2;deadline_time=1440;minutes=60} 400
    $plannerBadDate = Invoke-WebRequest "$plannerBase/api/state?date=2026-02-30" -SkipHttpErrorCheck
    Assert-Planner ($plannerBadDate.StatusCode -eq 400) 'Invalid selected date must be rejected.'
    Post-Planner '/api/planning' @{day_start=480;day_end=1320}
    $plannerReviewId = $plannerSequence.tasks[0].id
    Post-Planner '/api/session' @{task_id=$plannerReviewId;date=$plannerSelected;start=900;end=960}
    $plannerMoved = Invoke-RestMethod "$plannerBase/api/state?date=$plannerSelected"
    $plannerFixed = @($plannerMoved.plan.sessions | Where-Object manual_id)[0]
    Assert-Planner ($plannerFixed.start -eq 900 -and $plannerMoved.plan.tasks[0].scheduled_minutes -eq 180) 'Move changed the required review duration.'
    Post-Planner '/api/session' @{id=$plannerFixed.manual_id;task_id=$plannerReviewId;date=$plannerSelected;start=960;end=1020}
    Post-Planner '/api/session' @{task_id=$plannerReviewId;date=$plannerSelected;start=990;end=1050} 400
    Post-Planner '/api/session' @{id=$plannerFixed.manual_id;task_id=$plannerReviewId;date=$plannerSelected;start=480;end=540} 400
    Post-Planner '/api/session' @{task_id=$plannerReviewId;date=$plannerSelected;start=1050;end=1320} 400
    Post-Planner '/api/session' @{task_id=$plannerReviewId;date=$plannerTomorrow.AddDays(1).ToString('yyyy-MM-dd');start=480;end=540} 400
    $plannerClassEdit = @($plannerMoved.classes | Where-Object { $_.subject -eq 'Networks' })[0]
    Post-Planner '/api/edit_class' @{id=$plannerClassEdit.id;subject='Networks edited';day=$plannerClassEdit.day;start=960;end=1020} 400
    Post-Planner '/api/edit_class' @{id=$plannerClassEdit.id;subject='Networks edited';day=$plannerClassEdit.day;start=480;end=530}
    Post-Planner '/api/planning' @{day_start=480;day_end=1000} 400
    Post-Planner '/api/tasks' @{title='Exact date task';is_review=$false;due_date=$plannerSelected;deadline_time=1300;minutes=30} 201
    Post-Planner '/api/tasks' @{title='Exact date quiz';is_review=$true;due_date=$plannerSelected;deadline_time=1320;minutes=90} 201
    Post-Planner '/api/tasks' @{title='Bad date';is_review=$true;due_date='2026-02-30';deadline_time=1320;minutes=90} 400
    Stop-Process -Id $plannerProcess.Id
    $plannerProcess.WaitForExit()
    Start-TestPlanner
    $plannerEdited = Invoke-RestMethod "$plannerBase/api/state?date=$plannerSelected"
    $plannerFixedAgain = @($plannerEdited.plan.sessions | Where-Object manual_id)
    Assert-Planner ($plannerFixedAgain.Count -eq 1 -and $plannerFixedAgain[0].start -eq 960) 'Edited work did not persist exactly once.'
    Assert-Planner (@($plannerEdited.classes | Where-Object { $_.id -eq $plannerClassEdit.id -and $_.subject -eq 'Networks edited' -and $_.end -eq 530 }).Count -eq 1) 'Class edit did not persist with its ID.'
    Assert-Planner (@($plannerEdited.tasks | Where-Object { $_.title -eq 'Exact date quiz' -and $_.type -eq 'exam_review' -and $_.deadline_time -eq 1320 -and $_.due_date -eq $plannerSelected }).Count -eq 1) 'Exact quiz deadline did not persist.'
    Post-Planner '/api/delete_session' @{id=$plannerFixed.manual_id}
    $plannerAutomatic = Invoke-RestMethod "$plannerBase/api/state"
    Assert-Planner (@($plannerAutomatic.plan.sessions | Where-Object manual_id).Count -eq 0) 'Return to automatic left a fixed session.'
    $plannerHTML = Invoke-WebRequest $plannerBase
    Assert-Planner ($plannerHTML.Content.Contains('Your next steps')) 'Frontend did not load.'
    Write-Output "$plannerChecks HTTP integration checks passed, including restart persistence."
} finally {
    $env:PLANNER_STATE = $plannerOldEnv
    if ($plannerProcess -and -not $plannerProcess.HasExited) { Stop-Process -Id $plannerProcess.Id; $plannerProcess.WaitForExit() }
    foreach ($plannerTempFile in @($plannerStateFile, ($plannerStateFile + '.tmp'), $plannerOutput, $plannerErrors)) {
        if (Test-Path -LiteralPath $plannerTempFile) { Remove-Item -LiteralPath $plannerTempFile -Force }
    }
    Remove-Item -LiteralPath $plannerTestDir -Force
}
