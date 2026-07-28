---
name: xpz-codex-apply-patch-alternative
description: Backup auditável para aplicar patch textual Git já aprovado no Codex, em um repositório alvo, quando a rota nativa apply_patch estiver indisponível, falhar antes de escrita local ou for solicitada explicitamente.
---

# Backup auditável de patch no Codex

Use esta skill como backup auditável da rota nativa `apply_patch`, e somente depois de aprovação humana explícita para os caminhos afetados.

Ela pode ser usada fora da raiz `GeneXus-XPZ-Skills` quando estiver disponível na sessão por registro global, symlink, junction ou caminho publicado equivalente. Nesse caso, trate o repositório alvo como contexto operacional explícito e passe sua raiz em `-RepositoryRoot`; essa raiz deve ser uma work tree Git não-bare na branch `main`. Não copie o motor para o repositório alvo nem presuma que ele exista localmente em `scripts/`.

1. Gere um patch unificado textual em UTF-8 sem BOM e com LF, sem binário, rename, copy ou troca de modo. O cabeçalho `diff --git a/<caminho> b/<caminho>` é obrigatório; o cabeçalho `index` é opcional. Arquivos textuais regulares `100644`, inclusive criação ou deleção, são aceitos.
2. Na rota de backup desta skill, `pwsh -File` recebe argv literal, inclusive quando o chamador o monta com `ProcessStartInfo.ArgumentList`. Nessa forma, `-AllowedPath` repetido não é associado ao parâmetro array: a falha acontece antes do motor, não emite JSON no stdout e deixa o diagnóstico do binder no stderr. Aplique um patch e um `-AllowedPath` por ciclo. Envie o Base64 contíguo ao `-DryRun` por `StandardInput.Write(...)` e feche com `StandardInput.Close()`. Não use `WriteLine` nem pipe, pois ambos podem acrescentar newline/whitespace ao Base64. Essa limitação é da forma de invocação, não do motor: o motor continua exigindo que `-AllowedPath` corresponda ao conjunto completo e exato de caminhos do patch.
3. Para vários arquivos nessa rota, repita ciclos independentes de stage → apply, um por arquivo. Não há atomicidade entre ciclos já aplicados.
4. Leia o JSON de retorno e guarde `stagedPatchId` e `patchSha256`.
5. Chame o mesmo motor com `-StagedPatchId` e `-ExpectedPatchSha256`; não reenvie o patch.
6. Releia o trecho alterado e execute a validação pertinente.

O motor bloqueia contexto Git inadequado, caminhos divergentes, patch binário/rename/copy/modo não textual, atributos transformadores, alterações preparadas no índice e divergência de pré-imagem. Ele não faz commit, push, checkout, reset ou rollback automático.

Para validar o motor, execute `pwsh -NoProfile -File scripts/Test-ApplyApprovedPatchSelfTest.ps1` a partir da raiz publicada da skill/motor, ou use o caminho absoluto equivalente resolvido a partir desta skill, e exija o token `APPLY_APPROVED_PATCH_SELFTEST_OK`. Não execute esse comando como relativo ao repositório alvo salvo se ele for a própria raiz do motor. O self-test cobre Base64 sem newline, caminhos compostos (binding repetido e CSV), CRLF, criação e deleção, e ciclo misto entre grafias curta/longa da raiz quando o alias curto está disponível.
