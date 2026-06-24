#requires -Version 7.4
<#
.SYNOPSIS
    Normalizacao de nome base de arquivo para materializacao de objetos GeneXus (fonte unica).

.DESCRIPTION
    Fonte canonica de Normalize-FileBaseName, dot-sourced por Sync-GeneXusXpzToXml.ps1 e (frente
    futura, dependente da amostra GX9) pelo conversor de export legado
    GeneXusLegacyExportFileSupport.ps1. Centralizar garante que a deteccao de colisao de nome
    (agrupamento por FolderType|NormalizedName) seja identica nos dois caminhos — evita a divergencia
    de normalizacao entre caminhos que a revisao por pares apontou.

    Regra: substitui cada caractere invalido de nome de arquivo (System.IO.Path.GetInvalidFileNameChars)
    por '_' e remove ponto(s) final(is) com TrimEnd('.'). Comportamento preservado byte a byte da
    implementacao historica interna ao Sync.
#>

function Normalize-FileBaseName {
    param([string]$LogicalName)

    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    $builder = New-Object System.Text.StringBuilder

    foreach ($char in $LogicalName.ToCharArray()) {
        if ($invalidChars -contains $char) {
            [void]$builder.Append('_')
        } else {
            [void]$builder.Append($char)
        }
    }

    return $builder.ToString().TrimEnd('.')
}
