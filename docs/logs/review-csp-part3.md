# Review of CSP Security Assessment (Part 3)

**Reviewer:** Application Security Architect
**Date:** 2026-03-19
**Target Document:** `docs/logs/20260319-csp-security-assessment.md`

## Findings

### 1. Technical Accuracy
**Severity:** **Major**
**Lines:** 180-188 (Option B) & 90-93
**Description:**
The document correctly proposes removing the hash for Option B ("Pragmatic"), but fails to explain the critical technical interaction between hashes and `'unsafe-inline'`. Per CSP Level 2 specifications, if a hash or nonce is present in `script-src`, browsers **ignore** `'unsafe-inline'`.
This distinction is vital because a developer might attempt to "merge" Options A and B (keeping the theme script hash while adding `'unsafe-inline'` for hydration) thinking it would allow both. This would result in the browser ignoring `'unsafe-inline'` and breaking the application.

**Suggested Fix:**
Add an explicit warning box:
> **Critical Implementation Note:** You cannot combine strict hashes with `'unsafe-inline'`. If a hash (or nonce) is present in `script-src`, modern browsers will **ignore** `'unsafe-inline'`. You must choose one approach or the other; you cannot mix them to support both hashed scripts and arbitrary inline scripts in the same policy.

### 2. Completeness (Missing HSTS)
**Severity:** **Critical**
**Lines:** 14-21 (Current Posture) & 214-240 (Recommendations)
**Description:**
The document characterizes the self-hosted nginx configuration as "mature" and a "strong... baseline," yet the `nginx.conf` (and the proposed `vercel.json`) completely omits **HTTP Strict Transport Security (HSTS)**. HSTS is a fundamental security control (required for A+ SSL Labs rating) that protects against SSL stripping and man-in-the-middle attacks. Its absence is a significant gap in a "Security Assessment."

**Suggested Fix:**
1. Update existing posture analysis to note HSTS is missing.
2. Add the header to the recommended `vercel.json`:
   ```json
   {
     "key": "Strict-Transport-Security",
     "value": "max-age=63072000; includeSubDomains; preload"
   }
   ```
3. (Optional) Recommend adding it to `nginx.conf`.

### 3. Vercel-specific Accuracy (Route Matching)
**Severity:** **Minor**
**Lines:** 216 (`"source": "/(.*)"`)
**Description:**
While `/(.*)` matches all paths, it is safer and more standard in Vercel configuration to ensure the root path and all subpaths are covered explicitly if there are edge cases, though `/(.*)` is generally accepted. More importantly, verify that these headers apply to **static assets** (images, fonts) in the build output, which Vercel handles correctly, but it's worth noting that aggressive CSP on assets (like images) can sometimes block CDN optimizations if not tested (though `img-src 'self' data:` is usually fine).
No changes required to JSON, but the assumption should be verified.

### 4. Severity Assessment (Sanitization)
**Severity:** **Medium**
**Lines:** 133 ("Low priority")
**Description:**
The assessment rates the lack of `rehype-sanitize` as "Low priority" because the content is "repository-controlled." While the exploitability is currently low, relying solely on the input source being trusted when the sink (`dangerouslySetInnerHTML` with `allowDangerousHtml: true`) is effectively wide open creates significant **Technical Debt**. If the architecture changes (e.g., pulling content from a CMS or external contributor PRs), this becomes a Critical vulnerability immediately.

**Suggested Fix:**
Reclassify as **Medium** priority or "Important Technical Debt." Strongly recommend adding `rehype-sanitize` now to enforce "Secure by Design" principles, rather than leaving a dormant RCE sink in the codebase.

### 5. Missing Topics (Reporting)
**Severity:** **Informational**
**Lines:** Entire Document
**Description:**
The document recommends enforcing CSP immediately without any mention of `Content-Security-Policy-Report-Only` or a `report-uri` / `report-to` endpoint. Deploying CSP (especially strict ones) without visibility into violations makes debugging production issues difficult and hides potential attacks.

**Suggested Fix:**
Add a recommendation to either:
1. Use `Content-Security-Policy-Report-Only` for an initial period.
2. Or add a `report-uri` (or `report-to`) directive to the enforcement policy to monitor for blocked legitimate scripts or XSS attempts.

### 6. CSP Spec Compliance (Directives)
**Severity:** **Informational**
**Lines:** 184 & 220
**Description:**
The proposed policies are syntactically correct. `object-src 'none'` and `base-uri 'self'` are excellent inclusions often missed. The use of `frame-ancestors 'none'` appropriately mitigates Clickjacking.
One observation: `connect-src 'self'` is very restrictive. If the application adds client-side analytics (Google Analytics, Plausible), search (Algolia), or any external API calls later, this will break.

**Suggested Fix:**
Add a note in the "Trade-off" section that `connect-src 'self'` will block third-party analytics and APIs, requiring future policy updates.
