---
name: xpz-codex-apply-patch-alternative
description: Aplica patch textual Git já aprovado no Codex sem usar apply_patch.
---

# Aplicação aprovada de patch no Codex

Use esta skill somente na raiz deste repositório e somente depois de aprovação humana explícita para os caminhos afetados.

1. Gere um patch unificado textual UTF-8/ASCII sem binário, rename, copy ou alteração de modo.
2. Envie o Base64 contíguo do patch para `scripts/Apply-ApprovedPatch.ps1` com `-DryRun`, `-RepositoryRoot` e a lista completa/exata de `-AllowedPath`.
3. Leia o JSON de retorno e guarde `stagedPatchId` e `patchSha256`.
4. Chame o mesmo motor com `-StagedPatchId` e `-ExpectedPatchSha256`; não reenvie o patch.
5. Releia o trecho alterado e execute a validação pertinente.

O motor bloqueia contexto Git inadequado, caminhos divergentes, patch binário/rename/copy/modo não textual, atributos transformadores, alterações preparadas no índice e divergência de pré-imagem. Ele não faz commit, push, checkout, reset ou rollback automático.

Para validar o motor, execute `pwsh -NoProfile -File scripts/Test-ApplyApprovedPatchSelfTest.ps1` e exija o token `APPLY_APPROVED_PATCH_SELFTEST_OK`.
