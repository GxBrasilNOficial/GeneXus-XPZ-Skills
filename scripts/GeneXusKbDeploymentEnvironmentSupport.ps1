#requires -Version 7.4
<#
.SYNOPSIS
    Leitura de campos de environment/output em kb-source-metadata.md e resolucao de -EnvironmentName para wrappers MSBuild.

.DESCRIPTION
    Inventario de environments da KB nativa ocorre somente via xpz-kb-parallel-setup
    (Set-XpzKbSourceMetadataDeployment.ps1 com -KbEnvironmentNames e -KbEnvironmentOutputDirs declarados pelo usuário). Build/import/diagnostico de .cs apenas leem o metadata gravado.
#>

Set-StrictMode -Version Latest

# Fase 2 (paridade Java/Tomcat): registro-fonte-unica dos hosting kinds, usado na validacao de VALOR de
# deployment_hosting_kind no diagnostico de consistencia (Test-GeneXusKbDeploymentMetadataConsistency).
# O registro e standalone (nao dot-source este arquivo) — sem ciclo.
. (Join-Path $PSScriptRoot 'GeneXusKbHostingKindSupport.ps1')

function Get-GeneXusKbSourceMetadataDirectField {
    param(
        [string[]]$Lines,
        [string]$FieldName
    )

    $pattern = '^\s*{0}\s*[:=]\s*(?<value>.+?)\s*$' -f [regex]::Escape($FieldName)
    foreach ($line in $Lines) {
        $match = [regex]::Match($line, $pattern)
        if ($match.Success) {
            return $match.Groups['value'].Value.Trim()
        }
    }

    return $null
}

function Normalize-GeneXusKbMetadataScalar {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return $null
    }

    $trimmed = $Value.Trim()
    if ($trimmed.Length -eq 0 -or $trimmed -eq '(ausente)') {
        return $null
    }

    return $trimmed
}

function Split-GeneXusKbEnvironmentMap {
    param([AllowNull()][string]$MapRaw)

    $result = [ordered]@{}
    if ([string]::IsNullOrWhiteSpace($MapRaw)) {
        return $result
    }

    $entries = @(
        $MapRaw -split ';' |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_.Length -gt 0 }
    )

    foreach ($entry in $entries) {
        $parts = @($entry -split '=', 2)
        if ($parts.Count -ne 2) {
            $result[$entry] = $null
            continue
        }

        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        if ($key.Length -eq 0) {
            $result[$entry] = $null
            continue
        }

        $result[$key] = if ($value.Length -gt 0) { $value } else { $null }
    }

    return $result
}

function Join-GeneXusKbEnvironmentMap {
    param([System.Collections.IDictionary]$Map)

    if ($null -eq $Map -or $Map.Count -eq 0) {
        return ''
    }

    $entries = New-Object System.Collections.Generic.List[string]
    foreach ($key in @($Map.Keys | Sort-Object)) {
        $value = $Map[$key]
        $entries.Add(('{0}={1}' -f $key, $value)) | Out-Null
    }

    return ($entries -join '; ')
}

function Resolve-GeneXusKbSourceMetadataPath {
    param(
        [string]$KbMetadataPath,
        [string]$ParallelKbRoot
    )

    if (-not [string]::IsNullOrWhiteSpace($KbMetadataPath)) {
        return [System.IO.Path]::GetFullPath($KbMetadataPath)
    }

    if (-not [string]::IsNullOrWhiteSpace($ParallelKbRoot)) {
        return [System.IO.Path]::GetFullPath((Join-Path $ParallelKbRoot 'kb-source-metadata.md'))
    }

    return $null
}

function Read-GeneXusKbDeploymentMetadataFields {
    param([string]$MetadataPath)

    $result = [ordered]@{
        MetadataPath                  = $MetadataPath
        MetadataFound                 = $false
        deployment_environment_name   = $null
        deployment_hosting_kind       = $null
        kb_environment_count          = $null
        kb_environment_names          = @()
        kb_environment_output_dirs    = [ordered]@{}
        kb_environment_web_dirs       = [ordered]@{}
        # Fase 3 (paridade Java/Tomcat): metadata dedicado do alvo Java externo (por env).
        kb_environment_servlet_dirs   = [ordered]@{}   # env -> SERVLET_DIR (...\WEB-INF\classes)
        kb_environment_app_package    = [ordered]@{}   # env -> pacote da app (ex.: com\ebtech)
        kb_environment_servlet_flavor = [ordered]@{}   # env -> jakarta|javax
        kb_environment_post_build_event_hashes = [ordered]@{}
    }

    if ([string]::IsNullOrWhiteSpace($MetadataPath) -or -not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
        return [pscustomobject]$result
    }

    $result.MetadataFound = $true
    $lines = [System.IO.File]::ReadAllLines($MetadataPath)

    $result.deployment_environment_name = Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'deployment_environment_name'
    )

    $result.deployment_hosting_kind = Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'deployment_hosting_kind'
    )

    $countRaw = Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'kb_environment_count'
    )
    if ($countRaw) {
        $parsedCount = 0
        if ([int]::TryParse($countRaw, [ref]$parsedCount)) {
            $result.kb_environment_count = $parsedCount
        }
    }

    $namesRaw = Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'kb_environment_names'
    )
    if ($namesRaw) {
        $splitNames = @(
            $namesRaw -split '[,;]' |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_.Length -gt 0 }
        )
        $result.kb_environment_names = $splitNames
    }

    $outputDirsRaw = Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'kb_environment_output_dirs'
    )
    if ($outputDirsRaw) {
        $result.kb_environment_output_dirs = Split-GeneXusKbEnvironmentMap -MapRaw $outputDirsRaw
    }

    $webDirsRaw = Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'kb_environment_web_dirs'
    )
    if ($webDirsRaw) {
        $result.kb_environment_web_dirs = Split-GeneXusKbEnvironmentMap -MapRaw $webDirsRaw
    }

    # Fase 3: mapas por-env do alvo Java externo (mesmo formato env=valor;env=valor).
    $servletDirsRaw = Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'kb_environment_servlet_dirs'
    )
    if ($servletDirsRaw) {
        $result.kb_environment_servlet_dirs = Split-GeneXusKbEnvironmentMap -MapRaw $servletDirsRaw
    }

    $appPackageRaw = Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'kb_environment_app_package'
    )
    if ($appPackageRaw) {
        $result.kb_environment_app_package = Split-GeneXusKbEnvironmentMap -MapRaw $appPackageRaw
    }

    $servletFlavorRaw = Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'kb_environment_servlet_flavor'
    )
    if ($servletFlavorRaw) {
        $result.kb_environment_servlet_flavor = Split-GeneXusKbEnvironmentMap -MapRaw $servletFlavorRaw
    }

    $postBuildHashesRaw = Normalize-GeneXusKbMetadataScalar (
        Get-GeneXusKbSourceMetadataDirectField -Lines $lines -FieldName 'kb_environment_post_build_event_hashes'
    )
    if ($postBuildHashesRaw) {
        $postBuildMap = Split-GeneXusKbEnvironmentMap -MapRaw $postBuildHashesRaw
        $postBuildResult = [ordered]@{}
        foreach ($envKey in $postBuildMap.Keys) {
            $hashesValue = $postBuildMap[$envKey]
            if ([string]::IsNullOrWhiteSpace($hashesValue)) {
                $postBuildResult[$envKey] = @()
                continue
            }
            $postBuildResult[$envKey] = @(
                $hashesValue -split ',' |
                ForEach-Object { $_.Trim() } |
                Where-Object { $_.Length -gt 0 }
            )
        }
        $result.kb_environment_post_build_event_hashes = $postBuildResult
    }

    return [pscustomobject]$result
}

function Get-GeneXusRegisteredPostBuildEventHashesForEnvironment {
    param(
        [AllowNull()][string]$MetadataPath,
        [AllowNull()][string]$EnvironmentName
    )

    if ([string]::IsNullOrWhiteSpace($MetadataPath) -or [string]::IsNullOrWhiteSpace($EnvironmentName)) {
        return @()
    }
    if (-not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
        return @()
    }

    $fields = Read-GeneXusKbDeploymentMetadataFields -MetadataPath $MetadataPath
    $map = $fields.kb_environment_post_build_event_hashes
    if ($null -eq $map -or $map.Count -eq 0) {
        return @()
    }

    foreach ($envKey in $map.Keys) {
        if ($envKey -ieq $EnvironmentName) {
            return @($map[$envKey])
        }
    }
    return @()
}

function Resolve-GeneXusKbValidationEnvironment {
    param(
        [string]$EnvironmentName,
        [string]$KbMetadataPath,
        [string]$ParallelKbRoot
    )

    $requested = if ([string]::IsNullOrWhiteSpace($EnvironmentName)) { $null } else { $EnvironmentName.Trim() }
    $resolvedMetadataPath = Resolve-GeneXusKbSourceMetadataPath -KbMetadataPath $KbMetadataPath -ParallelKbRoot $ParallelKbRoot

    $context = [ordered]@{
        validationEnvironmentRequested   = $requested
        validationEnvironmentResolved    = $null
        deploymentEnvironmentSource      = $null
        kbEnvironmentCount               = $null
        kbEnvironmentNames               = @()
        multiEnvironmentKbFromMetadata     = $null
        kbSourceMetadataPath             = $resolvedMetadataPath
        kbSourceMetadataFound            = $false
        deployment_environment_name    = $null
    }

    $blockingReasons = New-Object System.Collections.Generic.List[string]

    if (-not $resolvedMetadataPath) {
        if ($requested) {
            $context.validationEnvironmentResolved = $requested
            $context.deploymentEnvironmentSource = 'parameter'
            return [pscustomobject][ordered]@{
                Proceed           = $true
                EnvironmentName   = $requested
                BlockingReasons   = @()
                Summary           = $null
                Context           = $context
            }
        }

        $blockingReasons.Add(
            'Sem -EnvironmentName e sem kb-source-metadata.md resolvivel (-KbMetadataPath ou -ParallelKbRoot). Informe -EnvironmentName explicito ou aponte metadata da pasta paralela atualizado pelo xpz-kb-parallel-setup.'
        ) | Out-Null

        return [pscustomobject][ordered]@{
            Proceed           = $false
            EnvironmentName   = $null
            BlockingReasons   = $blockingReasons.ToArray()
            Summary           = 'Environment de validacao/deploy indefinido: metadata da pasta paralela ausente e -EnvironmentName nao informado.'
            Context           = $context
        }
    }

    $fields = Read-GeneXusKbDeploymentMetadataFields -MetadataPath $resolvedMetadataPath
    $context.kbSourceMetadataFound = $fields.MetadataFound
    $context.deployment_environment_name = $fields.deployment_environment_name
    $context.kbEnvironmentCount = $fields.kb_environment_count
    $context.kbEnvironmentNames = @($fields.kb_environment_names)

    if (-not $fields.MetadataFound) {
        $blockingReasons.Add("kb-source-metadata.md nao encontrado: $resolvedMetadataPath") | Out-Null
        return [pscustomobject][ordered]@{
            Proceed           = $false
            EnvironmentName   = $null
            BlockingReasons   = $blockingReasons.ToArray()
            Summary           = 'kb-source-metadata.md ausente ou ilegivel para resolucao de Environment.'
            Context           = $context
        }
    }

    if ($null -eq $fields.kb_environment_count) {
        $blockingReasons.Add(
            'Campo kb_environment_count ausente em kb-source-metadata.md. Executar atualizacao de environments via xpz-kb-parallel-setup (Set-XpzKbSourceMetadataDeployment.ps1 na pasta paralela).'
        ) | Out-Null
        return [pscustomobject][ordered]@{
            Proceed           = $false
            EnvironmentName   = $null
            BlockingReasons   = $blockingReasons.ToArray()
            Summary           = 'Metadata de environments incompleto: falta kb_environment_count.'
            Context           = $context
        }
    }

    $context.multiEnvironmentKbFromMetadata = ($fields.kb_environment_count -gt 1)

    if ($fields.kb_environment_count -le 0) {
        $blockingReasons.Add('kb_environment_count invalido em kb-source-metadata.md (deve ser >= 1).') | Out-Null
        return [pscustomobject][ordered]@{
            Proceed           = $false
            EnvironmentName   = $null
            BlockingReasons   = $blockingReasons.ToArray()
            Summary           = 'kb_environment_count invalido no metadata.'
            Context           = $context
        }
    }

    if ($fields.kb_environment_count -eq 1) {
        if ($requested) {
            $context.validationEnvironmentResolved = $requested
            $context.deploymentEnvironmentSource = 'parameter'
            return [pscustomobject][ordered]@{
                Proceed           = $true
                EnvironmentName   = $requested
                BlockingReasons   = @()
                Summary           = $null
                Context           = $context
            }
        }

        $context.deploymentEnvironmentSource = 'geneXus-active-default-single'
        return [pscustomobject][ordered]@{
            Proceed           = $true
            EnvironmentName   = $null
            BlockingReasons   = @()
            Summary           = $null
            Context           = $context
        }
    }

    if ($requested) {
        $context.validationEnvironmentResolved = $requested
        $context.deploymentEnvironmentSource = 'parameter'

        if ($fields.kb_environment_names.Count -gt 0) {
            $known = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            foreach ($name in $fields.kb_environment_names) {
                [void]$known.Add($name)
            }
            if (-not $known.Contains($requested)) {
                $blockingReasons.Add(
                    ("-EnvironmentName '{0}' nao consta em kb_environment_names do metadata ({1})." -f $requested, ($fields.kb_environment_names -join ', '))
                ) | Out-Null
            }
        }

        if ($blockingReasons.Count -gt 0) {
            return [pscustomobject][ordered]@{
                Proceed           = $false
                EnvironmentName   = $null
                BlockingReasons   = $blockingReasons.ToArray()
                Summary           = 'Environment informado diverge do inventario gravado no metadata.'
                Context           = $context
            }
        }

        return [pscustomobject][ordered]@{
            Proceed           = $true
            EnvironmentName   = $requested
            BlockingReasons   = @()
            Summary           = $null
            Context           = $context
        }
    }

    if ($fields.deployment_environment_name) {
        $context.validationEnvironmentResolved = $fields.deployment_environment_name
        $context.deploymentEnvironmentSource = 'kb-source-metadata'
        return [pscustomobject][ordered]@{
            Proceed           = $true
            EnvironmentName   = $fields.deployment_environment_name
            BlockingReasons   = @()
            Summary           = $null
            Context           = $context
        }
    }

    $blockingReasons.Add(
        'KB com multiplos environments (kb_environment_count > 1): informe -EnvironmentName ou preencha deployment_environment_name em kb-source-metadata.md via xpz-kb-parallel-setup.'
    ) | Out-Null

    return [pscustomobject][ordered]@{
        Proceed           = $false
        EnvironmentName   = $null
        BlockingReasons   = $blockingReasons.ToArray()
        Summary           = 'Environment de validacao/deploy indefinido para KB multi-environment.'
        Context           = $context
    }
}

function Test-GeneXusKbActiveEnvironmentMatchesValidation {
    param(
        [AllowNull()][string]$ActiveEnvironment,
        [hashtable]$DeploymentEnvironmentContext
    )

    if ($null -eq $DeploymentEnvironmentContext) {
        return $true
    }

    $resolved = $DeploymentEnvironmentContext['validationEnvironmentResolved']
    if ([string]::IsNullOrWhiteSpace($resolved)) {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($ActiveEnvironment)) {
        return $false
    }

    return ($ActiveEnvironment.Trim() -ieq $resolved.Trim())
}

function Split-GeneXusKbDeploymentMetadataEnvironmentNames {
    param([AllowNull()][string]$NamesRaw)

    if ([string]::IsNullOrWhiteSpace($NamesRaw)) {
        return @()
    }

    return @(
        $NamesRaw -split '[,;]' |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_.Length -gt 0 }
    )
}

function Get-GeneXusKbDeploymentMetadataLegacyPollutionReason {
    param([string]$EnvironmentName)

    if ([string]::IsNullOrWhiteSpace($EnvironmentName)) {
        return 'nome vazio'
    }

    $trimmed = $EnvironmentName.Trim()

    $prefixExcluded = @(
        'CSharpModel'
        'CSharp'
        'Data'
        'DATA'
        'backup'
        'Backup'
        'Temp'
        'temp'
    )

    foreach ($prefix in $prefixExcluded) {
        if ($trimmed.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            return ("prefixo legado/estrutural '{0}' (tipico de scan por pastas web\\, nao environment GeneXus)" -f $prefix)
        }
    }

    return $null
}

function Test-GeneXusKbDeploymentMetadataPlausibility {
    param(
        [string]$MetadataPath,
        [scriptblock]$GetLegacyPollutionReason
    )

    if ($null -eq $GetLegacyPollutionReason) {
        $GetLegacyPollutionReason = { param($Name) Get-GeneXusKbDeploymentMetadataLegacyPollutionReason -EnvironmentName $Name }
    }

    $result = [ordered]@{
        status                     = 'unknown'
        metadataPath               = $MetadataPath
        deploymentFieldsPresent    = $false
        failures                   = @()
        warnings                   = @()
        kb_environment_names       = @()
        kb_environment_count       = $null
        deployment_environment_name = $null
        kb_environment_output_dirs = [ordered]@{}
        kb_environment_web_dirs    = [ordered]@{}
    }

    if ([string]::IsNullOrWhiteSpace($MetadataPath) -or -not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
        $result.status = 'BLOCK'
        $result.failures = @("kb-source-metadata.md nao encontrado: $MetadataPath")
        return [pscustomobject]$result
    }

    $fields = Read-GeneXusKbDeploymentMetadataFields -MetadataPath $MetadataPath
    $hasAnyDeploymentField = (
        $fields.deployment_environment_name -or
        $fields.deployment_hosting_kind -or
        ($null -ne $fields.kb_environment_count) -or
        ($fields.kb_environment_names.Count -gt 0)
    )

    $result.deploymentFieldsPresent = $hasAnyDeploymentField
    $result.deployment_environment_name = $fields.deployment_environment_name
    $result.kb_environment_count = $fields.kb_environment_count
    $result.kb_environment_names = @($fields.kb_environment_names)
    $result.kb_environment_output_dirs = $fields.kb_environment_output_dirs
    $result.kb_environment_web_dirs = $fields.kb_environment_web_dirs

    if (-not $hasAnyDeploymentField) {
        $result.status = 'PENDENTE'
        $result.warnings = @('Campos de environment/deploy ausentes em kb-source-metadata.md — executar Set-*KbSourceMetadataDeployment com -KbEnvironmentNames e mapeamento de output por environment (confirmados pelo usuario) e validacao MSBuild no setup.')
        return [pscustomobject]$result
    }

    $failures = New-Object System.Collections.Generic.List[string]

    if ([string]::IsNullOrWhiteSpace($fields.deployment_environment_name)) {
        $failures.Add('deployment_environment_name ausente enquanto outros campos de deploy estao preenchidos.') | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($fields.deployment_hosting_kind)) {
        $failures.Add('deployment_hosting_kind ausente enquanto outros campos de deploy estao preenchidos.') | Out-Null
    }
    elseif ($null -eq (Get-GeneXusKbHostingKindSupportRecord -HostingKind $fields.deployment_hosting_kind)) {
        # Fase 2: valor PRESENTE mas fora do registro (ex.: metadata editado a mao — bypassa a validacao de
        # escrita de Set-XpzKbSourceMetadataDeployment). Auditoria de valor, nao so presenca; mensagem canonica
        # do registro (fonte-unica). O elseif garante que so consulta quando presente (guard de vazio T1).
        $failures.Add((Get-GeneXusKbHostingKindSupportInvalidValueMessage -HostingKind $fields.deployment_hosting_kind)) | Out-Null
    }

    if ($null -eq $fields.kb_environment_count) {
        $failures.Add('kb_environment_count ausente enquanto kb_environment_names ou deployment_environment_name estao preenchidos.') | Out-Null
    }

    if ($fields.kb_environment_names.Count -eq 0) {
        $failures.Add('kb_environment_names ausente ou vazio enquanto outros campos de deploy estao preenchidos.') | Out-Null
    }

    if ($fields.kb_environment_count -lt 1) {
        $failures.Add("kb_environment_count invalido: $($fields.kb_environment_count).") | Out-Null
    }

    if ($fields.kb_environment_names.Count -gt 0 -and $null -ne $fields.kb_environment_count) {
        if ($fields.kb_environment_count -ne $fields.kb_environment_names.Count) {
            $failures.Add(
                ("kb_environment_count ({0}) diverge da lista kb_environment_names ({1} nomes)." -f $fields.kb_environment_count, $fields.kb_environment_names.Count)
            ) | Out-Null
        }
    }

    foreach ($name in $fields.kb_environment_names) {
        $excludeReason = & $GetLegacyPollutionReason $name
        if ($excludeReason) {
            $failures.Add(
                ("kb_environment_names contem '{0}' — {1}." -f $name, $excludeReason)
            ) | Out-Null
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($fields.deployment_environment_name) -and ($fields.kb_environment_names.Count -gt 0)) {
        $known = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($name in $fields.kb_environment_names) {
            [void]$known.Add($name)
        }
        if (-not $known.Contains($fields.deployment_environment_name)) {
            $failures.Add(
                ("deployment_environment_name '{0}' nao consta em kb_environment_names ({1})." -f $fields.deployment_environment_name, ($fields.kb_environment_names -join ', '))
            ) | Out-Null
        }
    }

    $warnings = New-Object System.Collections.Generic.List[string]
    $hasOutputDirs = ($fields.kb_environment_output_dirs.Count -gt 0)
    $hasWebDirs = ($fields.kb_environment_web_dirs.Count -gt 0)
    if (-not $hasOutputDirs -or -not $hasWebDirs) {
        $warnings.Add('Mapeamento de output por environment ausente em kb-source-metadata.md: preencher kb_environment_output_dirs e kb_environment_web_dirs via xpz-kb-parallel-setup antes de diagnostico por .cs gerado.') | Out-Null
    } else {
        $knownEnvironmentNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($name in $fields.kb_environment_names) {
            [void]$knownEnvironmentNames.Add($name)
        }

        foreach ($mapName in @('kb_environment_output_dirs', 'kb_environment_web_dirs')) {
            $map = if ($mapName -eq 'kb_environment_output_dirs') { $fields.kb_environment_output_dirs } else { $fields.kb_environment_web_dirs }

            foreach ($key in $map.Keys) {
                if ([string]::IsNullOrWhiteSpace($map[$key])) {
                    $failures.Add(("{0} contem valor vazio ou entrada malformada para '{1}'." -f $mapName, $key)) | Out-Null
                    continue
                }

                if (-not $knownEnvironmentNames.Contains($key)) {
                    $failures.Add(("{0} contem environment '{1}' que nao consta em kb_environment_names." -f $mapName, $key)) | Out-Null
                }
            }

            foreach ($name in $fields.kb_environment_names) {
                if (-not $map.Contains($name)) {
                    $failures.Add(("{0} nao contem mapeamento para environment '{1}'." -f $mapName, $name)) | Out-Null
                }
            }
        }
    }

    $result.failures = $failures.ToArray()
    if ($failures.Count -gt 0) {
        $result.status = 'BLOCK'
        return [pscustomobject]$result
    }

    if ($warnings.Count -gt 0) {
        $result.status = 'PENDENTE'
        $result.warnings = $warnings.ToArray()
        return [pscustomobject]$result
    }

    $result.status = 'OK'
    return [pscustomobject]$result
}
