#requires -Version 7.4
<#
.SYNOPSIS
    Funções compartilhadas para catálogo de tipos GeneXus (base + override local).
#>

Set-StrictMode -Version Latest

$utf8NoBomEncodingSupportPath = Join-Path (Split-Path -Parent $PSCommandPath) 'Utf8NoBomEncodingSupport.ps1'
if (-not (Test-Path -LiteralPath $utf8NoBomEncodingSupportPath -PathType Leaf)) {
    throw "UTF-8 no-BOM encoding support script not found: $utf8NoBomEncodingSupportPath"
}
. $utf8NoBomEncodingSupportPath

function Get-GeneXusObjectTypeCatalogDefaultBasePath {
    return (Join-Path $PSScriptRoot 'gx-object-type-catalog.json')
}

function Get-GeneXusObjectTypeCatalogDefaultOverridePath {
    param([string]$ParallelKbRoot)

    if ([string]::IsNullOrWhiteSpace($ParallelKbRoot)) {
        return $null
    }

    return (Join-Path $ParallelKbRoot 'scripts/gx-object-type-catalog.override.json')
}

function Read-GeneXusObjectTypeCatalogFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Object type catalog not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return ($raw | ConvertFrom-Json)
}


function New-GeneXusCatalogOverrideDiagnosticResult {
    param([string]$Status,[bool]$OverrideActive,[string]$OverridePath,[string]$Reason,[string]$DiagnosticReason,[string]$FieldPath,[string]$Message,[object[]]$Entries=@(),[bool]$DeclaredUpstreamPending=$false,[string]$EffectiveCatalogAction='none')
    $pending=@($Entries|Where-Object{$_.classification -eq 'pending'}); $redundant=@($Entries|Where-Object{$_.classification -eq 'redundant'}); $divergent=@($Entries|Where-Object{$_.classification -eq 'divergent'}); $blocked=@($Entries|Where-Object{$_.effectiveCatalogAction -eq 'block-resolution'})
    $effectivePending = $Status -in @('REMINDER_REQUIRED','INVALID_OVERRIDE_SHAPE','OVERRIDE_RESOLUTION_BLOCKED')
    [pscustomobject]@{
        status=$Status; overrideActive=$OverrideActive; overridePath=$OverridePath; reason=$Reason; diagnosticReason=$DiagnosticReason; fieldPath=$FieldPath; message=$Message; blocked=($Status -in @('INVALID_OVERRIDE_SHAPE','OVERRIDE_RESOLUTION_BLOCKED'))
        classificationEntries=@($Entries); declaredUpstreamPending=$DeclaredUpstreamPending; effectiveUpstreamPending=$effectivePending; upstreamPending=$effectivePending; cleanupRecommended=($Status -eq 'CLEANUP_RECOMMENDED'); noticeRequired=($Status -ne 'OK'); reminderRequired=($Status -eq 'REMINDER_REQUIRED')
        pendingTypeNames=@($pending|ForEach-Object{$_.typeName}|Sort-Object); pendingTypeGuids=@($pending|ForEach-Object{$_.objectTypeGuid}|Where-Object{-not [string]::IsNullOrWhiteSpace($_)})
        redundantTypeNames=@($redundant|ForEach-Object{$_.typeName}|Sort-Object); redundantTypeGuids=@($redundant|ForEach-Object{$_.objectTypeGuid}|Where-Object{-not [string]::IsNullOrWhiteSpace($_)})
        divergentTypeNames=@($divergent|ForEach-Object{$_.typeName}|Sort-Object); divergentTypeGuids=@($divergent|ForEach-Object{$_.objectTypeGuid}|Where-Object{-not [string]::IsNullOrWhiteSpace($_)})
        blockedTypeNames=@($blocked|ForEach-Object{$_.typeName}|Sort-Object); blockedTypeGuids=@($blocked|ForEach-Object{$_.objectTypeGuid}|Where-Object{-not [string]::IsNullOrWhiteSpace($_)})
        effectiveCatalogAction=$EffectiveCatalogAction; unsupportedFields=@($Entries|ForEach-Object{$_.unsupportedFields}|Sort-Object -Unique)
    }
}

function Test-GeneXusCatalogGuidValue { param([object]$Value) $g=[Guid]::Empty; return ($null -ne $Value -and -not [string]::IsNullOrWhiteSpace([string]$Value) -and [Guid]::TryParse(([string]$Value).Trim(),[ref]$g)) }
function Get-GeneXusCatalogEntryValue { param([object]$Entry,[string]$Name) if($null -eq $Entry -or $null -eq $Entry.PSObject.Properties[$Name]){return $null}; return $Entry.PSObject.Properties[$Name].Value }
function Test-GeneXusCatalogFieldEquivalent { param([object]$Override,[object]$Base,[string]$Field) if($null -eq $Override.PSObject.Properties[$Field]){return $true}; if($null -eq $Base.PSObject.Properties[$Field]){return $false}; $a=$Override.PSObject.Properties[$Field].Value; $b=$Base.PSObject.Properties[$Field].Value; if($Field -in @('inventoryEligible','queryableByKbIntelligence','containerType')){return ([bool]$a -eq [bool]$b)}; return [string]::Equals([string]$a,[string]$b,[StringComparison]::OrdinalIgnoreCase) }

function New-GeneXusCatalogOverrideClassificationEntry {
    param([string]$TypeName,[object]$Entry,[string]$Classification,[string]$Reason,[string]$DiagnosticReason,[string]$FieldPath,[string]$BaseTypeName=$null,[object]$BaseEntry=$null,[string[]]$DivergentFields=@(),[string[]]$IgnoredFields=@(),[string[]]$UnsupportedFields=@(),[string]$Action='merge-with-warning')
    [pscustomobject]@{ typeName=$TypeName; objectTypeGuid=if($null -ne $Entry){[string](Get-GeneXusCatalogEntryValue $Entry 'objectTypeGuid')}else{$null}; classification=$Classification; reason=$Reason; diagnosticReason=$DiagnosticReason; fieldPath=$FieldPath; baseTypeName=$BaseTypeName; baseObjectTypeGuid=if($null -ne $BaseEntry){[string](Get-GeneXusCatalogEntryValue $BaseEntry 'objectTypeGuid')}else{$null}; divergentFields=@($DivergentFields); duplicateTypeNames=@(); ignoredFields=@($IgnoredFields); unsupportedFields=@($UnsupportedFields); removalRecommended=($Classification -eq 'redundant'); effectiveCatalogAction=$Action }
}

function Test-GeneXusCatalogJsonHasDuplicateKey {
    param([string]$Path)
    if([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
    try{$doc=[System.Text.Json.JsonDocument]::Parse((Get-Content -LiteralPath $Path -Raw -Encoding UTF8))}catch{return [pscustomobject]@{diagnosticReason='invalid-json';fieldPath='$';message=$_.Exception.Message}}
    $found=$null
    function Visit([System.Text.Json.JsonElement]$Element,[string]$FieldPath){
        if($null -ne $script:dupFound -or $Element.ValueKind -ne [System.Text.Json.JsonValueKind]::Object){return}
        $seen=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach($p in $Element.EnumerateObject()){
            if(-not $seen.Add($p.Name)){ $script:dupFound=[pscustomobject]@{diagnosticReason='duplicate-json-key';fieldPath=$FieldPath;message="Chave JSON duplicada '$($p.Name)' em $FieldPath."}; return }
            $childPath = if($FieldPath -eq '$'){'$.'+$p.Name}else{$FieldPath+'.'+$p.Name}
            if($p.Value.ValueKind -eq [System.Text.Json.JsonValueKind]::Object){ Visit $p.Value $childPath }
        }
    }
    $script:dupFound=$null
    try{Visit $doc.RootElement '$'}finally{$doc.Dispose()}
    return $script:dupFound
}

function Get-GeneXusCatalogOverrideClassification {
    param([string]$BaseCatalogPath,[string]$CatalogOverridePath,[string]$ParallelKbRoot,[object]$OverrideCatalog,[string]$OverridePathForDiagnostics)
    if([string]::IsNullOrWhiteSpace($BaseCatalogPath)){$BaseCatalogPath=Get-GeneXusObjectTypeCatalogDefaultBasePath}
    $resolvedOverridePath=$CatalogOverridePath
    if([string]::IsNullOrWhiteSpace($resolvedOverridePath) -and -not [string]::IsNullOrWhiteSpace($ParallelKbRoot)){$resolvedOverridePath=Get-GeneXusObjectTypeCatalogDefaultOverridePath -ParallelKbRoot $ParallelKbRoot}
    $overrideActive=($null -ne $OverrideCatalog) -or (-not [string]::IsNullOrWhiteSpace($resolvedOverridePath) -and (Test-Path -LiteralPath $resolvedOverridePath -PathType Leaf))
    if(-not $overrideActive){ return New-GeneXusCatalogOverrideDiagnosticResult -Status 'OK' -OverrideActive:$false -OverridePath $null -Reason $null -DiagnosticReason $null -FieldPath $null -Message $null }
    if([string]::IsNullOrWhiteSpace($OverridePathForDiagnostics) -and -not [string]::IsNullOrWhiteSpace($resolvedOverridePath) -and (Test-Path -LiteralPath $resolvedOverridePath -PathType Leaf)){$OverridePathForDiagnostics=(Resolve-Path -LiteralPath $resolvedOverridePath).Path}
    $baseCatalog=Read-GeneXusObjectTypeCatalogFile -Path $BaseCatalogPath
    if($null -eq $OverrideCatalog){
        $dup=Test-GeneXusCatalogJsonHasDuplicateKey -Path $OverridePathForDiagnostics
        if($null -ne $dup){ return New-GeneXusCatalogOverrideDiagnosticResult -Status 'INVALID_OVERRIDE_SHAPE' -OverrideActive:$true -OverridePath $OverridePathForDiagnostics -Reason 'invalid-override-shape' -DiagnosticReason $dup.diagnosticReason -FieldPath $dup.fieldPath -Message $dup.message -DeclaredUpstreamPending:$true -EffectiveCatalogAction 'block-resolution' }
        try{$OverrideCatalog=Read-GeneXusObjectTypeCatalogFile -Path $OverridePathForDiagnostics}catch{ return New-GeneXusCatalogOverrideDiagnosticResult -Status 'INVALID_OVERRIDE_SHAPE' -OverrideActive:$true -OverridePath $OverridePathForDiagnostics -Reason 'invalid-override-shape' -DiagnosticReason 'invalid-json' -FieldPath '$' -Message $_.Exception.Message -DeclaredUpstreamPending:$true -EffectiveCatalogAction 'block-resolution' }
    }
    $declared=$false
    if($null -ne $OverrideCatalog.PSObject.Properties['upstreamPending']){ if($OverrideCatalog.upstreamPending -isnot [bool]){ return New-GeneXusCatalogOverrideDiagnosticResult -Status 'INVALID_OVERRIDE_SHAPE' -OverrideActive:$true -OverridePath $OverridePathForDiagnostics -Reason 'invalid-override-shape' -DiagnosticReason 'upstream-pending-not-boolean' -FieldPath 'upstreamPending' -Message 'upstreamPending no override deve ser booleano real.' -DeclaredUpstreamPending:$true -EffectiveCatalogAction 'block-resolution' }; $declared=[bool]$OverrideCatalog.upstreamPending }
    if($null -eq $OverrideCatalog.PSObject.Properties['types']){ return New-GeneXusCatalogOverrideDiagnosticResult -Status 'CLEANUP_RECOMMENDED' -OverrideActive:$true -OverridePath $OverridePathForDiagnostics -Reason 'metadata-only' -DiagnosticReason $null -FieldPath 'types' -Message 'Override local metadata-only; remocao do arquivo e recomendada se nao houver entrada de tipo.' -DeclaredUpstreamPending:$declared }
    if($null -eq $OverrideCatalog.types -or $OverrideCatalog.types.GetType().Name -ne 'PSCustomObject'){ return New-GeneXusCatalogOverrideDiagnosticResult -Status 'INVALID_OVERRIDE_SHAPE' -OverrideActive:$true -OverridePath $OverridePathForDiagnostics -Reason 'invalid-override-shape' -DiagnosticReason 'types-not-object' -FieldPath 'types' -Message 'types no override deve ser objeto JSON.' -DeclaredUpstreamPending:$declared -EffectiveCatalogAction 'block-resolution' }
    $baseByName=@{}; $baseGuidToName=@{}
    foreach($p in $baseCatalog.types.PSObject.Properties){$baseByName[$p.Name.ToLowerInvariant()]=[pscustomobject]@{Name=$p.Name;Entry=$p.Value}; $g=Get-GeneXusCatalogEntryValue $p.Value 'objectTypeGuid'; if($null -ne $g -and -not [string]::IsNullOrWhiteSpace([string]$g)){$baseGuidToName[[string]$g.ToLowerInvariant()]=$p.Name}}
    $fold=[System.Collections.Generic.Dictionary[string,string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($p in $OverrideCatalog.types.PSObject.Properties){ if($fold.ContainsKey($p.Name)){ return New-GeneXusCatalogOverrideDiagnosticResult -Status 'INVALID_OVERRIDE_SHAPE' -OverrideActive:$true -OverridePath $OverridePathForDiagnostics -Reason 'invalid-override-shape' -DiagnosticReason 'duplicate-type-name-casefold' -FieldPath 'types' -Message "Chaves de tipo colidem ignorando caixa: $($fold[$p.Name]) / $($p.Name)." -DeclaredUpstreamPending:$declared -EffectiveCatalogAction 'block-resolution' }; $fold[$p.Name]=$p.Name }
    $guidSeen=@{}; foreach($p in $OverrideCatalog.types.PSObject.Properties){$e=$p.Value; if($null -ne $e -and $e.GetType().Name -eq 'PSCustomObject' -and $null -ne $e.PSObject.Properties['objectTypeGuid']){$g=[string]$e.objectTypeGuid; if(-not [string]::IsNullOrWhiteSpace($g)){ $k=$g.ToLowerInvariant(); if($guidSeen.ContainsKey($k) -and -not $guidSeen[$k].Equals($p.Name,[StringComparison]::OrdinalIgnoreCase)){ $entry=New-GeneXusCatalogOverrideClassificationEntry -TypeName $p.Name -Entry $e -Classification 'divergent' -Reason 'unsafe-duplicate-guid' -DiagnosticReason 'duplicate-guid-in-override' -FieldPath "types.$($p.Name).objectTypeGuid" -Action 'block-resolution'; return New-GeneXusCatalogOverrideDiagnosticResult -Status 'OVERRIDE_RESOLUTION_BLOCKED' -OverrideActive:$true -OverridePath $OverridePathForDiagnostics -Reason 'unsafe-duplicate-guid' -DiagnosticReason 'duplicate-guid-in-override' -FieldPath 'types' -Message 'Override contem GUID duplicado entre entradas locais.' -Entries @($entry) -DeclaredUpstreamPending:$declared -EffectiveCatalogAction 'block-resolution' }; $guidSeen[$k]=$p.Name }}}
    $ops=@('objectTypeGuid','rootKind','folderName','inventoryEligible','queryableByKbIntelligence','containerType','exportTaskLabel'); $identityFields=@('objectTypeGuid','rootKind','folderName'); $req=@('objectTypeGuid','rootKind','folderName','inventoryEligible','queryableByKbIntelligence','containerType'); $meta=@('evidenceSummary','wikiLinks','nexaFindings','notes','lastObservedAt'); $supported=@($ops+$meta); $entries=[System.Collections.Generic.List[object]]::new()
    foreach($p in $OverrideCatalog.types.PSObject.Properties){
        $type=[string]$p.Name; $e=$p.Value
        if($null -eq $e -or $e.GetType().Name -ne 'PSCustomObject'){ $entries.Add((New-GeneXusCatalogOverrideClassificationEntry -TypeName $type -Entry ([pscustomobject]@{}) -Classification 'divergent' -Reason 'invalid-override-shape' -DiagnosticReason 'entry-not-object' -FieldPath "types.$type" -Action 'block-resolution'))|Out-Null; continue }
        $unsupported=@($e.PSObject.Properties|Where-Object{$_.Name -notin $supported}|ForEach-Object{$_.Name}|Sort-Object); $ignored=@($e.PSObject.Properties|Where-Object{$_.Name -in $meta}|ForEach-Object{$_.Name}|Sort-Object)
        $base=$null; if($baseByName.ContainsKey($type.ToLowerInvariant())){$base=$baseByName[$type.ToLowerInvariant()]}
        $guid=Get-GeneXusCatalogEntryValue $e 'objectTypeGuid'; if($null -ne $base){$baseNameForEntry=$base.Name; $baseEntryForEntry=$base.Entry}else{$baseNameForEntry=$null; $baseEntryForEntry=$null}; if($null -ne $guid -and -not [string]::IsNullOrWhiteSpace([string]$guid) -and -not (Test-GeneXusCatalogGuidValue $guid)){ $entries.Add((New-GeneXusCatalogOverrideClassificationEntry $type $e 'divergent' 'invalid-operational-field' 'invalid-guid' "types.$type.objectTypeGuid" $baseNameForEntry $baseEntryForEntry @() $ignored $unsupported 'block-resolution'))|Out-Null; continue }
        $guidKey=if($null -ne $guid -and -not [string]::IsNullOrWhiteSpace([string]$guid)){[string]$guid.ToLowerInvariant()}else{$null}; $baseByGuid=$null; if($null -ne $guidKey -and $baseGuidToName.ContainsKey($guidKey)){$baseByGuid=$baseGuidToName[$guidKey]}
        if($null -eq $base -and $null -ne $baseByGuid){$base=$baseByName[$baseByGuid.ToLowerInvariant()]}
        $invalid=$null; $diag=$null
        foreach($f in $req){if($null -eq $base -and $null -eq $e.PSObject.Properties[$f]){$invalid=$f;$diag='required-field-missing';break}}
        if($null -eq $invalid){foreach($f in $ops){if($null -eq $e.PSObject.Properties[$f]){continue}; $v=$e.PSObject.Properties[$f].Value; if($f -in @('inventoryEligible','queryableByKbIntelligence','containerType')){if($v -isnot [bool]){$invalid=$f;$diag='field-not-boolean';break}}elseif($f -eq 'objectTypeGuid'){if(-not (Test-GeneXusCatalogGuidValue $v)){$invalid=$f;$diag='invalid-guid';break}}else{if($v -isnot [string]){$invalid=$f;$diag='field-not-string';break}; if([string]::IsNullOrWhiteSpace([string]$v)){$invalid=$f;$diag='field-empty';break}}}}
        if($null -ne $invalid){if($null -ne $base){$baseNameForEntry=$base.Name; $baseEntryForEntry=$base.Entry}else{$baseNameForEntry=$null; $baseEntryForEntry=$null}; $entries.Add((New-GeneXusCatalogOverrideClassificationEntry $type $e 'divergent' 'invalid-operational-field' $diag "types.$type.$invalid" $baseNameForEntry $baseEntryForEntry @() $ignored $unsupported 'block-resolution'))|Out-Null; continue}
        if($null -ne $baseByGuid -and $null -ne $base -and -not $baseByGuid.Equals($base.Name,[StringComparison]::OrdinalIgnoreCase)){$entries.Add((New-GeneXusCatalogOverrideClassificationEntry $type $e 'divergent' 'unsafe-duplicate-guid' 'guid-collides-with-other-base-type' "types.$type.objectTypeGuid" $baseByGuid $baseByName[$baseByGuid.ToLowerInvariant()].Entry @() $ignored $unsupported 'block-resolution'))|Out-Null; continue}
        if($null -ne $base){$bg=Get-GeneXusCatalogEntryValue $base.Entry 'objectTypeGuid'; if(($null -eq $bg -or [string]::IsNullOrWhiteSpace([string]$bg)) -and $null -ne $guid -and -not [string]::IsNullOrWhiteSpace([string]$guid)){$entries.Add((New-GeneXusCatalogOverrideClassificationEntry $type $e 'divergent' 'unsafe-shadowing' 'unsafe-shadowing-base-type-without-guid' "types.$type.objectTypeGuid" $base.Name $base.Entry @() $ignored $unsupported 'block-resolution'))|Out-Null; continue}; $div=[System.Collections.Generic.List[string]]::new(); foreach($f in $ops){if(-not (Test-GeneXusCatalogFieldEquivalent $e $base.Entry $f)){$div.Add($f)|Out-Null}}; if($div.Count -gt 0){$identityDiv=@($div|Where-Object{$_ -in $identityFields}); if($identityDiv.Count -gt 0){$entries.Add((New-GeneXusCatalogOverrideClassificationEntry $type $e 'divergent' 'unsafe-identity-divergence' 'identity-field-divergence' "types.$type.$($identityDiv[0])" $base.Name $base.Entry @($div) $ignored $unsupported 'block-resolution'))|Out-Null}else{$entries.Add((New-GeneXusCatalogOverrideClassificationEntry $type $e 'divergent' 'field-divergence' 'field-divergence' "types.$type" $base.Name $base.Entry @($div) $ignored $unsupported 'merge-with-warning'))|Out-Null}}else{$entries.Add((New-GeneXusCatalogOverrideClassificationEntry $type $e 'redundant' 'equivalent' 'equivalent' "types.$type" $base.Name $base.Entry @() $ignored $unsupported 'merge'))|Out-Null}}
        else{$entries.Add((New-GeneXusCatalogOverrideClassificationEntry $type $e 'pending' 'missing-in-base' 'missing-in-base' "types.$type" $null $null @() $ignored $unsupported 'merge-with-warning'))|Out-Null}
    }
    $arr=@($entries); $blocked=@($arr|Where-Object{$_.effectiveCatalogAction -eq 'block-resolution'}); $pending=@($arr|Where-Object{$_.classification -eq 'pending'}); $redundant=@($arr|Where-Object{$_.classification -eq 'redundant'}); $divergent=@($arr|Where-Object{$_.classification -eq 'divergent'})
    if($blocked.Count -gt 0){$b=$blocked[0]; $st=if($b.reason -in @('invalid-override-shape','invalid-operational-field')){'INVALID_OVERRIDE_SHAPE'}else{'OVERRIDE_RESOLUTION_BLOCKED'}; return New-GeneXusCatalogOverrideDiagnosticResult -Status $st -OverrideActive:$true -OverridePath $OverridePathForDiagnostics -Reason $b.reason -DiagnosticReason $b.diagnosticReason -FieldPath $b.fieldPath -Message 'Override local bloqueia a resolucao segura do catalogo efetivo.' -Entries $arr -DeclaredUpstreamPending:$declared -EffectiveCatalogAction 'block-resolution'}
    if($pending.Count -gt 0 -or $divergent.Count -gt 0){$r=if($pending.Count -gt 0){'missing-in-base'}else{'field-divergence'}; return New-GeneXusCatalogOverrideDiagnosticResult -Status 'REMINDER_REQUIRED' -OverrideActive:$true -OverridePath $OverridePathForDiagnostics -Reason $r -DiagnosticReason $r -FieldPath $null -Message 'Override local ainda exige alinhamento com a base compartilhada.' -Entries $arr -DeclaredUpstreamPending:$declared -EffectiveCatalogAction 'merge-with-warning'}
    return New-GeneXusCatalogOverrideDiagnosticResult -Status 'CLEANUP_RECOMMENDED' -OverrideActive:$true -OverridePath $OverridePathForDiagnostics -Reason 'equivalent' -DiagnosticReason 'equivalent' -FieldPath $null -Message 'Override local redundante; remocao das entradas equivalentes e recomendada.' -Entries $arr -DeclaredUpstreamPending:$declared -EffectiveCatalogAction 'merge'
}

function Merge-GeneXusObjectTypeCatalog {
    param([object]$BaseCatalog,[object]$OverrideCatalog,[object]$OverrideClassification)
    if($null -eq $OverrideCatalog -or $null -eq $OverrideCatalog.PSObject.Properties['types']){return $BaseCatalog}
    if($null -ne $OverrideClassification -and $OverrideClassification.effectiveCatalogAction -eq 'block-resolution'){throw "OVERRIDE_RESOLUTION_BLOCKED: $($OverrideClassification.reason)"}
    $supported=@('objectTypeGuid','rootKind','folderName','inventoryEligible','queryableByKbIntelligence','containerType','exportTaskLabel','evidenceSummary','wikiLinks','nexaFindings','notes','lastObservedAt')
    $mergedTypes=[ordered]@{}
    foreach($p in $BaseCatalog.types.PSObject.Properties){$h=[ordered]@{}; foreach($ep in $p.Value.PSObject.Properties){$h[$ep.Name]=$ep.Value}; $h['canonicalType']=$p.Name; $mergedTypes[$p.Name]=[pscustomobject]$h}
    foreach($p in $OverrideCatalog.types.PSObject.Properties){$ce=$null; if($null -ne $OverrideClassification){$ce=@($OverrideClassification.classificationEntries|Where-Object{$_.typeName -eq $p.Name}|Select-Object -First 1)}; if($null -ne $ce -and $ce.effectiveCatalogAction -eq 'block-resolution'){continue}; $target=if($null -ne $ce -and -not [string]::IsNullOrWhiteSpace($ce.baseTypeName)){$ce.baseTypeName}else{$p.Name}; $h=[ordered]@{}; if($mergedTypes.Contains($target)){foreach($ep in $mergedTypes[$target].PSObject.Properties){$h[$ep.Name]=$ep.Value}}; foreach($ep in $p.Value.PSObject.Properties){if($ep.Name -in $supported){$h[$ep.Name]=$ep.Value}}; $h['canonicalType']=$target; $mergedTypes[$target]=[pscustomobject]$h}
    [pscustomobject]@{version=if($null -ne $BaseCatalog.PSObject.Properties['version']){$BaseCatalog.version}else{1}; types=[pscustomobject]$mergedTypes}
}

function Resolve-GeneXusObjectTypeCatalogPaths {
    param([string]$BaseCatalogPath,[string]$CatalogOverridePath,[string]$ParallelKbRoot)
    if([string]::IsNullOrWhiteSpace($BaseCatalogPath)){$BaseCatalogPath=Get-GeneXusObjectTypeCatalogDefaultBasePath}
    $classification=Get-GeneXusCatalogOverrideClassification -BaseCatalogPath $BaseCatalogPath -CatalogOverridePath $CatalogOverridePath -ParallelKbRoot $ParallelKbRoot
    if($classification.effectiveCatalogAction -eq 'block-resolution'){throw "OVERRIDE_RESOLUTION_BLOCKED: $($classification.reason) / $($classification.diagnosticReason) at $($classification.overridePath)"}
    $baseCatalog=Read-GeneXusObjectTypeCatalogFile -Path $BaseCatalogPath; $overrideCatalog=$null
    if($classification.overrideActive -and -not [string]::IsNullOrWhiteSpace($classification.overridePath)){$overrideCatalog=Read-GeneXusObjectTypeCatalogFile -Path $classification.overridePath}
    $mergedCatalog=Merge-GeneXusObjectTypeCatalog -BaseCatalog $baseCatalog -OverrideCatalog $overrideCatalog -OverrideClassification $classification
    [pscustomobject]@{BaseCatalogPath=$BaseCatalogPath; OverridePath=$classification.overridePath; OverrideActive=$classification.overrideActive; UpstreamPending=$classification.effectiveUpstreamPending; DeclaredUpstreamPending=$classification.declaredUpstreamPending; EffectiveUpstreamPending=$classification.effectiveUpstreamPending; MergedCatalog=$mergedCatalog; OverrideCatalog=$overrideCatalog; OverrideClassification=$classification}
}

function Get-GeneXusCatalogOverrideSessionReminder {
    param([string]$ParallelKbRoot,[string]$CatalogOverridePath)
    $c=Get-GeneXusCatalogOverrideClassification -CatalogOverridePath $CatalogOverridePath -ParallelKbRoot $ParallelKbRoot
    $msg=$c.message
    if($c.status -eq 'REMINDER_REQUIRED'){$names=@($c.pendingTypeNames+$c.divergentTypeNames)|Sort-Object -Unique; $msg=('CATALOGO_LOCAL_OVERRIDE_ATIVO: esta pasta paralela usa gx-object-type-catalog.override.json. Tipos pendentes/divergentes: {0}. Revise alinhamento com a base compartilhada.' -f ($names -join ', '))}
    [pscustomobject]@{status=$c.status; reminderRequired=$c.reminderRequired; noticeRequired=$c.noticeRequired; cleanupRecommended=$c.cleanupRecommended; blocked=$c.blocked; overrideActive=$c.overrideActive; upstreamPending=$c.effectiveUpstreamPending; declaredUpstreamPending=$c.declaredUpstreamPending; effectiveUpstreamPending=$c.effectiveUpstreamPending; reason=$c.reason; diagnosticReason=$c.diagnosticReason; fieldPath=$c.fieldPath; message=$msg; overridePath=$c.overridePath; pendingTypeNames=$c.pendingTypeNames; pendingTypeGuids=$c.pendingTypeGuids; redundantTypeNames=$c.redundantTypeNames; redundantTypeGuids=$c.redundantTypeGuids; divergentTypeNames=$c.divergentTypeNames; divergentTypeGuids=$c.divergentTypeGuids; blockedTypeNames=$c.blockedTypeNames; blockedTypeGuids=$c.blockedTypeGuids; classificationEntries=$c.classificationEntries}
}

function Get-GeneXusCatalogGuidToFolderMap {
    param([object]$MergedCatalog)

    $map = @{}
    foreach ($property in $MergedCatalog.types.PSObject.Properties) {
        $entry = $property.Value
        if ($null -eq $entry.objectTypeGuid -or [string]::IsNullOrWhiteSpace([string]$entry.objectTypeGuid)) {
            continue
        }

        $folderName = if ($null -ne $entry.PSObject.Properties['folderName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.folderName)) {
            [string]$entry.folderName
        } else {
            [string]$property.Name
        }

        $map[[string]$entry.objectTypeGuid.ToLowerInvariant()] = $folderName
    }

    return $map
}

function Get-GeneXusCatalogGuidToTypeMap {
    param([object]$MergedCatalog)

    $map = @{}
    foreach ($property in $MergedCatalog.types.PSObject.Properties) {
        $entry = $property.Value
        if ($null -eq $entry.objectTypeGuid -or [string]::IsNullOrWhiteSpace([string]$entry.objectTypeGuid)) {
            continue
        }

        $folderName = if ($null -ne $entry.PSObject.Properties['folderName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.folderName)) {
            [string]$entry.folderName
        } else {
            [string]$property.Name
        }

        $map[[string]$entry.objectTypeGuid.ToLowerInvariant()] = [pscustomobject]@{
            TypeName   = [string]$property.Name
            FolderName = $folderName
        }
    }

    return $map
}

function Get-GeneXusExportTaskLabelAliasRules {
    param([object]$MergedCatalog)

    $rules = [System.Collections.Generic.List[object]]::new()
    foreach ($property in $MergedCatalog.types.PSObject.Properties) {
        $entry = $property.Value
        if ($null -eq $entry.PSObject.Properties['exportTaskLabel']) {
            continue
        }

        $exportTaskLabel = [string]$entry.exportTaskLabel
        if ([string]::IsNullOrWhiteSpace($exportTaskLabel)) {
            continue
        }

        $folderName = if ($null -ne $entry.PSObject.Properties['folderName'] -and -not [string]::IsNullOrWhiteSpace([string]$entry.folderName)) {
            [string]$entry.folderName
        } else {
            [string]$property.Name
        }

        [void]$rules.Add([ordered]@{
            exportTaskLabel = $exportTaskLabel.Trim()
            catalogTypeName = [string]$property.Name
            catalogTypeGuid = if ($null -ne $entry.objectTypeGuid) { [string]$entry.objectTypeGuid } else { $null }
            folderName      = $folderName
        })
    }

    return @($rules)
}

function Get-GeneXusXmlObjectOuterSnippet {
    param(
        [System.Xml.XmlNode]$Node,
        [int]$MaxLength = 480
    )

    if ($null -eq $Node) {
        return $null
    }

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.OmitXmlDeclaration = $true
    $settings.Indent = $false
    $settings.NewLineHandling = [System.Xml.NewLineHandling]::None

    $builder = New-Object System.Text.StringBuilder
    $writer = [System.Xml.XmlWriter]::Create($builder, $settings)
    try {
        $Node.WriteTo($writer)
    } finally {
        $writer.Dispose()
    }

    $text = $builder.ToString() -replace '\s+', ' '
    if ($text.Length -le $MaxLength) {
        return $text
    }

    return $text.Substring(0, $MaxLength) + '…'
}

function Get-GeneXusUnknownObjectTypesFromExportFile {
    param(
        [xml]$XmlDocument,
        [hashtable]$GuidToFolderMap,
        [int]$MaxSampleNamesPerGuid = 5,
        [int]$MaxXmlSnippetLength = 480
    )

    $aggregates = @{}

    $objectsNode = $XmlDocument.SelectSingleNode('/ExportFile/Objects')
    if ($null -eq $objectsNode) {
        return @()
    }

    foreach ($node in $objectsNode.SelectNodes('./Object')) {
        $typeGuid = $node.GetAttribute('type')
        if ([string]::IsNullOrWhiteSpace($typeGuid)) {
            continue
        }

        $typeKey = $typeGuid.ToLowerInvariant()
        if ($GuidToFolderMap.ContainsKey($typeKey)) {
            continue
        }

        if (-not $aggregates.ContainsKey($typeKey)) {
            $aggregates[$typeKey] = [pscustomobject]@{
                unknownObjectTypeGuid = $typeGuid
                count                   = 0
                sampleNames             = [System.Collections.Generic.List[string]]::new()
                sampleParents           = [System.Collections.Generic.List[string]]::new()
                sampleParentTypes       = [System.Collections.Generic.List[string]]::new()
                sampleXmlSnippets       = [System.Collections.Generic.List[string]]::new()
                suggestedFolderName     = ('Unknown_{0}' -f $typeKey.Split('-')[0])
            }
        }

        $bucket = $aggregates[$typeKey]
        $bucket.count += 1

        $logicalName = $node.GetAttribute('name')
        if (-not [string]::IsNullOrWhiteSpace($logicalName) -and $bucket.sampleNames.Count -lt $MaxSampleNamesPerGuid) {
            if (-not $bucket.sampleNames.Contains($logicalName)) {
                $bucket.sampleNames.Add($logicalName) | Out-Null
            }
        }

        $parent = $node.GetAttribute('parent')
        if (-not [string]::IsNullOrWhiteSpace($parent) -and $bucket.sampleParents.Count -lt $MaxSampleNamesPerGuid) {
            if (-not $bucket.sampleParents.Contains($parent)) {
                $bucket.sampleParents.Add($parent) | Out-Null
            }
        }

        $parentType = $node.GetAttribute('parentType')
        if (-not [string]::IsNullOrWhiteSpace($parentType) -and $bucket.sampleParentTypes.Count -lt $MaxSampleNamesPerGuid) {
            if (-not $bucket.sampleParentTypes.Contains($parentType)) {
                $bucket.sampleParentTypes.Add($parentType) | Out-Null
            }
        }

        if ($bucket.sampleXmlSnippets.Count -lt 2) {
            $snippet = Get-GeneXusXmlObjectOuterSnippet -Node $node -MaxLength $MaxXmlSnippetLength
            if (-not [string]::IsNullOrWhiteSpace($snippet) -and -not $bucket.sampleXmlSnippets.Contains($snippet)) {
                $bucket.sampleXmlSnippets.Add($snippet) | Out-Null
            }
        }
    }

    return @(
        $aggregates.GetEnumerator() |
            Sort-Object Name |
            ForEach-Object {
                [pscustomobject]@{
                    unknownObjectTypeGuid = $_.Value.unknownObjectTypeGuid
                    count                   = $_.Value.count
                    sampleNames             = @($_.Value.sampleNames)
                    sampleParents           = @($_.Value.sampleParents)
                    sampleParentTypes       = @($_.Value.sampleParentTypes)
                    sampleXmlSnippets       = @($_.Value.sampleXmlSnippets)
                    suggestedFolderName     = $_.Value.suggestedFolderName
                }
            }
    )
}

function Format-GeneXusUnknownObjectTypesErrorMessage {
    param(
        [object[]]$UnknownTypes,
        [bool]$OverrideActive
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $UnknownTypes) {
        $namePart = if ($entry.sampleNames.Count -gt 0) {
            (' names={0}' -f (($entry.sampleNames | Select-Object -First 3) -join ', '))
        } else {
            ''
        }
        $parentPart = if ($entry.sampleParents.Count -gt 0) {
            (' parent={0}' -f (($entry.sampleParents | Select-Object -First 2) -join ', '))
        } else {
            ''
        }
        $parentTypePart = if ($entry.sampleParentTypes.Count -gt 0) {
            (' parentType={0}' -f (($entry.sampleParentTypes | Select-Object -First 2) -join ', '))
        } else {
            ''
        }
        $lines.Add(('{0} [{1}]{2}{3}{4}' -f $entry.unknownObjectTypeGuid, $entry.count, $namePart, $parentPart, $parentTypePart)) | Out-Null
    }

    $suffix = 'Update scripts\gx-object-type-catalog.json and 01a-catalogo-e-padroes-empiricos.md in GeneXus-XPZ-Skills, or register an approved local override (gx-object-type-catalog.override.json) after explicit user consent.'
    if ($OverrideActive) {
        $suffix = 'Some types may still be missing from the merged catalog. Review gx-object-type-catalog.override.json and upstream GeneXus-XPZ-Skills catalog alignment.'
    }

    return ('Package contains object type GUIDs not mapped to destination folders: {0}. {1}' -f (($lines -join '; ')), $suffix)
}

function Write-GeneXusUnknownTypeDiscoveryReport {
    param(
        [string]$Path,
        [object[]]$UnknownTypes,
        [object]$CatalogResolution,
        [string]$InputPath
    )

    $payload = [ordered]@{
        generatedAt          = (Get-Date).ToString('o')
        inputPath            = $InputPath
        catalogBasePath      = $CatalogResolution.BaseCatalogPath
        catalogOverridePath  = $CatalogResolution.OverridePath
        catalogOverrideActive = $CatalogResolution.OverrideActive
        upstreamPending      = $CatalogResolution.UpstreamPending
        unknownTypes         = $UnknownTypes
        resolutionHints      = [ordered]@{
            recommendedSources = @('XPZ/XML evidence', 'nexa skill (with user consent)', 'docs.genexus.com / wiki.genexus.com official documentation')
            localOverrideFile  = 'scripts/gx-object-type-catalog.override.json under parallel KB root'
            upstreamCatalog    = 'GeneXus-XPZ-Skills scripts/gx-object-type-catalog.json + 01a-catalogo-e-padroes-empiricos.md'
        }
    }

    $json = ($payload | ConvertTo-Json -Depth 10)
    $dir = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($dir) -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $json, (Get-Utf8NoBomEncoding))
}

function New-GeneXusUnknownTypeMaintainerPromptText {
    param(
        [object[]]$UnknownTypes,
        [string]$KbName = $null,
        [string]$GeneXusVersion = $null,
        [string[]]$WikiLinks = @(),
        [string]$NexaFindings = $null
    )

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.AppendLine('## Pedido: registrar tipo(s) no catálogo GeneXus-XPZ-Skills')
    [void]$builder.AppendLine()
    [void]$builder.AppendLine('Contexto: sync XPZ/XML bloqueado por GUID de tipo não mapeado no catálogo compartilhado.')
    if (-not [string]::IsNullOrWhiteSpace($KbName)) {
        [void]$builder.AppendLine("- KB: $KbName")
    }
    if (-not [string]::IsNullOrWhiteSpace($GeneXusVersion)) {
        [void]$builder.AppendLine("- GeneXus: $GeneXusVersion")
    }
    [void]$builder.AppendLine()

    foreach ($entry in $UnknownTypes) {
        [void]$builder.AppendLine("### Tipo desconhecido: $($entry.unknownObjectTypeGuid)")
        [void]$builder.AppendLine("- Contagem no pacote: $($entry.count)")
        if ($entry.sampleNames.Count -gt 0) {
            [void]$builder.AppendLine(('- Amostra de nomes: {0}' -f (($entry.sampleNames -join ', '))))
        }
        if ($entry.sampleParents.Count -gt 0) {
            [void]$builder.AppendLine(('- parent: {0}' -f (($entry.sampleParents -join ', '))))
        }
        if ($entry.sampleParentTypes.Count -gt 0) {
            [void]$builder.AppendLine(('- parentType: {0}' -f (($entry.sampleParentTypes -join ', '))))
        }
        [void]$builder.AppendLine(('- folderName sugerido (provisório): {0}' -f $entry.suggestedFolderName))
        if ($entry.sampleXmlSnippets.Count -gt 0) {
            [void]$builder.AppendLine('- Snippet XML (evidência):')
            [void]$builder.AppendLine('```xml')
            [void]$builder.AppendLine($entry.sampleXmlSnippets[0])
            [void]$builder.AppendLine('```')
        }
        [void]$builder.AppendLine()
    }

    if ($WikiLinks.Count -gt 0) {
        [void]$builder.AppendLine('### Referências wiki/docs')
        foreach ($link in $WikiLinks) {
            [void]$builder.AppendLine("- $link")
        }
        [void]$builder.AppendLine()
    }

    if (-not [string]::IsNullOrWhiteSpace($NexaFindings)) {
        [void]$builder.AppendLine('### Achados nexa (com consentimento do usuário)')
        [void]$builder.AppendLine($NexaFindings)
        [void]$builder.AppendLine()
    }

    [void]$builder.AppendLine('### Ação solicitada no repositório GeneXus-XPZ-Skills')
    [void]$builder.AppendLine('- Entrada em `scripts/gx-object-type-catalog.json` (`objectTypeGuid`, `folderName`, flags alinhadas aos tipos vizinhos).')
    [void]$builder.AppendLine('- Linha correspondente em `01a-catalogo-e-padroes-empiricos.md`.')
    [void]$builder.AppendLine('- Self-test / regressão de descoberta de tipo desconhecido, se aplicável.')
    [void]$builder.AppendLine()
    [void]$builder.AppendLine('FIM DO PROMPT')

    return $builder.ToString()
}
