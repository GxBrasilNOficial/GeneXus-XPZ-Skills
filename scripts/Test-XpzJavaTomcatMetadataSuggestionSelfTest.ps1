#requires -Version 7.4
<#
.SYNOPSIS
    Self-test do assistente opt-in de metadata Java/Tomcat do setup.

.DESCRIPTION
    Cobre: sugestao read-only por gradle.properties, alerta quando model.ini diverge
    do alvo Gradle validado e gravacao explicita dos campos Java pelo Set-*.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath

function Get-Utf8NoBomEncoding {
    return [System.Text.UTF8Encoding]::new($false)
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "ASSERT_FAILED: $Message"
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("xpz-java-metadata-suggestion-" + [guid]::NewGuid().ToString('N'))

try {
    $kbNative = Join-Path $tempRoot 'NativeKb'
    $output = 'JavaEnv'
    $webDir = Join-Path (Join-Path $kbNative $output) 'web'
    $tomcatRoot = Join-Path $tempRoot 'Tomcat\webapps\App'
    $classesRoot = Join-Path $tomcatRoot 'WEB-INF\classes'
    $packageRoot = Join-Path $classesRoot 'com\sample'
    $libDir = Join-Path $tomcatRoot 'WEB-INF\lib'

    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $libDir -Force | Out-Null
    New-Item -ItemType Directory -Path $webDir -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $libDir 'GeneXus.jar'), 'jar', (Get-Utf8NoBomEncoding))

    $gradleLines = @(
        'WEBAPP_NAME=App'
        ('TOMCAT_WEBAPP_PATH=' + $tomcatRoot.Replace('\', '\\'))
        'JAVA_PLATFORM=jakartaEE'
        'SERVLET_VERSION=6'
        'JAVA_PACKAGE_NAME_FOLDER=com\\sample'
    )
    [System.IO.File]::WriteAllText((Join-Path $webDir 'gradle.properties'), ($gradleLines -join "`n") + "`n", (Get-Utf8NoBomEncoding))

    $wrongServletDir = Join-Path $tempRoot 'Tomcat\webapps\WrongApp\WEB-INF\classes'
    $modelLines = @(
        '[MODEL 001]'
        'Model=JavaEnv'
        ('TargetFullPath=' + (Join-Path $kbNative $output))
        '[PREFERENCES 001]'
        'GeneratorType=JavaWeb'
        'JAVA_PLATFORM_SUPPORT=JAKARTA_EE'
        ('SERVLET_DIR=' + $wrongServletDir)
    )
    [System.IO.File]::WriteAllText((Join-Path $kbNative 'model.ini'), ($modelLines -join "`n") + "`n", (Get-Utf8NoBomEncoding))

    $json = & (Join-Path $scriptDir 'Resolve-XpzJavaTomcatMetadataSuggestion.ps1') `
        -KbNativePath $kbNative `
        -EnvironmentName 'JavaEnv' `
        -OutputDir $output `
        -AsJson
    $suggestion = ($json | ConvertFrom-Json)

    Assert-True ($suggestion.readOnly -eq $true) 'assistente deve ser read-only'
    Assert-True ($suggestion.status -eq 'needs-confirmation') "divergencia model.ini/Gradle deve exigir confirmacao; status=$($suggestion.status)"
    Assert-True ($suggestion.suggestedMetadata.KbEnvironmentServletDirs -eq "JavaEnv=$classesRoot") 'SERVLET_DIR sugerido deve vir do TOMCAT_WEBAPP_PATH validado'
    Assert-True ($suggestion.suggestedMetadata.KbEnvironmentAppPackage -eq 'JavaEnv=com\sample') 'pacote da app deve vir de JAVA_PACKAGE_NAME_FOLDER'
    Assert-True ($suggestion.suggestedMetadata.KbEnvironmentServletFlavor -eq 'JavaEnv=jakarta') 'jakartaEE deve sugerir flavor jakarta'

    $parallel = Join-Path $tempRoot 'parallel'
    New-Item -ItemType Directory -Path $parallel -Force | Out-Null
    $metadataPath = Join-Path $parallel 'kb-source-metadata.md'
    [System.IO.File]::WriteAllText($metadataPath, "---`nkb_name: Sample`n---`n", (Get-Utf8NoBomEncoding))

    & (Join-Path $scriptDir 'Set-XpzKbSourceMetadataDeployment.ps1') `
        -MetadataPath $metadataPath `
        -DeploymentEnvironmentName 'JavaEnv' `
        -DeploymentHostingKind 'java-tomcat' `
        -KbEnvironmentNames @('JavaEnv') `
        -KbEnvironmentOutputDirs @('JavaEnv=JavaEnv') `
        -KbEnvironmentWebDirs @("JavaEnv=$webDir") `
        -KbEnvironmentServletDirs @("JavaEnv=$classesRoot") `
        -KbEnvironmentAppPackage @('JavaEnv=com\sample') `
        -KbEnvironmentServletFlavor @('JavaEnv=jakarta') `
        -SkipEnvironmentNamesMsBuildValidation | Out-Null

    $written = [System.IO.File]::ReadAllText($metadataPath)
    Assert-True ($written.Contains("kb_environment_servlet_dirs: JavaEnv=$classesRoot")) 'Set-* deve gravar servlet_dirs quando explicitamente informado'
    Assert-True ($written.Contains('kb_environment_app_package: JavaEnv=com\sample')) 'Set-* deve gravar app_package quando explicitamente informado'
    Assert-True ($written.Contains('kb_environment_servlet_flavor: JavaEnv=jakarta')) 'Set-* deve gravar servlet_flavor quando explicitamente informado'

    $plausibilityJson = & (Join-Path $scriptDir 'Test-XpzKbDeploymentMetadata.ps1') -MetadataPath $metadataPath -AsJson
    $plausibility = ($plausibilityJson | ConvertFrom-Json)
    Assert-True ($plausibility.status -eq 'OK') "metadata Java completa deveria ser plausivel; status=$($plausibility.status)"

    $partialMetadataPath = Join-Path $parallel 'kb-source-metadata-partial.md'
    [System.IO.File]::WriteAllText($partialMetadataPath, "---`nkb_name: Sample`n---`n", (Get-Utf8NoBomEncoding))
    $partialBlocked = $false
    try {
        & (Join-Path $scriptDir 'Set-XpzKbSourceMetadataDeployment.ps1') `
            -MetadataPath $partialMetadataPath `
            -DeploymentEnvironmentName 'JavaEnv' `
            -DeploymentHostingKind 'java-tomcat' `
            -KbEnvironmentNames @('JavaEnv', 'JavaEnv2') `
            -KbEnvironmentOutputDirs @('JavaEnv=JavaEnv', 'JavaEnv2=JavaEnv2') `
            -KbEnvironmentWebDirs @("JavaEnv=$webDir", "JavaEnv2=$webDir") `
            -KbEnvironmentServletDirs @("JavaEnv=$classesRoot") `
            -KbEnvironmentAppPackage @('JavaEnv=com\sample') `
            -SkipEnvironmentNamesMsBuildValidation | Out-Null
    }
    catch {
        $partialBlocked = ($_.Exception.Message -like "*nao contem mapeamento para environment 'JavaEnv2'*")
    }
    Assert-True $partialBlocked 'Set-* deve bloquear metadata Java parcial quando ha multiplos environments declarados'

    'XPZ_JAVA_TOMCAT_METADATA_SUGGESTION_SELFTEST_OK'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
