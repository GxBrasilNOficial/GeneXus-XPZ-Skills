#requires -Version 7.4
<#
.SYNOPSIS
    Funcoes compartilhadas do backend codex da skill xpz-llm-delegate: descoberta do
    binario do Codex CLI, TempDir absoluto, KeepDays por classe e identidade de processo.
.DESCRIPTION
    Modulo dot-source consumido por Invoke-Codex.ps1, Start-CodexJob.ps1 e Watch-CodexJob.ps1.
    Sem efeitos colaterais alem de invocar `codex --version` nos candidatos (descoberta)
    e IO local sob o TempDir de jobs quando KeepDays/TempDir sao usados.

    DESCOBERTA (fail-closed): o shim npm no PATH (Roaming\npm) pode estar antigo e e
    rejeitado pelo servidor para modelos novos. Por isso a descoberta ignora o PATH e usa
    os binarios da app desktop OpenAI Codex sob %LOCALAPPDATA%\OpenAI\Codex\bin.
    O executavel canonico bin\codex.exe prevalece quando responde a --version. Diretorios
    backup-* nunca participam. Somente quando o canonico estiver ausente ou invalido a
    descoberta recorre aos subdiretorios nao-backup e escolhe a maior versao utilizavel.
    Sem candidato utilizavel -> BLOCK com instrucao.

    TempDir: Resolve-CodexJobTempDir -Override (nulo/branco = unbound) -> env
    XPZ_CODEX_JOBS_DIR -> %TEMP%\codex-jobs; sempre GetFullPath e cria a pasta.
    KeepDays: classes A/B/C-codex/C-shared; best-effort (nao lanca para Start/Invoke).
    Resolve-CodexPidAndStartTime: merge campo-a-campo; nunca lanca 22.

    Contrato validado por Test-CodexCliSupportSelfTest.ps1 e Test-CodexDurableCaptureSelfTest.ps1.

.PARAMETER TempDir
    Nos adapters, -TempDir nao tem default no param(); o default efetivo vive neste helper
    (-Override nulo/branco -> env -> %TEMP%\codex-jobs).
#>

Set-StrictMode -Version Latest

function Get-CodexExeVersion {
    # Le 'codex-cli X.Y.Z[-alpha.N]' e devolve [version] X.Y.Z (ignora sufixo pre-release).
    param([string]$ExePath)
    try {
        $raw = & $ExePath --version 2>$null
        $line = @($raw)[0]
        $m = [regex]::Match([string]$line, '(\d+)\.(\d+)\.(\d+)')
        if ($m.Success) {
            return [version]("{0}.{1}.{2}" -f $m.Groups[1].Value, $m.Groups[2].Value, $m.Groups[3].Value)
        }
    } catch { }
    return $null
}

function Get-CodexExeCandidatePaths {
    param([Parameter(Mandatory)] [string] $BasePath)

    $paths = [System.Collections.Generic.List[string]]::new()
    $canonical = Join-Path $BasePath 'codex.exe'
    if (Test-Path -LiteralPath $canonical -PathType Leaf) {
        $paths.Add($canonical)
    }

    $fallbackDirs = @(Get-ChildItem -LiteralPath $BasePath -Directory -ErrorAction SilentlyContinue |
        Where-Object { -not $_.Name.StartsWith('backup-', [System.StringComparison]::OrdinalIgnoreCase) })
    foreach ($dir in $fallbackDirs) {
        $nested = @(Get-ChildItem -LiteralPath $dir.FullName -Recurse -Filter 'codex.exe' -File -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName)
        foreach ($candidate in $nested) {
            $paths.Add([string]$candidate)
        }
    }

    return @($paths)
}

function Resolve-CodexExe {
    # Devolve o caminho do codex.exe a usar. -Override forca um caminho explicito.
    # -BasePath e seam deterministico de self-test; adapters usam o default da app.
    param(
        [string] $Override,
        [string] $BasePath
    )

    if ($Override) {
        if (Test-Path -LiteralPath $Override -PathType Leaf) { return $Override }
        throw "BLOCK: -CodexExe informado nao existe: $Override"
    }

    $base = if ($BasePath) { $BasePath } else { Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin' }
    if (-not (Test-Path -LiteralPath $base -PathType Container)) {
        throw "BLOCK: pasta de binarios da app OpenAI Codex nao encontrada: $base. Instale/atualize a app ou o CLI do Codex (o shim npm e rejeitado para gpt-5.5)."
    }

    $candidates = @(Get-CodexExeCandidatePaths -BasePath $base)
    if ($candidates.Count -eq 0) {
        throw "BLOCK: nenhum codex.exe encontrado sob $base. Atualize a app/CLI do Codex."
    }

    $canonical = Join-Path $base 'codex.exe'
    if ($candidates -contains $canonical) {
        $canonicalVersion = Get-CodexExeVersion $canonical
        if ($null -ne $canonicalVersion) {
            return $canonical
        }
    }

    $best = $null; $bestVer = $null
    foreach ($c in $candidates) {
        if ([string]::Equals($c, $canonical, [System.StringComparison]::OrdinalIgnoreCase)) { continue }
        $v = Get-CodexExeVersion $c
        if ($null -eq $v) { continue }
        if ($null -eq $bestVer -or $v -gt $bestVer) { $bestVer = $v; $best = $c }
    }
    if (-not $best) {
        throw "BLOCK: nenhum codex.exe utilizavel respondeu a --version sob $base. Atualize a app/CLI do Codex."
    }
    return $best
}

function Get-CodexExecErrorMessage {
    # Extrai mensagem de erro do stdout/stderr do `codex exec` quando o servidor rejeita o
    # pedido (ex: modelo nao suportado, cota/rate-limit, autenticacao). Suporta:
    # 1. Linhas 'ERROR: {json}' ou JSON de erro nativo da API sem prefixo 'ERROR:'
    # 2. Linhas 'ERROR: <texto>'
    # 3. Sentinelas de cota, taxa, saldo, autenticacao e servico indisponivel em stdout/stderr.
    param([string]$StdoutText, [string]$StderrText)
    $combined = @($StdoutText, $StderrText) -join "`n"
    if ([string]::IsNullOrWhiteSpace($combined)) { return $null }

    # 1. Linhas com prefixo ERROR: e JSON
    $jsonMatches = [regex]::Matches($combined, 'ERROR:\s*(\{.*\})')
    if ($jsonMatches.Count -gt 0) {
        $jsonText = $jsonMatches[$jsonMatches.Count - 1].Groups[1].Value
        try {
            $obj = $jsonText | ConvertFrom-Json
            $msg = $null
            if ($obj.PSObject.Properties['error']) {
                if ($obj.error -is [string]) { $msg = [string]$obj.error }
                elseif ($obj.error.PSObject.Properties['message']) { $msg = [string]$obj.error.message }
            } elseif ($obj.PSObject.Properties['message']) {
                $msg = [string]$obj.message
            }
            if (-not [string]::IsNullOrWhiteSpace($msg)) { return $msg.Trim() }
        } catch { }
        return $jsonText.Trim()
    }

    # 2. JSON de erro nativo da API sem prefixo ERROR:
    $rawJsonMatches = [regex]::Matches($combined, '(?m)^\s*(\{.*"error".*\})\s*$')
    if ($rawJsonMatches.Count -gt 0) {
        $jsonText = $rawJsonMatches[$rawJsonMatches.Count - 1].Groups[1].Value
        try {
            $obj = $jsonText | ConvertFrom-Json
            $msg = $null
            if ($obj.PSObject.Properties['error']) {
                if ($obj.error -is [string]) { $msg = [string]$obj.error }
                elseif ($obj.error.PSObject.Properties['message']) { $msg = [string]$obj.error.message }
            } elseif ($obj.PSObject.Properties['message']) {
                $msg = [string]$obj.message
            }
            if (-not [string]::IsNullOrWhiteSpace($msg)) { return $msg.Trim() }
        } catch { }
        return $jsonText.Trim()
    }

    # 3. Fallback: linha 'ERROR: <texto>' sem JSON
    $lineMatch = [regex]::Match($combined, 'ERROR:\s*(\S.*)')
    if ($lineMatch.Success) { return $lineMatch.Groups[1].Value.Trim() }

    # 4. Sentinelas de cota, taxa, autenticacao e servico em linhas do texto combinado
    $lines = @($combined -split "`r?`n")
    $interesting = @($lines | Where-Object {
        $_ -match '(?i)\b(429|rate[_\s-]?limit(?:ed|exceeded)?|insufficient_quota|quota|credit\s+balance|token\s+limit|too\s+many\s+requests|usage\s*limit|unauthorized|authentication|auth\s+error|invalid_api_key|token\s+expired|session\s+expired|forbidden|overloaded|service\s+unavailable|does\s+not\s+exist|not\s+supported|not\s+available|not\s+found)\b' -or
        $_ -match '(?i)model.{0,60}\b(does\s+not\s+exist|not\s+found|not\s+supported|unavailable|not\s+available)\b'
    })
    if ($interesting.Count -gt 0) {
        return (($interesting | Select-Object -First 8) -join "`n").Trim()
    }

    return $null
}

function Resolve-CodexJobStatus {
    # Decide o status final de um job do Codex (completed | error | sem-texto).
    # A resposta final (output-last-message) e a evidencia PRIMARIA de sucesso: havendo-a, o
    # status e 'completed' mesmo que o stderr contenha texto "ERROR: {...}" — no modo async o
    # stderr do `codex exec --json` carrega logs de comandos internos do agente (grep, leitura
    # de arquivos) que podem incluir essa string sem serem erro da sessao. So SEM resposta final
    # investiga-se erro: primeiro um erro estruturado do stream ($StreamError), depois o stderr.
    param([string]$FinalText, [string]$StreamError, [string]$Stderr)
    if (-not [string]::IsNullOrWhiteSpace($FinalText)) {
        return [pscustomobject]@{ status = 'completed'; error = $null }
    }
    $err = $StreamError
    if ([string]::IsNullOrWhiteSpace($err)) {
        $err = Get-CodexExecErrorMessage -StdoutText '' -StderrText $Stderr
    }
    if (-not [string]::IsNullOrWhiteSpace($err)) {
        return [pscustomobject]@{ status = 'error'; error = $err }
    }
    return [pscustomobject]@{ status = 'sem-texto'; error = $null }
}

function Format-CodexUtcTimestamp {
    param([Parameter(Mandatory)] [datetime] $Value)
    $utc = if ($Value.Kind -eq [DateTimeKind]::Utc) { $Value } else { $Value.ToUniversalTime() }
    return $utc.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
}

function ConvertTo-CodexUtcDateTime {
    param([AllowNull()] $Raw)
    if ($null -eq $Raw) { return $null }
    if ($Raw -is [datetime]) {
        $dt = [datetime]$Raw
        if ($dt.Kind -ne [DateTimeKind]::Utc) { $dt = $dt.ToUniversalTime() }
        return $dt
    }
    if ($Raw -is [datetimeoffset]) {
        return ([datetimeoffset]$Raw).UtcDateTime
    }
    $s = [string]$Raw
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    $dto = [datetimeoffset]::MinValue
    if ([datetimeoffset]::TryParse(
            $s,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind,
            [ref]$dto)) {
        return $dto.UtcDateTime
    }
    return $null
}

function Test-CodexProcessStartTimeMatch {
    param(
        $Process,
        [Parameter(Mandatory)] [datetime] $ExpectedStartTimeUtc
    )
    if ($null -eq $Process) { return $false }
    try {
        if ($Process.HasExited) { return $false }
        $st = $Process.StartTime
        if ($st.Kind -ne [DateTimeKind]::Utc) { $st = $st.ToUniversalTime() }
        $exp = $ExpectedStartTimeUtc
        if ($exp.Kind -ne [DateTimeKind]::Utc) { $exp = $exp.ToUniversalTime() }
        return ([Math]::Abs(($st - $exp).TotalMilliseconds) -lt 1000)
    } catch {
        return $false
    }
}

function Resolve-CodexJobTempDir {
    <#
    .SYNOPSIS
        Resolve a pasta absoluta de jobs Codex.
    .PARAMETER Override
        Valor Bound do chamador. Nulo ou branco = unbound (cai em env / default).
    .PARAMETER TempDir
        Documentacao: o default efetivo NAO vive no param() dos adapters; vive aqui
        (env XPZ_CODEX_JOBS_DIR ou %TEMP%\codex-jobs).
    #>
    param([AllowNull()] [string] $Override)

    $candidate = $null
    if (-not [string]::IsNullOrWhiteSpace($Override)) {
        $candidate = $Override.Trim()
    } elseif (-not [string]::IsNullOrWhiteSpace($env:XPZ_CODEX_JOBS_DIR)) {
        $candidate = ([string]$env:XPZ_CODEX_JOBS_DIR).Trim()
    } else {
        $candidate = Join-Path ([System.IO.Path]::GetTempPath()) 'codex-jobs'
    }

    try {
        $full = [System.IO.Path]::GetFullPath($candidate)
    } catch {
        throw 'BLOCK: falha ao criar TempDir.'
    }

    if (-not (Test-Path -LiteralPath $full -PathType Container)) {
        try {
            New-Item -Path $full -ItemType Directory -Force | Out-Null
        } catch {
            throw 'BLOCK: falha ao criar TempDir.'
        }
    }
    if (-not (Test-Path -LiteralPath $full -PathType Container)) {
        throw 'BLOCK: falha ao criar TempDir.'
    }
    return $full
}

function Get-CodexJobFileProp {
    param($Obj, [string] $Name)
    if ($null -ne $Obj -and $Obj.PSObject.Properties[$Name]) {
        return $Obj.PSObject.Properties[$Name].Value
    }
    return $null
}

function Read-CodexJsonObject {
    param([Parameter(Mandatory)] [string] $Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        return (Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Write-CodexJsonAtomic {
    param(
        [Parameter(Mandatory)] $Object,
        [Parameter(Mandatory)] [string] $Path,
        [switch] $Force
    )
    $json = $Object | ConvertTo-Json -Depth 8
    $tmp = "$Path.tmp"
    if ((Test-Path -LiteralPath $Path -PathType Leaf) -and -not $Force) {
        if (Test-Path -LiteralPath $tmp -PathType Leaf) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
        throw [System.InvalidOperationException]::new('CODEX_RESULT_CLOBBER')
    }
    Set-Content -LiteralPath $tmp -Value $json -Encoding utf8
    try {
        if ($Force) {
            Move-Item -LiteralPath $tmp -Destination $Path -Force
        } else {
            Move-Item -LiteralPath $tmp -Destination $Path
        }
    } catch {
        if (Test-Path -LiteralPath $tmp -PathType Leaf) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
        if (-not $Force -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw [System.InvalidOperationException]::new('CODEX_RESULT_CLOBBER')
        }
        throw
    }
}

function Resolve-CodexPidAndStartTime {
    # Merge campo-a-campo request.json + identity.json. Nunca lanca 22.
    # Devolve { pid; processStartTimeUtc; divergence }.
    param(
        [Parameter(Mandatory)] [string] $TempDir,
        [Parameter(Mandatory)] [string] $JobId
    )

    $base = Join-Path $TempDir $JobId
    $req = Read-CodexJsonObject -Path "$base.request.json"
    $ident = Read-CodexJsonObject -Path "$base.identity.json"

    $reqPid = $null
    $reqTimeRaw = $null
    if ($null -ne $req) {
        $rp = Get-CodexJobFileProp $req 'pid'
        if ($null -ne $rp -and "$rp" -match '^\d+$') { $reqPid = [int]$rp }
        $reqTimeRaw = Get-CodexJobFileProp $req 'processStartTimeUtc'
    }
    $idPid = $null
    $idTimeRaw = $null
    if ($null -ne $ident) {
        $ip = Get-CodexJobFileProp $ident 'pid'
        if ($null -ne $ip -and "$ip" -match '^\d+$') { $idPid = [int]$ip }
        $idTimeRaw = Get-CodexJobFileProp $ident 'processStartTimeUtc'
    }

    $reqTime = ConvertTo-CodexUtcDateTime -Raw $reqTimeRaw
    $idTime = ConvertTo-CodexUtcDateTime -Raw $idTimeRaw

    $divergence = $false
    $effPid = $null
    $effTime = $null

    if ($null -ne $reqPid -and $null -ne $idPid) {
        if ($reqPid -ne $idPid) {
            $divergence = $true
            $effPid = $reqPid
        } else {
            $effPid = $reqPid
        }
    } elseif ($null -ne $reqPid) {
        $effPid = $reqPid
    } elseif ($null -ne $idPid) {
        $effPid = $idPid
    }

    if ($null -ne $reqTime -and $null -ne $idTime) {
        $rt = $reqTime
        $it = $idTime
        if ($rt.Kind -ne [DateTimeKind]::Utc) { $rt = $rt.ToUniversalTime() }
        if ($it.Kind -ne [DateTimeKind]::Utc) { $it = $it.ToUniversalTime() }
        if ([Math]::Abs(($rt - $it).TotalMilliseconds) -ge 1000) {
            $divergence = $true
            $effTime = $reqTime
        } else {
            $effTime = $reqTime
        }
    } elseif ($null -ne $reqTime) {
        $effTime = $reqTime
    } elseif ($null -ne $idTime) {
        $effTime = $idTime
    }

    $effTimeStr = $null
    if ($null -ne $effTime) {
        $effTimeStr = Format-CodexUtcTimestamp -Value $effTime
    }

    return [pscustomobject]@{
        pid                 = $effPid
        processStartTimeUtc = $effTimeStr
        divergence          = [bool]$divergence
    }
}

function Get-CodexJobSuffixMap {
    return [ordered]@{
        'request.json'     = 'request'
        'stdin.txt'        = 'stdin'
        'stream.jsonl'     = 'stream'
        'lastmsg.txt'      = 'lastmsg'
        'stderr.txt'       = 'stderr'
        'result.json'      = 'result'
        'identity.json'    = 'identity'
        'invoke-in.txt'    = 'invoke-in'
        'invoke-out.txt'   = 'invoke-out'
        'invoke-err.txt'   = 'invoke-err'
        'request.json.tmp' = 'request-tmp'
        'result.json.tmp'  = 'result-tmp'
        'identity.json.tmp'= 'identity-tmp'
    }
}

function Get-CodexExclusiveMarkerSuffixes {
    return @(
        'lastmsg.txt',
        'identity.json',
        'invoke-in.txt',
        'invoke-out.txt',
        'invoke-err.txt'
    )
}

function Get-CodexCCodexSuffixes {
    $markers = @(Get-CodexExclusiveMarkerSuffixes)
    return @(
        $markers + @(
            'stdin.txt',
            'result.json',
            'request.json.tmp',
            'result.json.tmp',
            'identity.json.tmp'
        ) | ForEach-Object { $_ }
    )
}

function Test-CodexJobProcessAlive {
    param([AllowNull()] $PidValue)
    if ($null -eq $PidValue) { return $false }
    try {
        $p = Get-Process -Id ([int]$PidValue) -ErrorAction Stop
        return (-not $p.HasExited)
    } catch {
        return $false
    }
}

function Invoke-CodexJobsKeepDaysCleanup {
    # Best-effort: catch interno; nunca lanca para Start/Invoke. divergence -> idade.
    param(
        [Parameter(Mandatory)] [string] $TempDir,
        [Parameter(Mandatory)] [ValidateRange(1, 3650)] [int] $KeepDays
    )

    if ($env:XPZ_CODEX_DISABLE_KEEPDAYS -eq '1') { return }

    try {
        $keepDaysLegacy = [Math]::Max(14, $KeepDays)
        $now = Get-Date
        $limitA = $now.AddDays(-$KeepDays)
        $limitLegacy = $now.AddDays(-$keepDaysLegacy)
        $suffixMap = Get-CodexJobSuffixMap
        $exclusive = @(Get-CodexExclusiveMarkerSuffixes)
        $cCodex = @(Get-CodexCCodexSuffixes)

        $files = @(Get-ChildItem -LiteralPath $TempDir -File -ErrorAction SilentlyContinue)
        $byGuid = @{}
        foreach ($f in $files) {
            $matched = $false
            foreach ($suf in $suffixMap.Keys) {
                if ($f.Name.EndsWith('.' + $suf, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $guidPart = $f.Name.Substring(0, $f.Name.Length - $suf.Length - 1)
                    if ($guidPart -match '^[0-9a-fA-F]{32}$') {
                        if (-not $byGuid.ContainsKey($guidPart)) {
                            $byGuid[$guidPart] = [System.Collections.Generic.List[object]]::new()
                        }
                        $byGuid[$guidPart].Add([pscustomobject]@{
                                File   = $f
                                Suffix = $suf
                            })
                        $matched = $true
                    }
                    break
                }
            }
            # Ficheiro que nao casa classe alguma nunca e apagado (inclui nome sem GUID.sufixo).
            if (-not $matched) { continue }
        }

        foreach ($guid in @($byGuid.Keys)) {
            $entries = @($byGuid[$guid])
            $reqEntry = @($entries | Where-Object { $_.Suffix -eq 'request.json' }) | Select-Object -First 1
            $hasExclusive = $false
            foreach ($e in $entries) {
                if ($exclusive -contains $e.Suffix) { $hasExclusive = $true; break }
            }

            $class = $null
            $source = $null
            $captureOutcome = $null
            $reqReadable = $false
            if ($null -ne $reqEntry) {
                $reqObj = Read-CodexJsonObject -Path $reqEntry.File.FullName
                if ($null -ne $reqObj) {
                    $reqReadable = $true
                    $source = [string](Get-CodexJobFileProp $reqObj 'source')
                    $captureOutcome = [string](Get-CodexJobFileProp $reqObj 'captureOutcome')
                }
                if ($reqReadable -and ($source -eq 'start-job' -or $source -eq 'invoke-sync')) {
                    $class = 'A'
                } else {
                    $class = 'B'
                }
            } elseif ($hasExclusive) {
                $class = 'C-codex'
            } else {
                $hasShared = $false
                foreach ($e in $entries) {
                    if ($e.Suffix -eq 'stream.jsonl' -or $e.Suffix -eq 'stderr.txt') {
                        $hasShared = $true
                        break
                    }
                }
                if ($hasShared) {
                    # C-shared: nunca apagar stream/stderr sem marcador exclusivo Codex.
                    continue
                }
                # Sem request, sem marcador, sem stream/stderr: so sufixos nao-classificados
                # no grupo — nao apagar.
                continue
            }

            $examFiles = @()
            if ($class -eq 'A' -or $class -eq 'B') {
                $examFiles = @($entries | ForEach-Object { $_.File })
            } elseif ($class -eq 'C-codex') {
                foreach ($e in $entries) {
                    if ($cCodex -contains $e.Suffix) {
                        $examFiles += $e.File
                    } elseif ($hasExclusive -and ($e.Suffix -eq 'stream.jsonl' -or $e.Suffix -eq 'stderr.txt')) {
                        $examFiles += $e.File
                    }
                }
            }
            if ($examFiles.Count -eq 0) { continue }

            $age = ($examFiles | Measure-Object -Property LastWriteTime -Maximum).Maximum
            $resolved = Resolve-CodexPidAndStartTime -TempDir $TempDir -JobId $guid
            $alive = Test-CodexJobProcessAlive -PidValue $resolved.pid
            $timeDt = ConvertTo-CodexUtcDateTime -Raw $resolved.processStartTimeUtc

            $useAge = $false
            if ($alive -and ($null -ne $timeDt) -and (-not $resolved.divergence)) {
                $proc = $null
                try { $proc = Get-Process -Id ([int]$resolved.pid) -ErrorAction Stop } catch { $proc = $null }
                if (Test-CodexProcessStartTimeMatch -Process $proc -ExpectedStartTimeUtc $timeDt) {
                    continue
                }
                # vivo + hora valida que nao casa -> idade
                $useAge = $true
            } elseif ($alive -and ($null -eq $timeDt)) {
                # vivo + identidade inconclusiva -> saltar
                continue
            } elseif ($alive -and $resolved.divergence) {
                $useAge = $true
            } elseif ((-not $alive) -and $class -eq 'A' -and $source -eq 'invoke-sync' `
                    -and [string]::IsNullOrWhiteSpace($captureOutcome) `
                    -and $null -eq $resolved.pid `
                    -and $age -gt $now.AddHours(-1)) {
                # sem pid + invoke-sync sem captureOutcome e mtime < 1 h -> saltar
                continue
            } else {
                $useAge = $true
            }

            if (-not $useAge) { continue }

            $limit = if ($class -eq 'A') { $limitA } else { $limitLegacy }
            if ($age -ge $limit) { continue }

            foreach ($f in $examFiles) {
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        # best-effort: nunca propaga para Start/Invoke
    }
}
