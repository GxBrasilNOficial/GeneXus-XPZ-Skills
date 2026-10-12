#requires -Version 7.4

<#
.SYNOPSIS
    Self-test do detector Measure-PtBrAccentDegradation.ps1.
.DESCRIPTION
    Dot-source o detector (o main e pulado pelo guard de InvocationName) e exercita
    o nucleo Measure-AccentInText sobre golden files de contagem conhecida:
    - markdown com supressao de fenced block, code inline e identificador/slug;
    - powershell medindo so comentarios de linha e de bloco, ignorando codigo e strings;
    - arquivo "ja corrigido" (so formas acentuadas) => zero;
    - integridade da lista (sem duplicatas; sem colisao com ingles comum).
    Exit 0 se tudo passa; exit 1 na primeira falha.
.EXAMPLE
    pwsh -NoProfile -File scripts/Test-MeasurePtBrAccentDegradationSelfTest.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'Measure-PtBrAccentDegradation.ps1')

$script:passed = 0
function Assert-Equal {
    param($Expected, $Actual, [string] $Message)
    if ($Expected -ne $Actual) {
        throw "FAIL: $Message (esperado=$Expected, obtido=$Actual)"
    }
    $script:passed++
    Write-Host "  ok: $Message"
}

# ---------------------------------------------------------------------------
# Golden 1 — markdown
# ---------------------------------------------------------------------------
$goldenMd = @'
A funcao nao foi documentada.
Esta funcao tem um indice.
Codigo correto: `funcao` e `nao` entre crases.
```
nao funcao codigo indice
```
Ja documentado: função não.
Veja xpz-funcao-test e o caminho a/b/funcao/x.
Use a variavel responsavel pela acao.
'@

# Inequivocas esperadas:
#  L1 funcao,nao (2) | L2 funcao,indice (2) | L3 codigo (1; inline `funcao`/`nao` suprimidos)
#  fence (nao/funcao/codigo/indice) -> 0 | L7 ja (1) | L8 xpz-funcao/.../funcao colados -> 0
#  L9 variavel,responsavel,acao (3)  => 9
# Ambiguas: L2 esta(1), tem(1) => 2
$r1 = Measure-AccentInText -Text $goldenMd
Write-Host 'Golden markdown:'
Assert-Equal 9 $r1.Inequivocas.Count 'md: total inequivocas'
Assert-Equal 1 $r1.Ambiguous['esta'] 'md: ambiguo esta'
Assert-Equal 1 $r1.Ambiguous['tem']  'md: ambiguo tem'
Assert-Equal 0 $r1.Ambiguous['vem']  'md: ambiguo vem'
Assert-Equal 0 $r1.Ambiguous['so']   'md: ambiguo so'

# Confirma que fenced/inline/identificador nao vazaram nenhuma ocorrencia de funcao
$funcaoHits = @($r1.Inequivocas | Where-Object { $_.Word.ToLowerInvariant() -eq 'funcao' })
Assert-Equal 2 $funcaoHits.Count 'md: funcao contado so nas 2 linhas de prosa (fence/inline/slug suprimidos)'

# ---------------------------------------------------------------------------
# Golden 2 — powershell (so comentarios contam)
# ---------------------------------------------------------------------------
$goldenPs = @'
$funcao = 1   # define a funcao principal
Write-Output "mensagem: nao traduzida"
<#
  Resumo: gera o indice e a versao.
#>
$x = "indice"  # comentario sem acento valido aqui
'@

# Inequivocas: L1 comentario funcao(1) | L2 string nao -> NAO conta (0)
#  bloco <# #>: indice(1),versao(1) | L6 comentario sem palavra da lista(0); string "indice" nao conta
#  => 3
$r2 = Measure-AccentInText -Text $goldenPs -IsPowerShell
Write-Host 'Golden powershell:'
Assert-Equal 3 $r2.Inequivocas.Count 'ps: inequivocas so em comentarios (codigo e strings ignorados)'

# ---------------------------------------------------------------------------
# Golden 3 — arquivo ja corrigido => zero
# ---------------------------------------------------------------------------
$goldenClean = @'
A função única gera o índice automático.
Configuração e versão estão corretas.
'@
$r3 = Measure-AccentInText -Text $goldenClean
Write-Host 'Golden ja-corrigido:'
Assert-Equal 0 $r3.Inequivocas.Count 'corrigido: zero inequivocas (so formas acentuadas)'

# ---------------------------------------------------------------------------
# Golden 4 — supressao de identificador/slug isolada
# ---------------------------------------------------------------------------
$goldenSlug = @'
O codigo xpz-funcao-core e o path scripts/funcao/run nao sao prosa.
'@
# "codigo"(1) e "nao"(1) sao prosa; "funcao" em xpz-funcao-core e scripts/funcao/run -> suprimido; "sao"(1)
$r4 = Measure-AccentInText -Text $goldenSlug
$slugFuncao = @($r4.Inequivocas | Where-Object { $_.Word.ToLowerInvariant() -eq 'funcao' })
Write-Host 'Golden slug:'
Assert-Equal 0 $slugFuncao.Count 'slug: funcao em identificador/path nao conta'
Assert-Equal 3 $r4.Inequivocas.Count 'slug: codigo+nao+sao contam (prosa)'

# ---------------------------------------------------------------------------
# Golden 5 — fronteira pt-BR em arquivo trilingue (PT/ES/EN)
# ---------------------------------------------------------------------------
$goldenMulti = @'
A funcao nao foi documentada.
## Español
El repositorio tiene una version.
## English
The repository has a version.
'@
Write-Host 'Golden multilingue:'
# pt-BR e so a L1 (ate o cabecalho '## Español' na L2): funcao,nao => 2.
Assert-Equal 1 (Get-PtBrLineCount -Text $goldenMulti) 'multilingue: fronteira pt-BR para antes de ## Español'
$r5 = Measure-AccentInText -Text (Get-PtBrText -Text $goldenMulti)
Assert-Equal 2 $r5.Inequivocas.Count 'multilingue: medicao cobre so a secao pt-BR (ES/EN ignorados)'
# Sem o corte, o espanhol 'repositorio' viraria falso positivo (motivo do corte).
$r5full = Measure-AccentInText -Text $goldenMulti
Assert-Equal 3 $r5full.Inequivocas.Count 'multilingue: sem corte, espanhol repositorio e falso positivo'

# ---------------------------------------------------------------------------
# Integridade da lista curada
# ---------------------------------------------------------------------------
Write-Host 'Integridade da lista:'
$asciiList = @($wordlist.entries | ForEach-Object { $_.a.ToLowerInvariant() })
$dups = @($asciiList | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name })
Assert-Equal 0 $dups.Count "lista sem ascii duplicado (dups: $($dups -join ', '))"

$englishCommon = @('area','so','no','set','run','code','data','list','map','name','type','file','line','final','total','local','manual','media','plus','the','and','for','use','to','in','on','of')
$collisions = @($asciiList | Where-Object { $englishCommon -contains $_ })
Assert-Equal 0 $collisions.Count "lista sem colisao com ingles comum (colisoes: $($collisions -join ', '))"

# Toda entry tem forma correta nao-vazia e diferente da ascii
$badCorrect = @($wordlist.entries | Where-Object { [string]::IsNullOrWhiteSpace($_.c) -or ($_.c -eq $_.a) })
Assert-Equal 0 $badCorrect.Count 'toda entry tem forma correta acentuada distinta da ascii'

# Formas que tambem sao flexao verbal comum NAO podem estar no piso firme (devem ser ambiguousTokens).
# Guard contra regressao: 'analise o impacto' (imperativo) nao pode virar 'análise'.
$verbAmbiguous = @('analise', 'calculo', 'especifico', 'especifica', 'pratico', 'pratica', 'modulo')
$verbLeaked = @($asciiList | Where-Object { $verbAmbiguous -contains $_ })
Assert-Equal 0 $verbLeaked.Count "formas verbais ambiguas fora do piso firme (vazou: $($verbLeaked -join ', '))"
$verbMissing = @($verbAmbiguous | Where-Object { $wordlist.ambiguousTokens -notcontains $_ })
Assert-Equal 0 $verbMissing.Count "formas verbais ambiguas registradas em ambiguousTokens (faltando: $($verbMissing -join ', '))"

Write-Host ''
Write-Host "SELF-TEST OK ($script:passed asserts)."
Write-Host 'PTBR_ACCENT_MEASURE_SELFTEST_OK'
exit 0
