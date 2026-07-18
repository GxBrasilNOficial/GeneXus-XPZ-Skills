#requires -Version 7.4
[CmdletBinding()]
param([switch]$AsJson)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
function Run([string]$file,[string[]]$ArgumentList,[string]$InputText='') {
  $s=[Diagnostics.ProcessStartInfo]::new($file); $s.UseShellExecute=$false; $s.RedirectStandardInput=$true; $s.RedirectStandardOutput=$true; $s.RedirectStandardError=$true
  foreach($a in $ArgumentList){[void]$s.ArgumentList.Add($a)}
  $p=[Diagnostics.Process]::new();$p.StartInfo=$s;[void]$p.Start();if($InputText.Length){$p.StandardInput.Write($InputText)};$p.StandardInput.Close();$o=$p.StandardOutput.ReadToEnd();$e=$p.StandardError.ReadToEnd();$p.WaitForExit();[pscustomobject]@{exit=$p.ExitCode;out=$o;err=$e}
}
$t=Join-Path ([IO.Path]::GetTempPath()) ('a2-'+[guid]::NewGuid().ToString('N'))
try {
 New-Item -ItemType Directory $t|Out-Null;Run git @('-C',$t,'init','-b','main')|Out-Null;Run git @('-C',$t,'config','user.email','a@b.c')|Out-Null;Run git @('-C',$t,'config','user.name','A2')|Out-Null;Run git @('-C',$t,'config','core.autocrlf','false')|Out-Null
 [IO.File]::WriteAllText((Join-Path $t 'allowed.txt'),"one`n",[Text.UTF8Encoding]::new($false));Run git @('-C',$t,'add','allowed.txt')|Out-Null;Run git @('-C',$t,'commit','-m','i')|Out-Null
 [IO.File]::WriteAllText((Join-Path $t 'allowed.txt'),"two`n",[Text.UTF8Encoding]::new($false));$d=Run git @('-C',$t,'diff','--','allowed.txt');[IO.File]::WriteAllText((Join-Path $t 'allowed.txt'),"one`n",[Text.UTF8Encoding]::new($false))
 $engine=Join-Path ([IO.Path]::GetDirectoryName($PSCommandPath)) 'Apply-ApprovedPatch.ps1';$dry=Run pwsh @('-NoProfile','-File',$engine,'-RepositoryRoot',$t,'-AllowedPath','allowed.txt','-DryRun') ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($d.out)));$j=$dry.out|ConvertFrom-Json;if($dry.exit -ne 0 -or $j.code -ne 'DRY_RUN_OK'){throw "dry: $($dry.out) $($dry.err)"}
 $apply=Run pwsh @('-NoProfile','-File',$engine,'-RepositoryRoot',$t,'-AllowedPath','allowed.txt','-StagedPatchId',$j.stagedPatchId,'-ExpectedPatchSha256',$j.patchSha256);$a=$apply.out|ConvertFrom-Json;if($apply.exit -ne 0 -or $a.code -ne 'APPLIED'){throw "apply: $($apply.out) $($apply.err)"};if([IO.File]::ReadAllText((Join-Path $t 'allowed.txt')) -ne "two`n"){throw 'bytes'};if($AsJson){[pscustomobject]@{status='pass';code='SELFTEST_OK';token='APPLY_APPROVED_PATCH_SELFTEST_OK'}|ConvertTo-Json -Compress}else{'APPLY_APPROVED_PATCH_SELFTEST_OK'}
} finally {if(Test-Path $t){Remove-Item -LiteralPath $t -Recurse -Force}}
