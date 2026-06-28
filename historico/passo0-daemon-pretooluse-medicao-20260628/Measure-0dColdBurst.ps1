# Measure-0dColdBurst.ps1 - PROTOTIPO DESCARTAVEL (passo 0d: frio sob contencao).
# Implementa a coordenacao do cliente do design (secao 5): tenta conectar; se nao ha canal,
# disputa um NAMED MUTEX; SO o vencedor sobe o daemon e segura ate ready; os demais fazem 2
# reconnects em ~30ms e DEFEREM. Dispara K clientes simultaneos com o daemon PARADO e conta
# os defers ate ready + confirma UM UNICO daemon. E correcao (contagem), nao latencia.
# NAO e codigo final: identidade do mutex/pipe simplificada (nome fixo).
[CmdletBinding()]
param([int] $K = 10)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scratch = 'C:\Users\ANTONIOJOSE\AppData\Local\Temp\claude\C--Dev-Knowledge-GeneXus-XPZ-Skills\01c98338-4fed-4c53-9438-d321fa4a18ef\scratchpad'
$repo = 'C:\Dev\Knowledge\GeneXus-XPZ-Skills'
$daemonScript = Join-Path $scratch 'daemon-pipe-persistpy.ps1'
$persistPy = Join-Path $scratch 'shlex-persistent.py'
$pwshExe = (Get-Command pwsh).Source

$pipeName = 'ptu-daemon-0d'
$mutexName = 'ptu-daemon-0d-mutex'
$readyFile = Join-Path $scratch 'daemon-ready-0d.txt'
$dOut = Join-Path $scratch 'daemon-out-0d.txt'
$dErr = Join-Path $scratch 'daemon-err-0d.txt'
foreach ($f in @($readyFile, $dOut, $dErr)) { if (Test-Path $f) { Remove-Item $f -Force } }

$jsonAllow = '{"tool_name":"Bash","cwd":"C:\\Dev\\Knowledge\\GeneXus-XPZ-Skills","tool_input":{"command":"git status"}}'

Write-Host "Disparando $K clientes simultaneos com o daemon PARADO (pipe '$pipeName')..." -ForegroundColor Cyan

$results = 1..$K | ForEach-Object -ThrottleLimit $K -Parallel {
    $idx = $_
    $pipeName = $using:pipeName
    $mutexName = $using:mutexName
    $json = $using:jsonAllow
    $pwshExe = $using:pwshExe
    $daemonScript = $using:daemonScript
    $readyFile = $using:readyFile
    $repo = $using:repo
    $persistPy = $using:persistPy
    $dOut = $using:dOut
    $dErr = $using:dErr

    function Connect-Decide {
        param([string] $PipeName, [string] $Json, [int] $TimeoutMs)
        $pipe = $null
        try {
            $pipe = [System.IO.Pipes.NamedPipeClientStream]::new('.', $PipeName, [System.IO.Pipes.PipeDirection]::InOut)
            $pipe.Connect($TimeoutMs)
            $payload = [System.Text.Encoding]::UTF8.GetBytes($Json)
            $pipe.WriteByte(1)
            $len = [byte[]]::new(4)
            $len[0] = [byte](($payload.Length -shr 24) -band 0xFF); $len[1] = [byte](($payload.Length -shr 16) -band 0xFF)
            $len[2] = [byte](($payload.Length -shr 8) -band 0xFF); $len[3] = [byte]($payload.Length -band 0xFF)
            $pipe.Write($len, 0, 4); $pipe.Write($payload, 0, $payload.Length); $pipe.Flush()
            $magic = $pipe.ReadByte(); if ($magic -lt 0) { throw 'eof' }
            $rl = [byte[]]::new(4); $off = 0
            while ($off -lt 4) { $k = $pipe.Read($rl, $off, 4 - $off); if ($k -le 0) { throw 'eof' }; $off += $k }
            $n = ([int]$rl[0] -shl 24) -bor ([int]$rl[1] -shl 16) -bor ([int]$rl[2] -shl 8) -bor [int]$rl[3]
            $rb = [byte[]]::new($n); $off = 0
            while ($off -lt $n) { $k = $pipe.Read($rb, $off, $n - $off); if ($k -le 0) { throw 'eof' }; $off += $k }
            return [System.Text.Encoding]::UTF8.GetString($rb)
        }
        catch { return $null }
        finally { if ($pipe) { try { $pipe.Dispose() } catch { } } }
    }

    # Passo 1: tenta conectar (canal pode ja existir).
    $d = Connect-Decide -PipeName $pipeName -Json $json -TimeoutMs 50
    if ($d) { return [pscustomobject]@{ idx = $idx; outcome = 'connected'; decision = $d; spawnedPid = $null } }

    # Passo 2: disputa o mutex.
    $mx = [System.Threading.Mutex]::new($false, $mutexName)
    $got = $false
    try { $got = $mx.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $got = $true } catch { $got = $false }

    if ($got) {
        # Vencedor: sobe o daemon e segura o mutex ate ready (<=2s).
        $spawnedPid = $null
        try {
            $p = Start-Process -FilePath $pwshExe -ArgumentList @('-NoProfile', '-NoLogo', '-NonInteractive', '-File', $daemonScript, '-PipeName', $pipeName, '-ReadyFile', $readyFile, '-RepoRoot', $repo, '-PersistPy', $persistPy) -PassThru -WindowStyle Hidden -RedirectStandardOutput $dOut -RedirectStandardError $dErr
            $spawnedPid = $p.Id
            $dl = [DateTime]::UtcNow.AddMilliseconds(2000)
            $d2 = $null
            while ([DateTime]::UtcNow -lt $dl) {
                if (Test-Path $readyFile) { $d2 = Connect-Decide -PipeName $pipeName -Json $json -TimeoutMs 150; if ($d2) { break } }
                Start-Sleep -Milliseconds 25
            }
            if ($d2) { return [pscustomobject]@{ idx = $idx; outcome = 'spawner-connected'; decision = $d2; spawnedPid = $spawnedPid } }
            else { return [pscustomobject]@{ idx = $idx; outcome = 'spawner-defer'; decision = $null; spawnedPid = $spawnedPid } }
        }
        finally { try { $mx.ReleaseMutex() } catch { }; try { $mx.Dispose() } catch { } }
    }
    else {
        # Nao-vencedor: 2 reconnects em ~30ms total, senao DEFER (fail-closed, design 5).
        try {
            $d3 = $null
            for ($a = 0; $a -lt 2; $a++) { $d3 = Connect-Decide -PipeName $pipeName -Json $json -TimeoutMs 15; if ($d3) { break }; Start-Sleep -Milliseconds 15 }
            if ($d3) { return [pscustomobject]@{ idx = $idx; outcome = 'late-connected'; decision = $d3; spawnedPid = $null } }
            else { return [pscustomobject]@{ idx = $idx; outcome = 'defer-nomutex'; decision = $null; spawnedPid = $null } }
        }
        finally { try { $mx.Dispose() } catch { } }
    }
}

$spawners = @($results | Where-Object { $_.spawnedPid })
$defers = @($results | Where-Object { $_.outcome -in @('defer-nomutex', 'spawner-defer') })
$connected = @($results | Where-Object { $_.outcome -in @('connected', 'late-connected', 'spawner-connected') })

Write-Host ""
Write-Host "RESULTADO 0d (K=$K, daemon parado no arranque):" -ForegroundColor Green
$results | Sort-Object idx | Format-Table idx, outcome, decision, spawnedPid -AutoSize | Out-String | Write-Host
Write-Host ("daemons spawnados (DEVE ser 1): {0} (PIDs: {1})" -f $spawners.Count, (($spawners.spawnedPid | Sort-Object -Unique) -join ',')) -ForegroundColor Yellow
Write-Host ("defers no arranque: {0}/{1}  |  conectados: {2}/{1}" -f $defers.Count, $K, $connected.Count) -ForegroundColor Yellow

# Pos-arranque: o daemon agora deve estar ready; um cliente solto conecta normalmente.
Start-Sleep -Milliseconds 300
$post = $null
if (Test-Path $readyFile) {
    $post = & {
        $pipe = [System.IO.Pipes.NamedPipeClientStream]::new('.', $pipeName, [System.IO.Pipes.PipeDirection]::InOut)
        try { $pipe.Connect(300); 'ok' } catch { 'falha' } finally { $pipe.Dispose() }
    }
}
Write-Host ("pos-arranque (daemon ja ready): cliente solto conecta = {0}" -f ($(if ($post) { $post } else { 'ready-file ausente' }))) -ForegroundColor Yellow

# Cleanup: mata o daemon spawnado.
foreach ($dpid in ($spawners.spawnedPid | Sort-Object -Unique)) {
    try { $pp = Get-Process -Id $dpid -ErrorAction SilentlyContinue; if ($pp) { $pp.Kill() } } catch { }
}
Write-Host "daemon 0d encerrado." -ForegroundColor DarkGray
