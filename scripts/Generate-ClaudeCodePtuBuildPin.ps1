#requires -Version 7.4
<#
.SYNOPSIS
Gera o BuildPin.g.cs com o buildContractPin do Passo B do daemon PreToolUse (auto-allow) do
Claude Code. Invocado pelo ptu-native/BuildPin.targets em BeforeTargets="CoreCompile" nos dois
projetos (EXE NativeAOT e DLL gerenciada), de modo que ambos compilem o MESMO pin.

.DESCRIPTION
Contrato de determinismo (claude-code-pretooluse-implementacao-v1-plan.md, spec congelada v12):
- buildContractPin = SHA256 de uma SEQUENCIA de 6 CHUNKS em ORDEM FIXA, cada um precedido por um
  PREFIXO de 8 bytes (uint64 big-endian) com o comprimento do chunk em BYTES UTF-8 APOS normalizacao,
  sem separadores. Ordem: (1) PtuCanon.cs, (2) este gerador, (3) BuildPin.targets,
  (4) InvariantGlobalization, (5) TargetFramework, (6) LangVersion.
- Arquivos materiais sao lidos por bytes, com strip de BOM UTF-8 e normalizacao CRLF->LF e CR->LF
  (nunca Get-Content / default de cmdlet); decodificacao UTF-8 estrita.
- As 3 props chegam como PARAMETROS (o .ps1 NAO parseia .csproj); normalizadas Trim + ToLowerInvariant.
- Nenhum path absoluto/arg/valor expandido entra no material (so o CONTEUDO dos 3 arquivos + as props).
- BuildPin.g.cs e escrito em LF + UTF-8 SEM BOM, so com literal estavel (sem path/data/usuario/versao),
  e SO e reescrito quando o conteudo muda (idempotente; evita rebuild em cascata).
Falha (arquivo ausente, prop vazia) -> excecao -> exit != 0 -> o <Exec> do .targets falha o build.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $CsPath,
    [Parameter(Mandatory)][string] $GeneratorPath,
    [Parameter(Mandatory)][string] $TargetsPath,
    [Parameter(Mandatory)][string] $InvariantGlobalization,
    [Parameter(Mandatory)][string] $TargetFramework,
    [Parameter(Mandatory)][string] $LangVersion,
    [Parameter(Mandatory)][string] $OutPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PtuNormalizedFileBytes {
    # Le o arquivo por bytes, remove BOM UTF-8, decodifica UTF-8 estrito, normaliza CRLF/CR -> LF,
    # e devolve os bytes UTF-8 normalizados. Determinismo independente do EOL do working tree.
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Generate-ClaudeCodePtuBuildPin: arquivo material ausente: $Path" }
    $raw = [System.IO.File]::ReadAllBytes($Path)
    $start = 0
    if ($raw.Length -ge 3 -and $raw[0] -eq 0xEF -and $raw[1] -eq 0xBB -and $raw[2] -eq 0xBF) { $start = 3 }
    $strict = [System.Text.UTF8Encoding]::new($false, $true)
    $text = $strict.GetString($raw, $start, $raw.Length - $start)
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    return $strict.GetBytes($text)
}

function Get-PtuPropBytes {
    # Prop canonica: Trim + ToLowerInvariant, UTF-8 sem BOM.
    param([string] $Value)
    $norm = $Value.Trim().ToLowerInvariant()
    return ([System.Text.UTF8Encoding]::new($false)).GetBytes($norm)
}

function Get-PtuLengthPrefix {
    # Prefixo de 8 bytes, uint64 big-endian (network order).
    param([int] $Length)
    $bytes = [System.BitConverter]::GetBytes([uint64] $Length)
    if ([System.BitConverter]::IsLittleEndian) { [System.Array]::Reverse($bytes) }
    return $bytes
}

# Props canonicas obrigatorias e nao-vazias (senao o pin perderia um chunk silenciosamente).
foreach ($prop in @(
        @{ Name = 'InvariantGlobalization'; Value = $InvariantGlobalization },
        @{ Name = 'TargetFramework';        Value = $TargetFramework },
        @{ Name = 'LangVersion';            Value = $LangVersion })) {
    if ([string]::IsNullOrWhiteSpace($prop.Value)) {
        throw "Generate-ClaudeCodePtuBuildPin: prop canonica vazia: $($prop.Name)"
    }
}

# Sequencia de 6 chunks em ORDEM FIXA (ver spec v12 §5j).
$chunks = [System.Collections.Generic.List[byte[]]]::new()
$chunks.Add((Get-PtuNormalizedFileBytes -Path $CsPath))
$chunks.Add((Get-PtuNormalizedFileBytes -Path $GeneratorPath))
$chunks.Add((Get-PtuNormalizedFileBytes -Path $TargetsPath))
$chunks.Add((Get-PtuPropBytes -Value $InvariantGlobalization))
$chunks.Add((Get-PtuPropBytes -Value $TargetFramework))
$chunks.Add((Get-PtuPropBytes -Value $LangVersion))

$stream = [System.IO.MemoryStream]::new()
try {
    foreach ($chunk in $chunks) {
        # Assertion self-documenting (§5j): o comprimento cabe no prefixo de 8 bytes. Array .NET e
        # int32, sempre < 2^64; a checagem torna o contrato explicito.
        if ([uint64] $chunk.Length -gt [uint64]::MaxValue) {
            throw "Generate-ClaudeCodePtuBuildPin: chunk excede o prefixo de 8 bytes"
        }
        $prefix = Get-PtuLengthPrefix -Length $chunk.Length
        $stream.Write($prefix, 0, $prefix.Length)
        $stream.Write($chunk, 0, $chunk.Length)
    }
    $material = $stream.ToArray()
}
finally {
    $stream.Dispose()
}

$hash = [System.Security.Cryptography.SHA256]::HashData($material)
$pin = [System.Convert]::ToHexString($hash).ToLowerInvariant()

# BuildPin.g.cs: LF, UTF-8 sem BOM, so literal estavel (sem path/data/usuario/versao).
$lines = @(
    '// <auto-generated/> Gerado por scripts/Generate-ClaudeCodePtuBuildPin.ps1 -- NAO editar.',
    '// buildContractPin do Passo B (ver claude-code-pretooluse-implementacao-v1-plan.md).',
    'namespace Ptu',
    '{',
    '    public static class BuildPin',
    '    {',
    "        public const string Value = `"$pin`";",
    '    }',
    '}',
    ''
)
$content = [string]::Join("`n", $lines)
$outBytes = ([System.Text.UTF8Encoding]::new($false)).GetBytes($content)

# Idempotencia (§5h): so reescreve quando muda, para nao disparar rebuild em cascata do CoreCompile.
$needWrite = $true
if (Test-Path -LiteralPath $OutPath) {
    $existing = [System.IO.File]::ReadAllBytes($OutPath)
    if ($existing.Length -eq $outBytes.Length) {
        $different = $false
        for ($i = 0; $i -lt $outBytes.Length; $i++) {
            if ($existing[$i] -ne $outBytes[$i]) { $different = $true; break }
        }
        if (-not $different) { $needWrite = $false }
    }
}

if ($needWrite) {
    $dir = [System.IO.Path]::GetDirectoryName($OutPath)
    if (-not [string]::IsNullOrEmpty($dir) -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllBytes($OutPath, $outBytes)
}

Write-Output $pin
