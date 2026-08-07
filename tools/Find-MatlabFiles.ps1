<#
.SYNOPSIS
Creates a Markdown inventory of MATLAB .m, .mat, and .mlx files below a directory.

.DESCRIPTION
Searches the selected root directory recursively, records every .m, .mat, and .mlx file,
and writes a Markdown table with paths relative to the root, file type, size, and last-modified time.
The source tree is only read; no source file is moved, renamed, or edited.

.EXAMPLE
.\Find-MatlabFiles.ps1 -RootPath 'C:\path\to\MATLAB' -OutputPath 'C:\path\to\MATLAB_FILES.md'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$RootPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$extensions = @('.m', '.mat', '.mlx')

if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
    throw "Root directory does not exist: $RootPath"
}

$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path.TrimEnd('\', '/')
Write-Verbose "Searching recursively for .m, .mat, and .mlx files under: $resolvedRoot"
$outputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$files = Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Force |
    Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
    Sort-Object -Property FullName
Write-Verbose "Found $($files.Count) matching MATLAB files."

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# MATLAB file inventory')
$lines.Add('')
$lines.Add("- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K')")
$lines.Add(('- Root directory: `{0}`' -f $resolvedRoot))
$lines.Add("- Extensions: $($extensions -join ', ')")
$lines.Add("- Total files: $($files.Count)")
$lines.Add('')
$lines.Add('| Relative path | Extension | Size (bytes) | Last modified |')
$lines.Add('|---|---|---:|---|')

foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($resolvedRoot.Length).TrimStart('\', '/') -replace '\\', '/'
    $safePath = $relativePath -replace '\|', '\\|'
    $lines.Add(('| `{0}` | `{1}` | {2} | {3:yyyy-MM-dd HH:mm:ss} |' -f $safePath, $file.Extension, $file.Length, $file.LastWriteTime))
}

Write-Verbose "Writing Markdown report to: $OutputPath"
Set-Content -LiteralPath $OutputPath -Value $lines -Encoding UTF8
Write-Verbose "Inventory complete: wrote $($files.Count) entries."
Write-Host "Wrote $($files.Count) MATLAB file entries to: $OutputPath"
