$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $projectRoot 'tools\Find-MatlabFiles.ps1'
$sourceRoot = 'C:\Users\e_cri\OneDrive\Documents\PhD\Investigacion\MATLAB\Scripts_analisis'
$outputPath = Join-Path $projectRoot 'inventory\TEST_MATLAB_FILES.md'

if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Expected inventory script was not found: $scriptPath"
}

$verboseMessages = @(& $scriptPath -RootPath $sourceRoot -OutputPath $outputPath -Verbose 4>&1 |
    Where-Object { $_ -is [System.Management.Automation.VerboseRecord] } |
    ForEach-Object { $_.Message })

foreach ($requiredMessage in @('Searching recursively for .m, .mat, and .mlx files', 'Found ', 'Writing Markdown report', 'Inventory complete')) {
    if (-not ($verboseMessages | Where-Object { $_ -like "*$requiredMessage*" })) {
        throw "Expected verbose feedback was not emitted: $requiredMessage"
    }
}

if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
    throw "Expected Markdown report was not created: $outputPath"
}

$report = Get-Content -LiteralPath $outputPath -Raw
foreach ($requiredText in @('# MATLAB file inventory', '.m', '.mat', '.mlx', 'Live_scripts/analysis_daphne_data.mlx')) {
    if ($report -notmatch [regex]::Escape($requiredText)) {
        throw "Report does not contain required text: $requiredText"
    }
}

Write-Host 'PASS: Find-MatlabFiles.ps1 generated a valid Markdown inventory.'
