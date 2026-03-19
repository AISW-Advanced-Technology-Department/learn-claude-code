# Next.js 16.1.6 Static Export Security Audit (Vercel)

### Finding 1 — Missing security headers in Vercel configuration
| Field | Value |
|---|---|
| **File** | `web/vercel.json` |
| **Line(s)** | 1-20 |
| **Severity** | High |
| **CVSS v3.1** | 7.4 (AV:N/AC:L/PR:N/UI:R/S:U/C:H/I:L/A:N) |

**Issue**: `vercel.json` defines redirects only and has no `headers` block. For static exports on Vercel, response headers must be set in `vercel.json`. Missing headers reduce browser-enforced protections (XSS impact reduction, framing defense, MIME sniffing prevention, origin isolation, and HTTPS hardening).

**Exploit scenario**: An attacker leveraging any client-side injection bug (now or future) gets broader impact because no CSP exists; clickjacking is possible without `X-Frame-Options`/`frame-ancestors`; insecure embedding/origin interaction risks remain without COOP/COEP/CORP.

**Recommendation**: Add a global `headers` block. Example:

```json
{
  "redirects": [
    {
      "source": "/:path(.*)",
      "has": [{ "type": "host", "value": "learn-claude-agents.vercel.app" }],
      "destination": "https://learn.shareai.run/:path",
      "permanent": true
    },
    { "source": "/", "destination": "/en", "permanent": false }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "Content-Security-Policy",
          "value": "default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'none'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'; form-action 'self'; upgrade-insecure-requests"
        },
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
        { "key": "Permissions-Policy", "value": "camera=(), microphone=(), geolocation=(), interest-cohort=()" },
        { "key": "Strict-Transport-Security", "value": "max-age=31536000; includeSubDomains" },
        { "key": "Cross-Origin-Opener-Policy", "value": "same-origin" },
        { "key": "Cross-Origin-Embedder-Policy", "value": "require-corp" },
        { "key": "Cross-Origin-Resource-Policy", "value": "same-origin" }
      ]
    }
  ]
}
```

---

### Finding 2 — Wildcard redirect is not an open redirect
| Field | Value |
|---|---|
| **File** | `web/vercel.json` |
| **Line(s)** | 3-13 |
| **Severity** | Info |
| **CVSS v3.1** | 0.0 (AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:N) |

**Issue**: Redirect rule uses `/:path(.*)` and forwards to `https://learn.shareai.run/:path` only when host is `learn-claude-agents.vercel.app`.

**Exploit scenario**: Attempts such as `//evil.com` or encoded path tricks remain on the hardcoded destination domain (`learn.shareai.run`). Because destination origin is fixed and not user-controlled, this is not an open redirect.

**Recommendation**: No security fix required. Keep destination host hardcoded and host condition strict as implemented.

---

### Finding 3 — Raw HTML markdown pipeline enables trusted-content XSS path
| Field | Value |
|---|---|
| **File** | `web/src/components/docs/doc-renderer.tsx` |
| **Line(s)** | 22-23, 87 |
| **Severity** | Low |
| **CVSS v3.1** | 3.8 (AV:N/AC:H/PR:L/UI:R/S:C/C:L/I:L/A:N) |

**Issue**: Markdown rendering explicitly allows and parses raw HTML (`allowDangerousHtml: true` + `rehypeRaw`) and injects the result via `dangerouslySetInnerHTML`.

**Exploit scenario**: In this architecture, content originates from build-time, repo-controlled markdown (`docs/` -> generated `docs.json`), not runtime user input. Direct external XSS is therefore unlikely. However, a malicious/compromised contributor or supply-chain tampering in content generation could inject active HTML/JS payloads that ship to production.

**Recommendation**: Defense-in-depth options:
- Prefer disallowing raw HTML (`allowDangerousHtml: false`, remove `rehypeRaw`) if not required.
- If raw HTML must stay, sanitize output with `rehype-sanitize` and a strict schema.
- Protect content integrity with branch protection, CODEOWNERS, and CI checks on markdown diffs.

---

### Finding 4 — Inline theme script blocks strict CSP adoption
| Field | Value |
|---|---|
| **File** | `web/src/app/[locale]/layout.tsx` |
| **Line(s)** | 41-48 |
| **Severity** | Medium |
| **CVSS v3.1** | 5.3 (AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:L/A:N) |

**Issue**: Theme bootstrap JS is injected inline using `dangerouslySetInnerHTML`. This is a common anti-FOUC pattern, but incompatible with strict CSP (`script-src 'self'`) unless using a nonce/hash.

**Exploit scenario**: In static export mode, per-request nonces are impractical. Teams often weaken CSP with `'unsafe-inline'`, reducing XSS mitigation strength globally.

**Recommendation**:
- Preferred: move script to external static file and load with `script-src 'self'`.
- If inline must remain, use a CSP hash (`'sha256-...'`) for this exact script body and avoid broad `'unsafe-inline'` where feasible.

---

### Finding 5 — Dependency pinning strategy has Python supply-chain risk
| Field | Value |
|---|---|
| **File** | `requirements.txt`, `web/package.json` |
| **Line(s)** | `requirements.txt` 1-2; `package.json` 14-37 |
| **Severity** | Medium |
| **CVSS v3.1** | 5.9 (AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:L/A:L) |

**Issue**: Python dependencies use unbounded lower-only specifiers (`anthropic>=0.25.0`, `python-dotenv>=1.0.0`), allowing uncontrolled major upgrades over time. JS dependencies mostly use caret ranges (`^`), which is standard when lockfiles are enforced, and core runtime deps (`next`, `react`, `react-dom`) are exactly pinned.

**Exploit scenario**: A future malicious or breaking upstream Python release can be pulled during installs, causing compromise or instability without code changes in this repo.

**Recommendation**:
- Pin Python dependencies to exact versions (or bounded ranges) and maintain a lock workflow.
- Keep JS lockfile committed and CI-enforced (`npm ci`) to preserve reproducibility.

---

### Finding 6 — `skipLibCheck` disables dependency declaration type validation
| Field | Value |
|---|---|
| **File** | `web/tsconfig.json` |
| **Line(s)** | 6 |
| **Severity** | Info |
| **CVSS v3.1** | 0.0 (AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:N) |

**Issue**: `skipLibCheck: true` skips type-checking of `.d.ts` files in dependencies.

**Exploit scenario**: Not directly exploitable as a runtime vulnerability; it may hide typing defects or risky declarations during development.

**Recommendation**: Acceptable as a performance tradeoff (common Next.js default). For stricter assurance, consider periodic CI jobs with `skipLibCheck: false`.

---

### Finding 7 — `allowJs` permits less-checked JavaScript files in TS project
| Field | Value |
|---|---|
| **File** | `web/tsconfig.json` |
| **Line(s)** | 5 |
| **Severity** | Info |
| **CVSS v3.1** | 0.0 (AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:N) |

**Issue**: `allowJs: true` includes `.js` files in the TS project; without `checkJs`, these files do not receive full type checking.

**Exploit scenario**: Primarily a code-quality and assurance gap, not a direct security vulnerability.

**Recommendation**: If JS files are present in sensitive paths, enable `checkJs` or migrate them to TypeScript.

---

### Finding 8 — Build-time tool `tsx` is in production dependencies
| Field | Value |
|---|---|
| **File** | `web/package.json` |
| **Line(s)** | 6, 9, 26, 29-37 |
| **Severity** | Low |
| **CVSS v3.1** | 2.7 (AV:L/AC:L/PR:L/UI:N/S:U/C:L/I:L/A:N) |

**Issue**: `tsx` is used for content extraction during predev/prebuild, but is listed in `dependencies` rather than `devDependencies`, increasing production install surface unnecessarily. Also, some libraries use broad ranges (`^`), and `lucide-react` is a `0.x` package where compatibility guarantees are weaker.

**Exploit scenario**: Larger production dependency graph increases supply-chain exposure if installation happens in runtime environments.

**Recommendation**:
- Move `tsx` to `devDependencies`.
- Keep lockfile strict and review updates for `0.x` packages carefully.

---

### Finding 9 — Missing explicit HSTS and cross-origin isolation headers
| Field | Value |
|---|---|
| **File** | `web/vercel.json` |
| **Line(s)** | 1-20 |
| **Severity** | Medium |
| **CVSS v3.1** | 5.3 (AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:L/A:N) |

**Issue**: No explicit `Strict-Transport-Security`, `COOP`, `COEP`, or `CORP` headers are configured.

**Exploit scenario**: On custom domains, relying on platform defaults may leave transport/security policy weaker than intended. Lack of origin-isolation headers can increase risk around cross-origin interactions and future browser-side feature hardening.

**Recommendation**: Set these headers explicitly in `vercel.json` (see Finding 1 recommended block). Validate compatibility before enforcing `COEP: require-corp` if third-party assets are embedded.

---

### Finding 10 — `next@16.1.6` advisories are not exploitable in this deployment model
| Field | Value |
|---|---|
| **File** | `web/package.json`, `web/next.config.ts` |
| **Line(s)** | `package.json` 17; `next.config.ts` 4-6 |
| **Severity** | Info |
| **CVSS v3.1** | 0.0 (AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:N) |

**Issue**: `npm audit` reports moderate advisories for Next.js versions up to `16.1.6`.

**Exploit scenario**: The cited issues are server-side in nature (Server Actions CSRF, image optimizer cache growth, rewrite/request-smuggling paths). This app is static export (`output: "export"`), has no API routes/Server Actions runtime, and uses `images.unoptimized: true`; therefore these vectors are not reachable in deployed static hosting.

**Recommendation**: Mark as currently not exploitable in this architecture, but still plan framework updates for defense-in-depth and future architecture changes.

---

## Executive Summary

### Risk Matrix
| # | Finding | Severity | CVSS | Exploitable? |
|---|---------|----------|------|--------------|
| 1 | Missing security headers in Vercel config | High | 7.4 | Yes |
| 2 | Wildcard redirect open-redirect analysis | Info | 0.0 | No |
| 3 | Raw HTML markdown pipeline + innerHTML | Low | 3.8 | Limited (trusted-content path) |
| 4 | Inline script vs strict CSP | Medium | 5.3 | Indirectly (weakens CSP posture) |
| 5 | Dependency pinning strategy (Python/JS) | Medium | 5.9 | Yes (supply-chain/reproducibility) |
| 6 | skipLibCheck enabled | Info | 0.0 | No direct runtime exploit |
| 7 | allowJs without checkJs | Info | 0.0 | No direct runtime exploit |
| 8 | `tsx` in production dependencies | Low | 2.7 | Low likelihood |
| 9 | No explicit HSTS/COOP/COEP/CORP | Medium | 5.3 | Potentially |
| 10 | Next.js 16.1.6 advisories in static export | Info | 0.0 | No (for current model) |

Primary risk is **security header absence** in `vercel.json` (especially CSP, HSTS, framing/MIME protections). The app’s static-export architecture substantially reduces server-side exploitability and invalidates several `npm audit` Next.js findings for current deployment. Secondary concerns are **policy hardening debt** (inline script vs strict CSP) and **supply-chain hygiene** (Python `>=` pinning and build tooling placement). Prioritize implementing the headers block and tightening dependency governance.
