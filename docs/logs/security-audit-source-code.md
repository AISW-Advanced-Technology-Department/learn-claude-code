# Security Audit: Application Source Code Analysis

## Executive Summary
This application is a static-export Next.js documentation site with no server runtime, no API surface, no authentication flows, and no direct user input processing. Most scanner-flagged patterns are present, but in this architecture they are generally non-exploitable unless an attacker can already modify trusted source content or the build/deployment pipeline. Overall risk is **low**, with the most meaningful improvement opportunity being defense-in-depth hardening (notably CSP/security headers and optional HTML sanitization discipline).

## Finding 1: `dangerouslySetInnerHTML` in doc-renderer.tsx
### Description
`DocRenderer` renders HTML generated from markdown and injects it via `dangerouslySetInnerHTML`. The markdown pipeline enables raw HTML parsing (`allowDangerousHtml: true` + `rehypeRaw`) and does not apply `rehype-sanitize`.

### Exploitable: NO

### Attack Scenario
In this repository’s current model, markdown content is sourced from committed files under `docs/` and transformed at build time to static JSON. There is no user-submitted markdown, no runtime content ingestion, and no API endpoint that can be abused to inject payloads. Practical exploitation therefore requires upstream compromise (e.g., malicious commit, compromised maintainer credentials, or CI/CD tampering). If that trust boundary is broken, arbitrary script-capable HTML could be emitted and executed client-side.

### Severity: Low

### Evidence (code reference)
- `web/src/components/docs/doc-renderer.tsx`
  - `remarkRehype, { allowDangerousHtml: true }`
  - `.use(rehypeRaw)`
  - `<div className="prose-custom" dangerouslySetInnerHTML={{ __html: html }} />`

### Recommendation
- Keep severity aligned with architecture (low for current threat model).
- Add defense-in-depth controls:
  1. Prefer disabling raw HTML in markdown unless explicitly required.
  2. If raw HTML must remain, add `rehype-sanitize` with a strict allowlist.
  3. Enforce branch protection, signed commits, CODEOWNERS review, and CI integrity checks to protect the content supply chain.

## Finding 2: `dangerouslySetInnerHTML` in layout.tsx
### Description
`layout.tsx` injects an inline script using `dangerouslySetInnerHTML` to apply dark theme preference before hydration.

### Exploitable: NO

### Attack Scenario
The injected script is a static literal authored in source code and does not include attacker-controlled interpolation. There is no user input path into this sink. Exploitation again requires source-code or build artifact compromise, which is outside normal remote attacker capability for this app.

### Severity: Info

### Evidence (code reference)
- `web/src/app/[locale]/layout.tsx`
  - `<script dangerouslySetInnerHTML={{ __html: \`(function() { ... })();\` }} />`

### Recommendation
- Keep as-is if early theme bootstrapping is required.
- For hardening, pair with CSP nonce/hash strategy or migrate to framework-supported safe script injection patterns while preserving no-FOUC behavior.
- Under a strict CSP, this inline theme script will not execute unless you provide an explicit nonce or hash.

## Finding 3: `RegExp.exec` in extract-content.ts
### Description
Build-time extractor uses a global regex with `exec` in a loop to collect tool names.

### Exploitable: NO

### Attack Scenario
Pattern `/"name"\s*:\s*"(\w+)"/g` is linear and does not exhibit catastrophic backtracking characteristics. Input is local repository source read during trusted build-time execution. There is no runtime user input channel to trigger ReDoS.

### Severity: Info

### Evidence (code reference)
- `web/scripts/extract-content.ts`
  - `const toolPattern = /"name"\s*:\s*"(\w+)"/g;`
  - `while ((m = toolPattern.exec(source)) !== null) { ... }`

### Recommendation
- No urgent security action required.
- Optional robustness: cap file sizes processed in CI and add unit tests for malformed/large inputs as a resilience measure.

## Finding 4: `fs` operations in extract-content.ts
### Description
Build script performs filesystem reads/writes using Node `fs` and hardcoded directories resolved from `__dirname`.

### Exploitable: NO

### Attack Scenario
Path traversal risk is not practically present because paths are not derived from user input or request parameters. Operations occur at build time in trusted CI/local dev context against fixed paths (`agents`, `docs`, generated output directory). Abuse would require repository or pipeline compromise.

### Severity: Info

### Evidence (code reference)
- `web/scripts/extract-content.ts`
  - `const AGENTS_DIR = path.join(REPO_ROOT, "agents");`
  - `const DOCS_DIR = path.join(REPO_ROOT, "docs");`
  - `const OUT_DIR = path.join(WEB_DIR, "src", "data", "generated");`
  - `fs.readdirSync(...)`, file reads/writes under these constants

### Recommendation
- Maintain current hardcoded path model.
- Add CI guardrails: least-privilege build runners, immutable build steps, and integrity monitoring for generated artifacts.

## Finding 5: `window.location.href` in header.tsx
### Description
Locale switcher performs client-side navigation by assigning `window.location.href` from transformed pathname.

### Exploitable: NO

### Attack Scenario
`newLocale` is selected exclusively from hardcoded values (`en`, `zh`, `ja`), and the operation is a local path replacement, not a user-controlled absolute URL assignment. Therefore this is not an open redirect in current implementation.

### Severity: Info

### Evidence (code reference)
- `web/src/components/layout/header.tsx`
  - `const LOCALES = [{ code: "en" }, { code: "zh" }, { code: "ja" }]`
  - `const newPath = pathname.replace(\`/${locale}\`, \`/${newLocale}\`);`
  - `window.location.href = newPath;`

### Recommendation
- No vulnerability under current constraints.
- Optional improvement: use `next/navigation` router push/replace for idiomatic navigation and easier future policy enforcement.

## Finding 6: `as any` type coercion in i18n.tsx
### Description
Translation accessor uses `(messages as any)[namespace]` and `(ns as any)[key]`, bypassing TypeScript compile-time guarantees.

### Exploitable: NO

### Attack Scenario
Prototype pollution concern is theoretical unless attacker controls `namespace`/`key` at runtime. Here, namespace usage is from hardcoded component literals (e.g., `"nav"`), and messages are static bundled JSON files. No user input path exists to inject `__proto__`, `constructor`, or similar keys.

### Severity: Info

### Evidence (code reference)
- `web/src/lib/i18n.tsx`
  - `const ns = namespace ? (messages as any)[namespace] : messages;`
  - `return (ns as any)[key] || key;`

### Recommendation
- Security risk is negligible in current design.
- Improve type safety to reduce future regression risk: strongly type namespaces/keys and avoid `any` where feasible.

## Finding 7: Dynamic property access in layout.tsx
### Description
Metadata selection performs `metaMessages[locale] || metaMessages.en` using locale from route params.

### Exploitable: NO

### Attack Scenario
In static export mode, locales are generated from hardcoded `generateStaticParams()` (`en`, `zh`, `ja`) at build time. There is no runtime dynamic route handler processing arbitrary attacker-controlled locales, and fallback to `en` prevents undefined access impact.

### Severity: Info

### Evidence (code reference)
- `web/src/app/[locale]/layout.tsx`
  - `const locales = ["en", "zh", "ja"];`
  - `generateStaticParams() { return locales.map(...) }`
  - `const messages = metaMessages[locale] || metaMessages.en;`

### Recommendation
- Current behavior is acceptable.
- Optional hardening: explicit locale type union and runtime assertion for defense-in-depth if architecture changes later.

## Additional Vulnerability Analysis

### XSS Vectors (beyond the 7 findings)
- **Current practical exposure:** Low.
- The only meaningful XSS route is content supply-chain compromise (malicious markdown/source commit or compromised CI artifact generation).
- There is no reflected/stored XSS vector from user input, query/body parameters, forms, or runtime APIs.
- `postProcessHtml` regex replacements in `web/src/components/docs/doc-renderer.tsx` do not introduce new XSS vectors by themselves; they perform fixed class-attribute rewrites and do not execute input or expand attacker control beyond already-present HTML.
- If architecture changes to ingest external/user content, risk would immediately increase and require sanitizer + strict CSP as mandatory controls.

### Prototype Pollution
- No obvious pollution sink reachable from attacker-controlled data.
- Dynamic object access exists but is bounded by static code paths and static message catalogs.
- Current exploitability: negligible.

### Open Redirect
- `window.location.href` usage is constrained to same-site locale paths from hardcoded locale values.
- No attacker-controlled scheme/host/path injection path identified.
- Current exploitability: none.

### Path Traversal
- Filesystem access is build-time only with fixed paths derived from trusted constants.
- No tainted path input from requests/users.
- Current exploitability: none.

### ReDoS
- Regex usage shown is simple and linear; no high-risk nested quantifier patterns.
- Not exposed to untrusted runtime input.
- Current exploitability: none.

### Supply Chain Risks
- This is the **primary realistic risk domain**:
  - Dependency compromise (npm packages)
  - Malicious or unauthorized repository changes
  - CI/CD token or runner compromise
- Dependency ranges include caret (`^`) specifiers in `package.json`; while lockfiles help reproducibility, CI should use lockfile-enforcing installs to prevent unintended drift.
- Because app content is trusted at build time, compromise of source/build chain directly translates to client-side impact.
- Recommended controls: lockfile discipline, Dependabot/SCA, branch protection, signed commits/tags, required reviews, least-privilege CI tokens, provenance/attestations where possible, and **`npm ci` in CI**.

### CSP / Security Headers
- No CSP configured; this weakens browser-enforced mitigation if malicious script reaches output.
- For a static site, strong headers are low-cost/high-value hardening.
- Recommended baseline:
  - `Content-Security-Policy` (prefer strict `script-src` with nonces/hashes; avoid broad `unsafe-inline` long-term)
  - `X-Content-Type-Options: nosniff`
  - `Referrer-Policy: strict-origin-when-cross-origin`
  - `X-Frame-Options: DENY` (or `frame-ancestors 'none'` in CSP)
  - `Permissions-Policy` minimal allowlist
  - `Strict-Transport-Security` (on apex/domain serving HTTPS)
- Important implementation detail: because `web/src/app/[locale]/layout.tsx` includes an inline theme script, a strict CSP requires either a nonce on that script or a matching hash in `script-src`.
- Example `vercel.json` headers baseline:
  ```json
  {
    "headers": [
      {
        "source": "/(.*)",
        "headers": [
          {
            "key": "Content-Security-Policy",
            "value": "default-src 'self'; script-src 'self' 'sha256-REPLACE_WITH_THEME_SCRIPT_HASH'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
          },
          { "key": "X-Content-Type-Options", "value": "nosniff" },
          { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
          { "key": "X-Frame-Options", "value": "DENY" },
          { "key": "Permissions-Policy", "value": "camera=(), microphone=(), geolocation=()" }
        ]
      }
    ]
  }
  ```

### Clickjacking
- No explicit clickjacking protection is currently documented/configured (`X-Frame-Options` and CSP `frame-ancestors`).
- For this documentation site, practical risk is low, but adding `X-Frame-Options: DENY` or CSP `frame-ancestors 'none'` is still recommended as low-cost hardening.

### Other Observations
- Architecture materially reduces remote attack surface (no backend, no auth/session state, no server-side business logic).
- Main residual risk is integrity of repository, dependencies, and deployment workflow—not direct runtime exploitation from external user input.
- `suppressHydrationWarning` in `layout.tsx` is not a security concern by itself; it is a React hydration-noise suppression mechanism, not an input sink.

## Prioritized Recommendations

### Must-do
1. Enforce lockfile-based dependency installation in CI with **`npm ci`**.
2. Configure baseline security headers (especially CSP + clickjacking controls).
3. Protect the content/build trust boundary: branch protection, required reviews, and least-privilege CI credentials.

### Should-do
1. Add CSP nonce/hash handling for the inline theme script in `layout.tsx`.
2. Add/verify automated dependency monitoring (Dependabot or equivalent SCA).
3. Consider `rehype-sanitize` (strict allowlist) if raw HTML in markdown remains enabled long-term.

### Nice-to-have
1. Improve TypeScript strictness around i18n key access to reduce future misuse risk.
2. Add resilience tests around build-time parsing and content processing edge cases.
3. Migrate locale navigation to framework router APIs for future policy consistency.

## Overall Risk Assessment

| Area | Practical Exploitability | Severity | Notes |
|---|---|---|---|
| Markdown HTML rendering (`dangerouslySetInnerHTML` + raw HTML) | Low (requires trusted content compromise) | Low | Technically risky pattern, not currently attacker-reachable via web input |
| Inline script injection in layout | Very Low | Info | Static script literal, no untrusted interpolation |
| Regex exec in build script | None (runtime) | Info | No ReDoS characteristics, build-time only |
| FS operations in build script | None (runtime) | Info | Hardcoded paths, no tainted path input |
| Locale navigation via `window.location.href` | None | Info | Hardcoded locales; not an open redirect |
| `as any` in i18n | Very Low | Info | Type safety issue, no practical security path currently |
| Dynamic key access for metadata | Very Low | Info | Build-time static locales + fallback |
| Missing CSP/security headers | Medium hardening gap (not direct vuln by itself) | Low | Increases blast radius if upstream compromise occurs |

**Final verdict:** The application is **low risk** in its current static architecture. No high-confidence, remotely exploitable vulnerabilities were identified from the provided code paths under the stated trust model. Priority should be on **defense-in-depth hardening** (especially CSP/security headers and software supply-chain protections) rather than emergency remediation.

## Review & Validation
- This audit was independently reviewed from two perspectives:
  - **Red Team (GPT)**: adversarial validation of exploitability claims and technical precision.
  - **Blue Team (Gemini)**: defensive architecture validation, prioritization, and hardening completeness.
- Corrections from both reviews have been incorporated in this revision, including path accuracy, XSS analysis clarifications, supply-chain install discipline (`npm ci`), clickjacking coverage, CSP nonce/hash implementation detail, and recommendation prioritization.
