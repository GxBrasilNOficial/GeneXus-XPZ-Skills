#requires -Version 7.4
<#
.SYNOPSIS
    Escrita atomica de arquivo de texto com temporario em diretorio declarado.

.DESCRIPTION
    Write-XpzTextFileAtomic grava o texto BRUTO (sem rejuntar linhas, sem
    normalizar EOL) em um temporario dentro de -TempDir, valida o conteudo
    gravado e substitui o destino com File.Move(replace).

    Diferencas deliberadas frente a Write-XpzReportFileAtomic (que permanece
    intocado, dono do relatorio de empacotamento):

      - o temporario vive em -TempDir (tipicamente o -WorkDir da rodada), nunca
        ao lado do destino - o destino pode estar dentro da frente, e a frente
        nao recebe temporario;
      - substituicao de destino existente e o caso normal (-ReplaceExisting),
        porque todo alvo de edicao em lote ja existe.

    Limite declarado: File.Move e atomico quanto a VISIBILIDADE do nome no
    mesmo volume. Flush($true) cobre o conteudo do arquivo, nao a entrada de
    diretorio; nao ha fsync de diretorio. Durabilidade contra queda de energia
    no instante do move e coberta pelo journal e pelos .bak do chamador.
#>

Set-StrictMode -Version Latest

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

function Write-XpzTextFileAtomic {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$TempDir,

        [switch]$ReplaceExisting
    )

    if (-not (Test-Path -LiteralPath $TempDir -PathType Container)) {
        throw "TEMPDIR_MISSING: diretorio de temporarios nao existe: $TempDir"
    }

    $destinationVolume = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($Path))
    $tempVolume = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($TempDir))
    if (-not $destinationVolume.Equals($tempVolume, [StringComparison]::OrdinalIgnoreCase)) {
        throw "TEMPDIR_CROSS_VOLUME: TempDir ($tempVolume) e destino ($destinationVolume) em volumes distintos; o move deixaria de ser atomico."
    }

    $tempPath = Join-Path $TempDir ("write.$PID." + [Guid]::NewGuid().ToString('N') + '.tmp')
    $encoding = (Get-Utf8NoBomEncoding)
    $stream = $null
    $moved = $false
    try {
        $stream = [IO.File]::Open($tempPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $bytes = $encoding.GetBytes($Text)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose()
        $stream = $null

        $writtenBytes = [IO.File]::ReadAllBytes($tempPath)
        if ($writtenBytes.Length -ne $bytes.Length) {
            throw "ATOMIC_WRITE_VERIFY_FAILED: temporario com $($writtenBytes.Length) bytes, esperado $($bytes.Length): $tempPath"
        }

        if ($ReplaceExisting) {
            [IO.File]::Move($tempPath, $Path, $true)
        } else {
            [IO.File]::Move($tempPath, $Path)
        }
        $moved = $true
    } finally {
        if ($null -ne $stream) {
            $stream.Dispose()
        }
        if (-not $moved -and (Test-Path -LiteralPath $tempPath -PathType Leaf)) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }

    return [pscustomobject]@{
        Path      = [IO.Path]::GetFullPath($Path)
        TempPath  = $tempPath
        ByteCount = $encoding.GetByteCount($Text)
    }
}
