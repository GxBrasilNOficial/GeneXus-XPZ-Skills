# AB-Defender.ps1 - PROTOTIPO DESCARTAVEL (passo 0b: A/B do Defender, EXECUTA ELEVADO).
# Adiciona exclusao SO do exe do protototipo, remede o e2e do pipe, e SEMPRE remove a
# exclusao no finally (reverte). Escreve resultado e log em arquivos (a janela elevada e
# separada e nao retorna stdout ao chamador).
param(
    [string] $Exe = 'C:\Users\ANTONIOJOSE\AppData\Local\Temp\claude\C--Dev-Knowledge-GeneXus-XPZ-Skills\01c98338-4fed-4c53-9438-d321fa4a18ef\scratchpad\aot\bin\x64\Release\net8.0\win-x64\publish\ptu-client-pipe.exe',
    [string] $Harness = 'C:\Users\ANTONIOJOSE\AppData\Local\Temp\claude\C--Dev-Knowledge-GeneXus-XPZ-Skills\01c98338-4fed-4c53-9438-d321fa4a18ef\scratchpad\Measure-PipeE2E.ps1',
    [string] $ResultFile = 'C:\Users\ANTONIOJOSE\AppData\Local\Temp\claude\C--Dev-Knowledge-GeneXus-XPZ-Skills\01c98338-4fed-4c53-9438-d321fa4a18ef\scratchpad\ab-defender-result.txt',
    [string] $LogFile = 'C:\Users\ANTONIOJOSE\AppData\Local\Temp\claude\C--Dev-Knowledge-GeneXus-XPZ-Skills\01c98338-4fed-4c53-9438-d321fa4a18ef\scratchpad\ab-defender-log.txt'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-Content -LiteralPath $LogFile -Value ("[{0}] inicio" -f (Get-Date).ToString('o')) -Encoding utf8
function Log { param([string] $m) Add-Content -LiteralPath $LogFile -Value ("[{0}] {1}" -f (Get-Date).ToString('o'), $m) -Encoding utf8 }

$pwsh = (Get-Command pwsh).Source
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
Log "isAdmin=$isAdmin; exe=$Exe"
if (-not $isAdmin) { Set-Content -LiteralPath $ResultFile -Value 'ERROR: processo nao esta elevado'; exit 1 }

$added = $false
try {
    $before = @((Get-MpPreference).ExclusionPath)
    $already = $before -contains $Exe
    Log "exclusoes antes=$($before.Count); ja presente=$already"
    if (-not $already) {
        Add-MpPreference -ExclusionPath $Exe
        $added = $true
        Log 'Add-MpPreference executado'
    }
    Start-Sleep -Milliseconds 600  # deixar o Defender assimilar a exclusao
    $after = @((Get-MpPreference).ExclusionPath)
    $present = $after -contains $Exe
    Log "exclusao presente agora=$present"
    if (-not $present) {
        Set-Content -LiteralPath $ResultFile -Value 'ERROR: exclusao nao aplicou (Tamper Protection / politica?)'
        throw 'exclusao nao aplicou'
    }

    Log 'rodando harness e2e COM exclusao...'
    $out = & $pwsh -NoProfile -NoLogo -NonInteractive -File $Harness 2>&1 | Out-String
    Set-Content -LiteralPath $ResultFile -Value $out -Encoding utf8
    Log 'harness concluido; resultado gravado'
}
catch {
    Log "ERRO: $($_.Exception.Message)"
    Add-Content -LiteralPath $ResultFile -Value "`nERRO: $($_.Exception.Message)"
}
finally {
    if ($added) {
        try { Remove-MpPreference -ExclusionPath $Exe; Log 'Remove-MpPreference executado (revertido)' }
        catch { Log "FALHA ao remover exclusao: $($_.Exception.Message)" }
    }
    else { Log 'nada a remover (exclusao ja existia antes ou nao foi adicionada)' }
    $final = @((Get-MpPreference).ExclusionPath)
    Log "exclusao ainda presente apos revert=$($final -contains $Exe); total final=$($final.Count)"
    Log 'fim'
}
