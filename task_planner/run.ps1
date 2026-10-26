param(
    [ValidateSet('menu', 'demo', 'test', 'check')]
    [string]$Mode = 'menu'
)

$ErrorActionPreference = 'Stop'
$taskLocalRuntime = Join-Path $PSScriptRoot '.tools\swipl\bin\swipl.exe'
if (Test-Path -LiteralPath $taskLocalRuntime) {
    $taskProlog = $taskLocalRuntime
} else {
    $taskInstalledRuntime = Get-Command swipl -ErrorAction SilentlyContinue
    if (-not $taskInstalledRuntime) {
        throw 'SWI-Prolog is required. See README.md for installation and direct commands.'
    }
    $taskProlog = $taskInstalledRuntime.Source
}

$taskSource = Join-Path $PSScriptRoot 'proj.pl'
switch ($Mode) {
    'menu'  { $taskGoal = 'main' }
    'demo'  { $taskGoal = 'demo' }
    'test'  { $taskSource = Join-Path $PSScriptRoot 'tests.pl'; $taskGoal = 'run_tests' }
    'check' { $taskGoal = 'validate_kb(E),writeln(E),E=[],knowledge_stats(S),writeln(S)' }
}

& $taskProlog -q -s $taskSource -g $taskGoal -t halt
exit $LASTEXITCODE
