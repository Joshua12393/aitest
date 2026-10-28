param(
    [ValidateRange(1024, 65535)][int]$Port = 8080
)
$ErrorActionPreference = 'Stop'
$plannerRuntime = Join-Path $PSScriptRoot '..\task_planner\.tools\swipl\bin\swipl.exe'
if (-not (Test-Path -LiteralPath $plannerRuntime)) {
    $plannerCommand = Get-Command swipl -ErrorAction SilentlyContinue
    if (-not $plannerCommand) { throw 'Install SWI-Prolog or restore the local task_planner runtime.' }
    $plannerRuntime = $plannerCommand.Source
}
& $plannerRuntime -q -s (Join-Path $PSScriptRoot 'server.pl') -- $Port
exit $LASTEXITCODE
