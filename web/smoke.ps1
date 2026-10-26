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
