#requires -Version 7.4

<#
.SYNOPSIS
Wrapper local sanitizado para resolver a identidade da KB nativa.

.DESCRIPTION
Executa o script compartilhado `Resolve-GeneXusKbIdentity.ps1`, que le
`model.ini`, `knowledgebase.connection` e consulta o banco interno da KB em
modo somente leitura para obter os campos estaveis de identidade usados pelo
`kb-source-metadata.md`.

Este wrapper é recomendado quando a pasta paralela precisa reconciliar
metadata de identidade porque o XPZ exportado veio com `Source` vazio ou
incompleto.

.PARAMETER AsJson
Retorna saida JSON estruturada.

.PARAMETER SqlCredential
Credencial SQL Server. Necessária apenas quando a conexão resolvida exigir
autenticacao SQL.

.PARAMETER UpdateMetadata
Atualiza os campos de identidade estavel em `kb-source-metadata.md` a partir da
KB nativa local. Por padrão, preenche campos ausentes e bloqueia divergencias.

.PARAMETER AllowIdentityOverwrite
Permite sobrescrever campos de identidade não vazios quando divergirem da KB
nativa local resolvida. Use apenas em frente aprovada de reconciliacao.

.PARAMETER SharedSkillsRoot
Raiz local da base compartilhada `GeneXus-XPZ-Skills`.

.EXAMPLE
.\Resolve-KbIdentity.ps1 -AsJson

.EXAMPLE
.\Resolve-KbIdentity.ps1 -SqlCredential (Get-Credential)

.EXAMPLE
.\Resolve-KbIdentity.ps1 -UpdateMetadata -AsJson
#>

param(
    [switch]$AsJson,

    [PSCredential]$SqlCredential,

    [switch]$UpdateMetadata,

    [switch]$AllowIdentityOverwrite,

    [string]$SharedSkillsRoot = "C:\CAMINHO\PARA\GeneXus-XPZ-Skills"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$kbNativePath = "C:\CAMINHO\PARA\KB-NATIVA"
$enginePath = Join-Path $SharedSkillsRoot "scripts\Resolve-GeneXusKbIdentity.ps1"
$updateEnginePath = Join-Path $SharedSkillsRoot "scripts\Update-XpzKbSourceMetadataIdentity.ps1"
$metadataPath = Join-Path (Split-Path -Parent $PSScriptRoot) "kb-source-metadata.md"

if ($UpdateMetadata) {
    if (-not (Test-Path -LiteralPath $updateEnginePath -PathType Leaf)) {
        throw "Shared KB metadata identity updater not found: $updateEnginePath"
    }

    $argsForUpdate = @{
        MetadataPath = $metadataPath
        KbNativePath = $kbNativePath
        PassThru = $AsJson
    }

    if ($AllowIdentityOverwrite) {
        $argsForUpdate.AllowIdentityOverwrite = $true
    }

    if ($null -ne $SqlCredential) {
        $argsForUpdate.SqlCredential = $SqlCredential
    }

    $updateResult = & $updateEnginePath @argsForUpdate
    if ($AsJson) {
        $updateResult | ConvertTo-Json -Depth 8
    } else {
        $updateResult
    }
    return
}

if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    throw "Shared KB identity resolver not found: $enginePath"
}

$argsForEngine = @{
    KbNativePath = $kbNativePath
}

if ($AsJson) {
    $argsForEngine.AsJson = $true
}

if ($null -ne $SqlCredential) {
    $argsForEngine.SqlCredential = $SqlCredential
}

& $enginePath @argsForEngine
