---
name: xpz-codex-apply-patch-alternative
description: Aplica patch textual Git já aprovado no Codex sem usar apply_patch.
---

# Aplicação aprovada de patch no Codex

Use esta skill somente na raiz deste repositório e somente depois de aprovação humana explícita para os caminhos afetados.

1. Gere um patch unificado textual em UTF-8 sem BOM e com LF, sem binário, rename, copy ou troca de modo. O cabeçalho `diff --git a/<caminho> b/<caminho>` é obrigatório; o cabeçalho `index` é opcional. Arquivos textuais regulares `100644`, inclusive criação ou deleção, são aceitos.
2. Na rota canônica desta skill, quando o chamador usa `ProcessStartInfo.ArgumentList`, aplique um patch e um `-AllowedPath` por ciclo: envie o Base64 contíguo ao `-DryRun` por `StandardInput.Write(...)` e feche com `StandardInput.Close()`. Não use `WriteLine` nem pipe, pois ambos podem acrescentar newline/whitespace ao Base64. Esta é uma limitação da rota de chamada recomendada, não do motor: ele continua exigindo que `-AllowedPath` corresponda ao conjunto completo e exato de caminhos do patch.
3. Para vários arquivos nessa rota, repita ciclos independentes de stage → apply, um por arquivo. Não há atomicidade entre ciclos já aplicados.
4. Leia o JSON de retorno e guarde `stagedPatchId` e `patchSha256`.
5. Chame o mesmo motor com `-StagedPatchId` e `-ExpectedPatchSha256`; não reenvie o patch.
6. Releia o trecho alterado e execute a validação pertinente.

O motor bloqueia contexto Git inadequado, caminhos divergentes, patch binário/rename/copy/modo não textual, atributos transformadores, alterações preparadas no índice e divergência de pré-imagem. Ele não faz commit, push, checkout, reset ou rollback automático.

Para validar o motor, execute `pwsh -NoProfile -File scripts/Test-ApplyApprovedPatchSelfTest.ps1` e exija o token `APPLY_APPROVED_PATCH_SELFTEST_OK`.
