# Security Assessment Review (Criteria 2–6)

## Criterion 2: Completeness
- **Severity:** **Major**
- **Line number(s):** 46–63, 81–101, 104–140, 141–165, 166–261
- **Description of finding:**
  - Q1–Q5 are addressed, but not fully complete for deployment reality. The document does not explicitly analyze behavior for redirected traffic (learn-claude-agents.vercel.app -> learn.shareai.run) and whether protections must exist on the **destination** host to be effective.
  - Threat model is narrow: it focuses on anonymous runtime attackers and repository-write compromise, but underweights practical supply-chain/CI compromise paths and trusted-contributor mistakes in markdown that become stored XSS at build time.
  - Combined-risk treatment is incomplete: missing CSP on Vercel + unsanitized HTML rendering are discussed separately, but not evaluated as a compound control failure.
- **Suggested fix text:**
  - “Expand threat model to include (a) compromised maintainer account, (b) compromised CI/build dependency, (c) malicious docs contribution merged by mistake. Add a combined-risk section explicitly evaluating `dangerouslySetInnerHTML` + `allowDangerousHtml` + no `rehype-sanitize` + no CSP on Vercel.”
  - “Add deployment-flow analysis: security headers must be verified on the final content-serving domain, not only the redirecting domain.”

## Criterion 3: Vercel-specific accuracy
- **Severity:** **Minor**
- **Line number(s):** 49–52, 194–241, 266–313
- **Description of finding:**
  - Line 49–52 claim is broadly correct: `vercel.json` `headers` is the right mechanism for static export on Vercel.
  - The proposed JSON is syntactically valid and `headers` can coexist with `redirects`.
  - `source: "/(.*)"` is commonly accepted for all-path matching on Vercel; `/:path*` is usually clearer and less error-prone for maintainers.
  - Missing nuance: requests that hit the first redirect rule return a redirect response; CSP on that redirect response does not protect the destination page. Effective protection must be present on `learn.shareai.run` responses.
- **Suggested fix text:**
  - “Retain `headers` + `redirects`, but add explicit note: security headers must be validated on the final content host (`learn.shareai.run`).”
  - “Optionally change header matcher to `"source": "/:path*"` for readability and consistency with existing redirect style.”

## Criterion 4: Next.js hydration script analysis
- **Severity:** **Informational**
- **Line number(s):** 81–99
- **Description of finding:**
  - Characterization is materially accurate for App Router static exports: Next.js can emit inline hydration/Flight bootstrap scripts (`self.__next_f.push(...)`).
  - These inline payloads can vary between builds (e.g., build IDs/chunk references/serialized data), making strict hash-only CSP operationally heavy without automation.
  - Hash-maintenance burden assessment is realistic.
- **Suggested fix text:**
  - “Add one concrete validation step: after `next build`, scan exported HTML for inline `<script>` blocks and regenerate CSP hashes in CI if strict mode is chosen.”

## Criterion 5: Severity assessment
- **Severity:** **Major**
- **Line number(s):** 153–161
- **Description of finding:**
  - The document’s **Low** rating is likely understated when considering simultaneous conditions:
    1) Vercel currently has no CSP/security headers.
    2) Markdown renderer allows raw HTML and uses `dangerouslySetInnerHTML` without sanitization.
  - CVSS-like scoring assumptions understate impact: if a malicious payload reaches docs content, impact is not “Low” for C/I; script execution in users’ browsers can be significant.
  - More defensible rating is **Medium** (or at least “Low-to-Medium”) due to compound defense gap despite high preconditions.
- **Suggested fix text:**
  - “Revise severity to **Medium** for combined finding, or split into two ratings: (A) missing Vercel CSP = Low/Medium, (B) unsanitized markdown rendering = Medium in absence of CSP.”
  - “State clearly that exploit preconditions are high, but potential browser-side impact is higher than currently scored.”

## Criterion 6: Actionability
- **Severity:** **Minor**
- **Line number(s):** 166–261
- **Description of finding:**
  - Recommendations are mostly practical and near copy-paste ready.
  - Priority order should be adjusted: adding `rehype-sanitize` should be elevated (or run in parallel) because CSP is currently absent on Vercel and rendering is unsanitized.
  - Missing implementation details:
    - verification steps (`curl -I` against final domain and representative paths),
    - rollout guardrails (Report-Only phase where feasible),
    - concrete `rehype-sanitize` schema/baseline and regression tests.
  - `vercel.json` snippet is valid JSON, but not fully “ready” operationally until destination-domain header verification is included.
- **Suggested fix text:**
  - “Updated priority: (1) Add Vercel headers + verify on final domain, (2) add `rehype-sanitize` with explicit allowed tags/attrs, (3) optionally automate strict hash CSP if needed.”
  - “Add validation checklist: deploy preview, run `curl -I` on `/`, `/en`, docs routes, and confirm CSP/XFO/nosniff/referrer/permissions headers on final serving host.”
