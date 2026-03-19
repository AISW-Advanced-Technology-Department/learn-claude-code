# Security Audit — Learn Claude Code (Next.js Static Export)

## Scope & Threat Model
- Deployment model: `output: "export"` static site on Vercel (no server runtime, no API routes).
- Data flow: markdown/docs content is ingested at build time and shipped as static JSON/HTML.
- No direct end-user input surfaces (forms/API) in production runtime.
- Therefore, **realistic attacker paths are mostly supply-chain/content-author compromise**, not anonymous remote input.

---

## Evaluation of the 7 Findings

| # | Finding | Exploitable in Production? | Severity |
|---|---|---|---|
| 1 | `dangerouslySetInnerHTML` in `doc-renderer.tsx` with `rehypeRaw` and no sanitize | **YES (conditional)** | **Medium** |
| 2 | `dangerouslySetInnerHTML` for hardcoded theme script in `layout.tsx` | **NO (as implemented)** | **Low / Info** |
| 3 | Regex (`RegExp.exec`) in `extract-content.ts` | **NO** | **Info** |
| 4 | `fs` file I/O in `extract-content.ts` | **NO (runtime); conditional build risk** | **Low** |
| 5 | `window.location.href` locale switch in `header.tsx` | **NO** | **Info** |
| 6 | `as any` coercion in `i18n.tsx` | **NO direct exploit** | **Info** |
| 7 | Dynamic property access `metaMessages[locale]` in `layout.tsx` | **NO direct exploit** | **Info** |

---

### 1) `dangerouslySetInnerHTML` + Markdown rendering without sanitize
**Exploitable:** **YES (conditional on content compromise)**  
**Attack scenario:**
- Pipeline permits raw HTML (`allowDangerousHtml: true` + `rehypeRaw`) and renders via `dangerouslySetInnerHTML`.
- If an attacker can modify markdown/docs (compromised maintainer account, malicious PR merged, compromised CI artifact), they can inject HTML with event handlers, e.g. `<img src=x onerror=...>`.
- This becomes **stored XSS in static content** viewed by all visitors.
- Anonymous internet users cannot inject content directly via app UI (no forms/API), so exploitability is **not public-input based**, but still real under supply-chain/content compromise.

**Severity:** **Medium** (could become High if docs are externally sourced/untrusted).  
**Recommendation:**
- Add `rehype-sanitize` with strict schema (allow only required tags/attrs/protocols).
- Consider disabling raw HTML entirely if not required.
- Add CSP in deployment (see missed vulnerabilities section) to reduce blast radius.
- Add CI checks/linting for dangerous HTML patterns in docs.

---

### 2) `dangerouslySetInnerHTML` for hardcoded dark-mode script
**Exploitable:** **NO**  
**Attack scenario / why safe:**
- Script content is static, no interpolation of attacker-controlled data.
- This is not a sink fed by request params/query/user content.
- Main risk is policy hardening (requires CSP exception for inline scripts), not direct injection.

**Severity:** **Low / Info**  
**Recommendation:**
- Prefer `next/script` with nonce/hash-compatible CSP strategy, or hash this exact inline script in CSP.
- Keep script immutable (no dynamic concatenation with user-controlled values).

---

### 3) Regex in build script (`extract-content.ts`)
**Exploitable:** **NO**  
**Attack scenario / why safe:**
- Regex is simple (`/"name"\s*:\s*"(\w+)"/g`) and linear; no catastrophic backtracking pattern.
- Input source is repository files at build time, not untrusted runtime network input.

**Severity:** **Info**  
**Recommendation:**
- No urgent security fix required.
- Optional robustness improvement: parse AST/JSON-like structures instead of regex for correctness.

---

### 4) `fs` operations in build script
**Exploitable:** **NO (production runtime), conditional in compromised build/content workflow**  
**Attack scenario / why mostly safe:**
- File paths are derived from fixed directories relative to script location, not user input.
- No runtime file access in browser.
- Build-time risk exists if a malicious contributor introduces crafted symlinks/content that causes sensitive local files to be ingested into generated JSON during CI/build.

**Severity:** **Low**  
**Recommendation:**
- Optionally reject symlinks and enforce `realpath` under allowed roots.
- Keep CI isolated and minimize sensitive files present in build workspace.

---

### 5) `window.location.href` for locale switching
**Exploitable:** **NO**  
**Attack scenario / why safe:**
- Destination path is derived from `usePathname()` (same-origin path) and locale from hardcoded allowlist buttons.
- No attacker-controlled external URL; no open redirect to arbitrary domain.

**Severity:** **Info**  
**Recommendation:**
- Optional hardening: validate `newLocale` against allowlist in function body.
- Use router navigation API for UX consistency (`router.push`) if desired.

---

### 6) `as any` in i18n
**Exploitable:** **NO direct exploit**  
**Attack scenario / why safe:**
- This is type-safety erosion, not a security sink by itself.
- `namespace` usage appears internal/hardcoded by components; not user-controlled request data.

**Severity:** **Info**  
**Recommendation:**
- Replace `any` with typed key unions for namespaces/keys.
- Improves correctness and reduces accidental unsafe future usage.

---

### 7) Dynamic property access `metaMessages[locale]`
**Exploitable:** **NO direct exploit**  
**Attack scenario / why safe:**
- Could theoretically read inherited keys like `__proto__`, but this does not currently yield code execution.
- Fallback logic (`|| metaMessages.en`) and optional chaining make this mostly benign.
- No attacker-controlled mutation of `metaMessages` object in current model.

**Severity:** **Info**  
**Recommendation:**
- Harden by validating locale against explicit allowlist before lookup.
- Alternatively use `Map` or object created with null prototype for defensive coding.

---

## Missed Vulnerabilities / Additional Risks

### A) Stored XSS via markdown HTML/event attributes (primary real risk)
**Status:** **Realistic under content/pipeline compromise**  
**Severity:** **Medium** (potentially High depending on trust boundary of docs authorship).  
**Details:**
- Combination of `remarkRehype({ allowDangerousHtml: true })`, `rehypeRaw`, and `dangerouslySetInnerHTML` is an XSS-capable pattern.
- Even if `<script>` inserted via innerHTML may not execute, handler-based payloads (`onerror`, etc.) and dangerous URLs can still execute or be abused.

**Fix:** enforce sanitization (`rehype-sanitize`) + CSP.

---

### B) CSP/security headers are missing or not enforced in static export path
**Status:** **Hardening gap**  
**Severity:** **Medium**  
**Details:**
- `next.config.ts` does not define headers, and for static export, header strategy must be handled via Vercel config/dashboard.
- Without strict CSP, any future XSS regression is easier to exploit.

**Fix:** define headers at hosting layer (Vercel):
- `Content-Security-Policy` (nonce/hash strategy; limit script sources)
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `X-Frame-Options: DENY` or CSP `frame-ancestors 'none'`

---

### C) Prototype pollution concerns (`metaMessages[locale]`, `(messages as any)[namespace]`)
**Status:** **Not practically exploitable in current architecture**  
**Severity:** **Info**  
**Details:**
- Accessing dynamic keys on normal objects can be risky if attacker controls keys and pollution primitives exist.
- Here, no clear path for attacker to inject/merge objects or control these keys from runtime user input.

**Fix:** locale/namespace allowlists and null-prototype maps as preventive hardening.

---

### D) Open redirect
**Status:** **Not found (practical exploit absent)**  
**Severity:** **Info**  
**Details:**
- `window.location.href` locale switching is same-origin path transformation.
- `vercel.json` redirect destination is fixed domain; path passthrough does not create arbitrary external redirect.

**Fix:** none required beyond optional validation.

---

### E) Path traversal
**Status:** **Not found in runtime; low build-time concern only**  
**Severity:** **Info/Low**  
**Details:**
- No user-controlled path joins in app runtime.
- Build script uses fixed directories; traversal not exposed to internet users.

**Fix:** optional symlink/root-boundary checks in extractor.

---

### F) ReDoS
**Status:** **Not found**  
**Severity:** **Info**  
**Details:**
- Reviewed regexes are simple and not vulnerable to catastrophic backtracking under normal assumptions.

---

### G) Supply-chain risk
**Status:** **Present (ecosystem-level)**  
**Severity:** **Medium**  
**Details:**
- App depends on markdown/HTML processing chain (`unified`, `remark-*`, `rehype-*`), where dependency compromise can impact output safety.
- Since XSS boundary depends on sanitizer choices, package integrity and version governance matter.

**Fix:**
- Pin and review dependencies, enable Dependabot/SCA, verify lockfile integrity.
- Prefer minimal plugin set and periodic security review of parser/render pipeline.

---

## Final Verdict
- Most flagged items are **not directly exploitable** in this static, no-user-input architecture.
- The **key real security issue** is the markdown-to-HTML pipeline allowing raw HTML rendered via `dangerouslySetInnerHTML` **without sanitization**.
- Practical attack requires **content/build supply-chain compromise**, but impact to visitors is real once compromised content ships.

## Priority Remediation
1. Add `rehype-sanitize` (or disable raw HTML) in `doc-renderer.tsx` pipeline.
2. Enforce CSP/security headers at Vercel layer (static hosting compatible).
3. Add defensive allowlists for locale/namespace dynamic lookups.
4. Add CI guardrails for docs content and dependency security.
