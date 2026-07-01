# API GAM runtime — precondition and enforcement smoke

Satellite of [api.md](api.md). This covers **Face 2 (runtime GAM configuration)** and **Face 3 (runtime proof)**. Runtime GAM configuration is **out of XPZ automation scope** (manual GAM admin UI); this file is a **precondition that blocks an unwarranted "secure" conclusion**. An `API` generated as `GAMSecurityLevel.SecurityHigh` with GAM permissions created by BuildAll is **NOT proven secure** until the steps below pass.

All HTTP/OAuth/C# facts here are dated **GeneXus 18 / KMW 4.0.187794 + GAM 3.15.78**; re-verify on other versions.

## Why this exists — the security false-positive

Empirically observed: with `Authorization` (`SecurityHigh`) and permissions created by BuildAll, but the GAM application's **"Habilitar autorização?"** (Enable authorization?) checkbox **OFF**, an authenticated user **without** the API role still received **HTTP 200**. `SecurityHigh` in C# + permission created in the build **does not prove enforcement**. Enforcement is only proven by the runtime smoke below.

## Runtime GAM precondition (manual — GAM admin UI, out of automation)

Perform in the **correct GAM application** — identify it by **name and ApplicationId**, NOT "GAM Backoffice"; validating "Habilitar autorização?" on Backoffice proves nothing about the API's application. (UI labels shown are from a pt-BR install; they may be localized.)

1. Application (e.g. `wsEducacaoSpTeste`): **"Habilitar autorização?"** = ON.
2. **"Permitir autenticação REST v2.0?"** = ON; the application has `client_id` + a valid `client_secret`.
3. Confirm the `<apiname>_Services_*` permissions exist in this application (created by BuildAll).
4. Create/reuse a technical role; assign the API permissions to it (`FullControl` and/or each specific `*_Services_*`).
5. Bind the role to the technical user. Direct-permission screen may be empty while the user inherits via role — check roles, not just direct permissions.

## OAuth token (GAM v2.0)

Endpoint pattern: `POST /<app-deployment>/oauth/gam/v2.0/access_token`. Minimal form that yields a token:

    grant_type=password
    client_id=<application id>
    client_secret=<application secret>
    username=<active GAM user>
    password=<user password>
    scope=gam_user_data

Error codes to recognize (they are failure signals, not success): **542** REST OAuth v2.0 disabled on the application; **116** invalid application secret; **232** missing `scope` when the app requires user scopes; **79** username not provided.

## 2-phase enforcement smoke (mandatory before declaring "secure")

- **Phase A — before granting permission:** anonymous call → **401** (missing `Authorization` header); authenticated user **without** the API role → **403** (`{"error":{"code":"139","message":"Não autorizado: acesso negado."}}`).
- **Phase B — after granting:** authenticated user **with** the role → **200**.
- **Reversibility (proves enforcement is live, recommended):** revoke the role from the user, request a fresh token, call again → **403**. Empirically confirmed (200 → 403 on revoke): GAM checks authorization per request against current permissions.
- Reliable evidence = C# `GAMSecurityLevel.SecurityHigh` **+** BuildAll permission creation **+** the HTTP codes above. **NOT** OpenAPI alone (it shows `oAuthGXGAM` even for `SecurityLevel(None)`), **NOT** a valid token alone (a token proves authentication, not authorization).

## Request/response specifics (dated)

- **Body envelope:** for a service with a path parameter **and** an input SDT in the body, the runtime expects the body **enveloped by the variable name** (`{"sdtProdutoRequest":{...}}`); a direct body returns **500**. Document this as an explicit consumption contract.
- **PUT limitation:** `PUT` may return **404 before reaching the GeneXus runtime** (IIS/environment specific). This is **not** a platform contract — either use an explicit operational route (`POST .../alteracao`) as a documented fallback, or investigate the IIS configuration. Do not cristallize PUT-vs-POST as a design decision from one environment.

## Multi-environment

State explicitly which environment was proven. The deployed/served output directory may differ from the KB's active environment (e.g. served `NETFrameworkSQLServer004\web` while active env is `NETPostgreSQL`). Prove enforcement on the environment actually served; list other environments as pending.

## Residue

If the smoke creates data (insert) and there is no delete endpoint, record the residue explicitly (ids created); do not hide the side effect.

## Sub-state

Until the 2-phase smoke passes, keep the post-build sub-state `operação concluída, pendente de confirmação funcional` (from `xpz-msbuild-build/SKILL.md`). Passing import + BuildAll is **not** "secure".
