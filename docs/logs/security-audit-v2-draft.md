# Security Audit Report — Next.js Static Export Web App

Scope: `web/vercel.json`, `web/package.json`, `web/tsconfig.json`, `web/src/components/docs/doc-renderer.tsx`, `web/src/app/[locale]/layout.tsx`, `requirements.txt`  
Assessment context: `output: "export"` static deployment model, build-time `docs.json` generation from repository markdown.

### Finding 1 — Missing HTTP Security Headers in Vercel Configuration
| Field | Value |
|---|---|
| **File** | `web/vercel.json` |
| **Line(s)** | 1-20 |
| **Severity** | Medium |
| **CVSS v3.1** | 5.3 (AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:L/A:N) |

**Issue**: The deployment config defines redirects but no `headers` block, so browser-side hardening headers are not explicitly enforced. Missing headers include CSP, HSTS, X-Content-Type-Options, Referrer-Policy, Permissions-Policy, and frame-embedding controls.

**Exploit scenario**: If an attacker finds an HTML/script injection path (e.g., malicious markdown introduced into build inputs), the absence of CSP and related controls increases script execution reliability and data exfiltration options.

**Recommendation**: Add a strict `headers` policy in `vercel.json`. Recommended baseline:

```json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "Content-Security-Policy",
          "value": "default-src 'self'; script-src 'self' 'sha256-REPLACE_WITH_THEME_SCRIPT_HASH'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'; upgrade-insecure-requests"
        },
        { "key": "Strict-Transport-Security", "value": "max-age=31536000; includeSubDomains; preload" },
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "Permissions-Policy", "value": "camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()" },
        { "key": "Cross-Origin-Opener-Policy", "value": "same-origin" },
        { "key": "Cross-Origin-Resource-Policy", "value": "same-origin" }
      ]
    }
  ]
}
```

---

### Finding 2 — Redirect Pattern Is Not a Practical Open Redirect
| Field | Value |
|---|---|
| **File** | `web/vercel.json` |
| **Line(s)** | 4-12 |
| **Severity** | Info |
| **CVSS v3.1** | 0.0 (AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:N) |

**Issue**: The wildcard redirect `/:path(.*)` might appear open-redirect prone at first glance, but destination host is hardcoded as `https://learn.shareai.run/:path` with a host match guard.

**Exploit scenario**: Requesting `https://learn-claude-agents.vercel.app//evil.com` redirects to `https://learn.shareai.run//evil.com`, which remains on `learn.shareai.run` (path begins with `//`, but authority is not re-parsed as a new host in an already absolute URL).

**Recommendation**: Keep current host constraint. Optionally normalize duplicate leading slashes in app/router layer for hygiene, but no material open-redirect vulnerability is present from this rule alone.

---

### Finding 3 — `rehypeRaw` + Dangerous HTML Enables XSS If Content Supply Chain Is Compromised
| Field | Value |
|---|---|
| **File** | `web/src/components/docs/doc-renderer.tsx` |
| **Line(s)** | 22-27, 85-88 |
| **Severity** | Low |
| **CVSS v3.1** | 3.8 (AV:N/AC:H/PR:H/UI:R/S:C/C:L/I:L/A:N) |

**Issue**: Markdown is transformed with `allowDangerousHtml: true` and `rehypeRaw`, then rendered via `dangerouslySetInnerHTML`. This is an execution-capable HTML sink.

**Exploit scenario**: Today, `docs.json` is generated only at build time from repository markdown (no user input, no runtime ingestion). Risk activates if attacker gains commit/release pipeline control (malicious PR merge, CI token compromise, dependency compromise in extraction pipeline), injecting `<script>`/event-handler HTML into docs content that ships to all users.

**Recommendation**: Treat markdown source as untrusted at processing time and sanitize before stringify. Example: add `rehype-sanitize` with strict schema and disable dangerous HTML where possible.

---

### Finding 4 — Inline Theme Script Weakens CSP Posture and Becomes a Pivot If Injection Exists
| Field | Value |
|---|---|
| **File** | `web/src/app/[locale]/layout.tsx` |
| **Line(s)** | 41-48 |
| **Severity** | Medium |
| **CVSS v3.1** | 5.4 (AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N) |

**Issue**: Inline script is injected with `dangerouslySetInnerHTML`. Without CSP, any future HTML injection elsewhere can execute script reliably; with CSP, inline code also forces weaker policy unless hashed/nonced.

**Exploit scenario**: If attacker-controlled HTML reaches DOM (e.g., via compromised markdown content path), missing CSP allows arbitrary `<script>` or event-handler execution, enabling token theft from local storage scope, phishing UI injection, or malicious redirects.

**Recommendation**: Move theme logic to a static JS file and enforce CSP without `'unsafe-inline'`, or keep inline script but pin with SHA-256 hash in CSP `script-src` (as shown in Finding 1).

---

### Finding 5 — `skipLibCheck: true` Reduces Type-Integrity Guarantees
| Field | Value |
|---|---|
| **File** | `web/tsconfig.json` |
| **Line(s)** | 6 |
| **Severity** | Low |
| **CVSS v3.1** | 2.7 (AV:L/AC:H/PR:H/UI:N/S:U/C:N/I:L/A:N) |

**Issue**: Declaration files from dependencies are not fully type-checked. Inconsistent or maliciously altered type definitions may evade compile-time detection.

**Exploit scenario**: A compromised dependency publishes misleading `.d.ts` definitions that mask unsafe runtime behavior. Build still passes, reducing reviewer visibility into risky API usage.

**Recommendation**: Set `skipLibCheck: false` in CI security builds (or periodic strict build job) to surface dependency type anomalies; keep local fast builds if needed.

---

### Finding 6 — `allowJs: true` Creates Future Drift Risk if JavaScript Files Are Introduced
| Field | Value |
|---|---|
| **File** | `web/tsconfig.json` |
| **Line(s)** | 5 |
| **Severity** | Info |
| **CVSS v3.1** | 0.0 (AV:L/AC:H/PR:H/UI:N/S:U/C:N/I:N/A:N) |

**Issue**: JavaScript files are permitted by compiler settings. Current state is pure TypeScript in `web/src/`, so immediate exposure is low.

**Exploit scenario**: Future `.js` additions may bypass strict TypeScript safety assumptions and silently introduce unsafe DOM/API usage patterns, especially in fast-moving feature work.

**Recommendation**: If TS-only policy is intended, set `allowJs: false` and enforce via CI. At minimum, document approved JS locations and add lint rules for JS parity.

---

### Finding 7 — `tsx` in Production Dependencies Expands Build/Runtime Attack Surface
| Field | Value |
|---|---|
| **File** | `web/package.json` |
| **Line(s)** | 13-27 (esp. 26) |
| **Severity** | Low |
| **CVSS v3.1** | 3.3 (AV:N/AC:H/PR:N/UI:N/S:U/C:L/I:N/A:N) |

**Issue**: `tsx` (TypeScript execution runtime) is listed under `dependencies` instead of `devDependencies`, increasing production install footprint.

**Exploit scenario**: In environments that install production deps broadly (or if scripts are abused), unnecessary executable tooling raises supply-chain exposure and available gadget surface for post-compromise command execution chains.

**Recommendation**: Move `tsx` to `devDependencies` unless required at runtime in production (not indicated here). Rebuild lockfile after change.

---

### Finding 8 — Next.js Version Is Valid Stable, but Slightly Behind Latest Patch Line
| Field | Value |
|---|---|
| **File** | `web/package.json` |
| **Line(s)** | 17 |
| **Severity** | Low |
| **CVSS v3.1** | 3.1 (AV:N/AC:H/PR:N/UI:N/S:U/C:L/I:N/A:N) |

**Issue**: `next: "16.1.6"` is a legitimate stable release (not canary/non-existent). However, latest stable is `16.2.0`, so this app is behind current patch/minor security and bug fixes.

**Exploit scenario**: If a security fix landed between 16.1.6 and 16.2.0, known exploit techniques may remain applicable until upgraded.

**Recommendation**: Upgrade to latest stable `16.2.x`, run full regression tests, and subscribe to Next.js security advisories for timely patching.

---

### Finding 9 — Python Dependencies Use Open-Ended Lower Bounds (`>=`) Increasing Supply-Chain Volatility
| Field | Value |
|---|---|
| **File** | `requirements.txt` |
| **Line(s)** | 1-2 |
| **Severity** | Medium |
| **CVSS v3.1** | 5.9 (AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:L/A:L) |

**Issue**: `anthropic>=0.25.0` and `python-dotenv>=1.0.0` allow resolver to pull any future major/minor versions, including potentially breaking or compromised releases.

**Exploit scenario**: A future malicious release or dependency confusion incident is automatically accepted during install, leading to code execution in CI/local tooling contexts.

**Recommendation**: Pin exact versions (or narrow compatible ranges), add hash-locked requirements (`pip-compile --generate-hashes`), and enforce reproducible installs in CI.

---

### Finding 10 — `incremental: true` Can Interact with Cached Builds and Hide Type Regressions
| Field | Value |
|---|---|
| **File** | `web/tsconfig.json` |
| **Line(s)** | 15 |
| **Severity** | Low |
| **CVSS v3.1** | 2.6 (AV:L/AC:H/PR:H/UI:N/S:U/C:N/I:L/A:N) |

**Issue**: Incremental TypeScript compilation can reuse stale state in `.tsbuildinfo` under cache-heavy CI workflows, occasionally delaying detection of new type errors.

**Exploit scenario**: A security-relevant type mismatch in validation/sanitization code is missed in one pipeline run due to stale incremental cache, allowing vulnerable code to merge.

**Recommendation**: Keep `incremental: true` for developer speed, but run CI security/type gate with clean cache (`tsc --noEmit --incremental false` or delete build info before check).

---

## Risk Matrix

| Severity | Findings |
|---|---|
| Critical | None |
| High | None |
| Medium | 1, 4, 9 |
| Low | 3, 5, 7, 8, 10 |
| Info | 2, 6 |

| Finding | Title | Severity | CVSS |
|---|---|---|---|
| 1 | Missing HTTP Security Headers in Vercel Configuration | Medium | 5.3 |
| 2 | Redirect Pattern Is Not a Practical Open Redirect | Info | 0.0 |
| 3 | `rehypeRaw` + Dangerous HTML Enables XSS If Content Supply Chain Is Compromised | Low | 3.8 |
| 4 | Inline Theme Script Weakens CSP Posture and Becomes a Pivot If Injection Exists | Medium | 5.4 |
| 5 | `skipLibCheck: true` Reduces Type-Integrity Guarantees | Low | 2.7 |
| 6 | `allowJs: true` Creates Future Drift Risk if JavaScript Files Are Introduced | Info | 0.0 |
| 7 | `tsx` in Production Dependencies Expands Build/Runtime Attack Surface | Low | 3.3 |
| 8 | Next.js Version Is Valid Stable, but Slightly Behind Latest Patch Line | Low | 3.1 |
| 9 | Python Dependencies Use Open-Ended Lower Bounds (`>=`) Increasing Supply-Chain Volatility | Medium | 5.9 |
| 10 | `incremental: true` Can Interact with Cached Builds and Hide Type Regressions | Low | 2.6 |
