// Sanitized excerpt from @jkudish/jev-mcp@0.13.0 dist/provider.js
// Source: npm tarball sha512-0fFOAJwlsntMdHu4+t40H4BObOowfqVsZdMnU1tbqIHojbWotRia8quh8/SjEtwpC0CbemZF9TpBDbFNBhnRGw==
// Captured: 2026-11-09. Scope: compatible mode resolve + fetch transport.

// --- resolve(env), lines 195-213 ---
function resolve(env) {
    const explicit = (env.JEV_PROVIDER ?? "auto").toLowerCase();
    const hasCompatible = Boolean(env.JEV_API_KEY && env.JEV_API_BASE_URL);
    if (explicit === "compatible") {
        const missing = ["JEV_API_KEY", "JEV_API_BASE_URL"].filter((name) => !env[name]);
        if (missing.length > 0) {
            throw new Error(`JEV_PROVIDER=compatible but ${missing.join(" and ")} ${missing.length > 1 ? "are" : "is"} not set. ` +
                "JEV_MCP_MODEL is optional and defaults to jev-latest.");
        }
        return "compatible";
    }
    // The published package owns the four built-in credential rules and order.
    if ((explicit === "auto" || explicit === "") && hasCompatible &&
        !env.TYPESAFE_API_KEY && !/^sk-or-/.test(env.OPENROUTER_API_KEY ?? "") &&
        !((env.JEV_CLOUDFLARE_API_TOKEN || env.CLOUDFLARE_API_TOKEN) && env.CLOUDFLARE_ACCOUNT_ID) &&
        !env.AI_GATEWAY_API_KEY)
        return "compatible";
    return resolveTransport({ ...env, JEV_PROVIDER: explicit || "auto" }).name;
}

// --- compatible transport, lines 307-362 ---
    if (provider === "compatible") {
        const deadline = deadlineSignal(signal, REQUEST_TIMEOUT_MS);
        try {
            const response = await fetchWithResilience(process.env.JEV_API_BASE_URL, {
                method: "POST",
                headers: {
                    Authorization: `Bearer ${process.env.JEV_API_KEY}`,
                    "Content-Type": "application/json",
                },
                body: JSON.stringify({ model, state, questions }),
            }, deadline);
            const bodyText = await readBodyBounded(response, deadline);
            if (!response.ok) {
                // Client-visible errors stay fixed-string: provider name and numeric
                // status only — a reflecting proxy can echo nothing back through them.
                throw new Error(`Jev-compatible endpoint ${response.status}`);
            }
            let body;
            try {
                body = JSON.parse(bodyText);
            }
            catch {
                body = null; // parse failures never retry; surface as invalid response
            }
            const invalid = (why) => new Error(`Jev-compatible endpoint returned an invalid response: ${why}`);
            if (!isRecord(body))
                throw invalid("expected a JSON object.");
            if (!isRecord(body.answers))
                throw invalid("expected an answers object.");
            // Envelope shape is validated here; per-question answer validity is the
            // tools' job. Each tool fails closed under its invalid_response contract,
            // so a missing or malformed answer can never reach tool-level defaults.
            let inputTokens = 0;
            let outputTokens = 0;
            if (body.usage !== undefined && body.usage !== null) {
                const tokenCount = (v) => typeof v === "number" && Number.isFinite(v) && v >= 0;
                if (!isRecord(body.usage) || !tokenCount(body.usage.input_tokens) || !tokenCount(body.usage.output_tokens)) {
                    throw invalid("usage must report finite non-negative input_tokens and output_tokens.");
                }
                inputTokens = body.usage.input_tokens;
                outputTokens = body.usage.output_tokens;
            }
            if (body.model !== undefined && body.model !== null && typeof body.model !== "string") {
                throw invalid("model must be absent or a string.");
            }
            return {
                answers: body.answers,
                usage: { input_tokens: inputTokens, output_tokens: outputTokens },
                provider,
                model: typeof body.model === "string" ? body.model : model,
            };
        }
        finally {
            deadline.dispose();
        }
    }
