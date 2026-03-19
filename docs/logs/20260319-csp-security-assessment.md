# Content Security Policy (CSP) Security Assessment
## learn-claude-code Web Application

- **Date:** 2026-03-19
- **Author:** Web Security Architecture Team
- **Classification:** Internal - Security Assessment

## Executive Summary
The self-hosted nginx deployment already implements a strong, comprehensive Content Security Policy (CSP) and supporting security headers. The primary security gap is deployment-specific: the Vercel-hosted static export currently does not return equivalent HTTP security headers, including CSP. Given the application’s architecture (fully static export, no SSR), trusted build-time content model, and absence of user-submitted markdown, this is assessed as a **Low severity** defense-in-depth gap rather than an immediately exploitable vulnerability. The main practical challenge is Next.js static-export hydration behavior, which produces build-variable inline scripts that make strict hash-only CSP maintenance operationally expensive.

## 1. Current Security Posture

### 1.1 Existing Controls (Already Implemented)
The self-hosted path (`deploy/nginx.conf`) includes a mature, explicit header baseline:

- `Content-Security-Policy` with restrictive defaults and explicit allowlists
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy: interest-cohort=()`

Current nginx CSP:

```http
default-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; object-src 'none'; script-src 'self' 'sha256-jNBf7AQyUoNbCZtcD2O/B0G5cA+LTkk2IyykV+9S0e8='; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; upgrade-insecure-requests
```

This policy is materially strong for a static documentation-style application and already includes the correct SHA-256 for the inline theme bootstrap script in `layout.tsx`.

### 1.2 Identified Gap
The Vercel deployment (`web/vercel.json`) currently defines redirects only and does **not** define security headers. As a result, equivalent CSP and companion headers are not guaranteed on that hosting path.

### 1.3 Header Coverage Comparison

| Control | Self-hosted (nginx) | Vercel (current) | Gap |
|---|---|---|---|
| Content-Security-Policy | ✅ Implemented | ❌ Missing | Yes |
| X-Content-Type-Options | ✅ Implemented | ❌ Missing | Yes |
| X-Frame-Options | ✅ Implemented | ❌ Missing | Yes |
| Referrer-Policy | ✅ Implemented | ❌ Missing | Yes |
| Permissions-Policy | ✅ Implemented | ❌ Missing | Yes |
| Redirects | ✅ N/A (handled separately) | ✅ Implemented | No |

**Conclusion:** Security posture is strong for self-hosted nginx; Vercel is the only materially uncovered deployment path.

## Q1: vercel.json Headers vs Meta Tags for CSP

### Recommendation for `output: "export"` on Vercel
For a Next.js static export (`output: "export"`), **`vercel.json` headers are the recommended and correct mechanism** for CSP and other HTTP security headers.

### Can Vercel serve custom headers for static exports?
Yes. Vercel applies `vercel.json` `headers` rules at its CDN/Edge layer for static assets and routes. This works for static export deployments where `next.config.ts` runtime header APIs are unavailable.

### Why not rely on `<meta http-equiv="Content-Security-Policy">`?
Meta-tag CSP has critical limitations and should not be the primary control:

1. **No support for `frame-ancestors`** via meta CSP.
2. **No support for `sandbox`** via meta CSP.
3. **No support for Report-Only mode** (`Content-Security-Policy-Report-Only`).
4. **Late parsing risk:** browser may parse/execute early content before encountering the meta tag.
5. **Pre-meta injection window:** if malicious injection occurs before the meta tag, policy may be bypassed for that content.

Therefore, HTTP response headers (via `vercel.json`) are the correct implementation path.

## Q2: CSP Directives for the Inline Theme Script

### Can nonces work with static export?
No. CSP nonces require a per-request, unpredictable server-generated value added to both header and script tag. Static-exported HTML serves fixed artifacts and cannot generate per-request nonces without introducing dynamic server logic.

### Is hash-based CSP the right approach?
Yes, for deterministic inline scripts such as the hardcoded theme initializer in `layout.tsx`. The existing hash is correct:

- `sha256-jNBf7AQyUoNbCZtcD2O/B0G5cA+LTkk2IyykV+9S0e8=`

### Exact `script-src` for current theme script

```http
script-src 'self' 'sha256-jNBf7AQyUoNbCZtcD2O/B0G5cA+LTkk2IyykV+9S0e8='
```

### Next.js Hydration Complication (Key Practical Constraint)
With Next.js static export, hydration/bootstrap can emit inline scripts (e.g., `self.__next_f.push(...)`) that vary across builds. In a strict hash-only model:

- Every new build may alter inline script bytes.
- CSP hashes may need recalculation per build artifact set.
- Deployment reliability can degrade unless hash generation/validation is fully automated.

Two practical implementation options:

1. **Add `'unsafe-inline'` to `script-src` (Pragmatic):**
   - Significantly simpler operations.
   - Avoids breakage from build-to-build inline script changes.
   - Weaker script execution protection than strict hash-only CSP.

2. **Maintain build-time hash extraction (Strict):**
   - Stronger policy integrity.
   - Higher maintenance overhead and CI/CD complexity.
   - Requires robust automation and failure handling for new hashes.

For most static sites with trusted, repository-controlled content, **Option 1 is operationally acceptable** when balanced against delivery stability and maintenance burden.

## Q3: CSP vs `dangerouslySetInnerHTML` + No `rehype-sanitize`

### Context and Threat Model
`doc-renderer.tsx` pipeline currently uses:

- `remarkParse`
- `remarkGfm`
- `remarkRehype({ allowDangerousHtml: true })`
- `rehypeRaw`
- `rehypeHighlight`
- `rehypeStringify`

and renders output through `dangerouslySetInnerHTML`.

No `rehype-sanitize` is present.

### Does build-time trusted source materially change risk?
Yes—dramatically. Markdown is sourced from repository-controlled files (`docs/{en,zh,ja}/*.md`) and compiled at build time into generated data. It is not user-submitted at runtime.

### Actual XSS attack surface
The realistic path to malicious script injection through markdown requires a supply-chain style event (e.g., malicious repository write/commit to docs content). That attacker capability already implies substantial project compromise and broader attack opportunities beyond markdown rendering.

Therefore, runtime exploitable XSS exposure from anonymous users is minimal in the current architecture.

### `rehype-sanitize` vs CSP: complementary controls
- **CSP** limits script execution and resource loading at browser enforcement level.
- **`rehype-sanitize`** constrains what HTML may be produced from markdown content.

They address different points in the attack chain and should be viewed as defense-in-depth, not substitutes.

### Should `rehype-sanitize` still be added?
Recommended, but **Low priority** in this specific threat model. Benefits include:

- Protection against accidental unsafe HTML in docs contributions.
- Reduced blast radius for future trust-boundary changes.
- Improved long-term maintainability and secure defaults.

Key insight: `allowDangerousHtml: true` + `rehypeRaw` + no sanitization is architecturally risky in general systems, but current risk is mitigated by trusted build-time sourcing.

## Q4: Severity Rating

### OWASP/CVSS-Oriented Analysis
Scope of finding: Missing CSP/security headers on **Vercel deployment only**.

Environmental factors:
- Static export architecture; no SSR.
- No user-generated markdown/input in rendering pipeline.
- Trusted repository-sourced docs content.
- Self-hosted nginx path already enforces robust CSP and related headers.

CVSS-like qualitative vector:
- **Attack Vector (AV):** Network
- **Attack Complexity (AC):** High (requires content supply-chain compromise)
- **Privileges Required (PR):** High (repository write/merge capability)
- **User Interaction (UI):** Required (victim must load affected page)
- **Scope (S):** Unchanged
- **Impact (C/I/A):** Low

### Final Rating
**Low Severity**

### Justification
This is a meaningful defense-in-depth gap, not an imminently exploitable vulnerability under the current architecture and trust assumptions. The absence of CSP on Vercel should be corrected to align deployment parity and reduce future risk, but present exploitability is constrained by static content generation and trusted source control.

## Q5: Recommended Implementation

### 5.1 Security Header Parity for Vercel
Implement headers in `web/vercel.json` while preserving existing redirects.

### 5.2 CSP Option A — Strict (Hash-based)
Use nginx-equivalent CSP (existing hash already correct for theme script):

```http
default-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; object-src 'none'; script-src 'self' 'sha256-jNBf7AQyUoNbCZtcD2O/B0G5cA+LTkk2IyykV+9S0e8='; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; upgrade-insecure-requests
```

**Trade-off:** strong but may require per-build hash automation for additional Next.js inline hydration scripts.

### 5.3 CSP Option B — Pragmatic (with `unsafe-inline` in script-src)
Recommended operational baseline for Vercel static export:

```http
default-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; object-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; upgrade-insecure-requests
```

**Trade-off:** weaker script execution hardening than strict hashes, but avoids deployment fragility from build-variant Next.js inline hydration payloads.

### 5.4 Recommended Decision
Adopt **Option 2 (Pragmatic)** for Vercel immediately to close header gap with low operational risk. Revisit Option 1 when/if CI/CD hash extraction and verification automation is added.

### 5.5 Exact `vercel.json` Configuration (Recommended Pragmatic)

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
          "value": "default-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; object-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; upgrade-insecure-requests"
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
          "value": "interest-cohort=()"
        }
      ]
    }
  ]
}
```

### 5.6 Strict Alternative Header Value (Drop-in)
If strict mode is later automated, replace only the `Content-Security-Policy` value with:

```text
default-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; object-src 'none'; script-src 'self' 'sha256-jNBf7AQyUoNbCZtcD2O/B0G5cA+LTkk2IyykV+9S0e8='; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; upgrade-insecure-requests
```

**Important:** Existing nginx CSP and hash are already correct and do not require changes.

## Recommendations Summary

| Priority | Recommendation | Effort | Security Value | Rationale |
|---|---|---:|---:|---|
| 1 | Add CSP + security headers in `vercel.json` (pragmatic CSP) | Low | Medium | Closes deployment parity gap on Vercel with minimal operational burden |
| 2 | Add `rehype-sanitize` to markdown pipeline | Low | Low | Defense-in-depth against accidental unsafe HTML in docs |
| 3 | Automate hash extraction/validation for strict CSP in CI/CD | Medium | Low | Improves CSP strictness if operationally justified |
| 4 | Keep nginx CSP as-is | None | Already High | Current self-hosted policy is well-configured and includes correct theme script hash |

## Appendix

### A. Full `vercel.json` (Recommended Pragmatic Configuration)

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
          "value": "default-src 'self'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'; object-src 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; upgrade-insecure-requests"
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
          "value": "interest-cohort=()"
        }
      ]
    }
  ]
}
```

### B. CSP Directive Reference

| Directive | Purpose | Current/Recommended Use |
|---|---|---|
| `default-src 'self'` | Baseline source restriction for unspecified fetch types | Restricts to same-origin by default |
| `base-uri 'self'` | Restricts allowed `<base>` URL origins | Prevents base tag origin manipulation |
| `form-action 'self'` | Restricts form submission targets | Prevents data exfiltration via rogue form endpoints |
| `frame-ancestors 'none'` | Controls who can frame the site | Clickjacking defense |
| `object-src 'none'` | Disables plugin content (`<object>`, `<embed>`, `<applet>`) | Removes legacy plugin attack surface |
| `script-src ...` | Controls JavaScript execution sources | Key directive for XSS risk reduction |
| `style-src 'self' 'unsafe-inline'` | Controls stylesheet sources | Allows inline styles required by app rendering behavior |
| `img-src 'self' data:` | Limits image sources | Allows local and data URI images |
| `font-src 'self' data:` | Limits font sources | Allows local and inlined font assets |
| `connect-src 'self'` | Limits XHR/fetch/WebSocket targets | Prevents arbitrary outbound data channels |
| `upgrade-insecure-requests` | Upgrades `http://` subrequests to HTTPS | Reduces mixed-content transport risk |

### C. Standards and References

- W3C Content Security Policy Level 3: https://www.w3.org/TR/CSP3/
- OWASP Content Security Policy Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html

