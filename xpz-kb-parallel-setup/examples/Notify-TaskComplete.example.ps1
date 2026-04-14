param(
    [string]$Title = "Codex",
    [string]$Message = "Tarefa concluida",
    [int]$DurationMs = 8000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    [System.Media.SystemSounds]::Exclamation.Play()

    $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
    $notifyIcon.Visible = $true
    $notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
    $notifyIcon.BalloonTipTitle = $Title
    $notifyIcon.BalloonTipText = $Message
    $notifyIcon.ShowBalloonTip($DurationMs)

    Start-Sleep -Milliseconds $DurationMs
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
} catch {
    [System.Media.SystemSounds]::Exclamation.Play()
    Write-Warning ("Falha ao exibir notificacao visual: {0}" -f $_.Exception.Message)
}
