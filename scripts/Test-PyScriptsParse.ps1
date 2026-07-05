#requires -Version 7.4
<#
.SYNOPSIS
    Parses repository Python scripts without generating bytecode.

.DESCRIPTION
    Checks scripts/*.py using Python ast.parse. This is a syntax-only gate and
    intentionally avoids py_compile so it does not write __pycache__/*.pyc.
#>

[CmdletBinding()]
param(
    [string]$RootPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,

    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RelativeDisplayPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$TargetPath
    )

    return [System.IO.Path]::GetRelativePath(
        [System.IO.Path]::GetFullPath($BasePath),
        [System.IO.Path]::GetFullPath($TargetPath)
    )
}

function Get-PythonExecutable {
    $python = Get-Command python -ErrorAction SilentlyContinue
    if ($null -ne $python) {
        return $python.Source
    }

    $py = Get-Command py -ErrorAction SilentlyContinue
    if ($null -ne $py) {
        return $py.Source
    }

    return $null
}

$resolvedRoot = (Resolve-Path -LiteralPath $RootPath).Path
$scriptsPath = Join-Path $resolvedRoot "scripts"

if (-not (Test-Path -LiteralPath $scriptsPath -PathType Container)) {
    throw "scripts directory not found: $scriptsPath"
}

$files = @(Get-ChildItem -LiteralPath $scriptsPath -File -Filter "*.py" | Sort-Object FullName)
$findings = [System.Collections.Generic.List[object]]::new()
$pythonPath = Get-PythonExecutable

if ($null -eq $pythonPath) {
    foreach ($file in $files) {
        $findings.Add([pscustomobject]@{
            file    = Get-RelativeDisplayPath -BasePath $resolvedRoot -TargetPath $file.FullName
            line    = $null
            column  = $null
            message = "Python executable not found; cannot parse Python scripts."
        }) | Out-Null
    }
} else {
    $parserCode = @'
import ast
import json
import pathlib
import sys

paths = sys.argv[1:]
findings = []
for raw_path in paths:
    path = pathlib.Path(raw_path)
    try:
        text = path.read_text(encoding="utf-8-sig")
        ast.parse(text, filename=str(path))
    except SyntaxError as exc:
        findings.append({
            "file": str(path),
            "line": exc.lineno,
            "column": exc.offset,
            "message": exc.msg,
        })
    except Exception as exc:
        findings.append({
            "file": str(path),
            "line": None,
            "column": None,
            "message": f"{type(exc).__name__}: {exc}",
        })

print(json.dumps(findings, ensure_ascii=False))
sys.exit(1 if findings else 0)
'@

    # Sob StrictMode, $files.FullName lanca quando $files e array vazio (scripts/ sem
    # nenhum .py). Materializar os caminhos por ForEach-Object e seguro com zero itens.
    $filePaths = @($files | ForEach-Object { $_.FullName })
    $parserOutput = & $pythonPath -c $parserCode @filePaths 2>&1
    $parserExitCode = $LASTEXITCODE
    $parserText = ($parserOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine

    if ([string]::IsNullOrWhiteSpace($parserText)) {
        if ($parserExitCode -ne 0) {
            $findings.Add([pscustomobject]@{
                file    = $null
                line    = $null
                column  = $null
                message = "Python parser failed without output."
            }) | Out-Null
        }
    } else {
        try {
            $rawFindings = @($parserText | ConvertFrom-Json)
            foreach ($rawFinding in $rawFindings) {
                $displayFile = $rawFinding.file
                if (-not [string]::IsNullOrWhiteSpace($displayFile)) {
                    $displayFile = Get-RelativeDisplayPath -BasePath $resolvedRoot -TargetPath $displayFile
                }

                $findings.Add([pscustomobject]@{
                    file    = $displayFile
                    line    = $rawFinding.line
                    column  = $rawFinding.column
                    message = $rawFinding.message
                }) | Out-Null
            }
        } catch {
            $findings.Add([pscustomobject]@{
                file    = $null
                line    = $null
                column  = $null
                message = "Python parser returned non-JSON output: $parserText"
            }) | Out-Null
        }
    }
}

$result = [ordered]@{
    rootPath   = $resolvedRoot
    status     = if ($findings.Count -eq 0) { "pass" } else { "fail" }
    fileCount  = $files.Count
    errorCount = $findings.Count
    findings   = @($findings)
}

if ($AsJson) {
    [pscustomobject]$result | ConvertTo-Json -Depth 6
} else {
    foreach ($finding in $findings) {
        "PY_PARSE_ERROR: {0}:{1}:{2}: {3}" -f $finding.file, $finding.line, $finding.column, $finding.message
    }
    "FILES={0}; ERRORS={1}" -f $files.Count, $findings.Count
}

if ($findings.Count -gt 0) {
    exit 1
}
