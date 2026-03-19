# CSP Security Assessment Review (Codex)

Reviewed file: `docs/logs/20260319-csp-security-assessment.md` (337 lines)

## 1) Technical Accuracy
**Severity: Major**

### Finding 1.1 — CSP hash behavior and inline-script semantics are underexplained
- **Line(s):** 22-29, 75-80, 90-101, 171-191, 251
- **Description:** The doc correctly records nginx `script-src 'self' 'sha256-...'`, but it does **not** explain a critical CSP L2/L3 behavior: when a nonce/hash appears in `script-src`, `'unsafe-inline'` is ignored by modern browsers for script execution. This matters because the report frames “strict hash-only” vs “unsafe-inline” as a binary operational choice without documenting compatibility semantics.
- **Suggested fix:** Add an explicit note: `script-src 'self' 'unsafe-inline' 'sha256-...'` behaves as strict hash-based in modern browsers (unsafe-inline ignored), but may relax behavior in legacy CSP1 user agents. Clarify recommendation impact.

### Finding 1.2 — Nonce claim is accurate but can be scoped more precisely
- **Line(s):** 67-69
- **Description:** “Nonces cannot work with static export” is directionally correct for pure static hosting (no per-request HTML mutation). Technically, nonces become possible only with dynamic middleware/edge HTML rewriting, which changes the architecture.
- **Suggested fix:** Reword to: “Nonces are not feasible in the current pure static-export deployment model without introducing dynamic response generation/rewriting.”

### Finding 1.3 — Meta CSP limitations are substantially accurate
- **Line(s):** 54-63
- **Description:** Claims on no `frame-ancestors`, no `sandbox`, and no Report-Only in meta policy are correct; “late parsing/pre-meta window” risk is also valid.
- **Suggested fix:** Optional: add one standards citation directly near lines 57-60 to tighten traceability.

### Finding 1.4 — CVSS framing is reasonable but underspecified for alternate attack paths
- **Line(s):** 152-159
- **Description:** The vector assumes supply-chain/write access precondition. Given missing CSP on Vercel, DOM injection opportunities from future code changes, third-party script inclusion, or accidental unsafe HTML may reduce AC/PR in future.
- **Suggested fix:** Add “current-state assumptions” + “re-rate if trust boundary changes (UGC/external embeds).”

---

## 2) Completeness (Q1–Q5)
**Severity: Major**

### Finding 2.1 — Q1–Q5 are answered, but key decision context is missing
- **Line(s):** 46-251
- **Description:** Core questions are covered; however, the document omits explicit treatment of CSP reporting rollout (`Report-Only`, `report-uri`/`report-to`) and phased deployment strategy, despite recommending major CSP changes.
- **Suggested fix:** Add a rollout section: stage policy in Report-Only (header-based), collect violations, then enforce.

### Finding 2.2 — No explicit validation plan / acceptance criteria
- **Line(s):** 168-251
- **Description:** Implementation config is provided, but there is no concrete post-deploy validation checklist (e.g., curl header checks, browser console CSP violations, sampling pages/locales).
- **Suggested fix:** Add “Verification Steps” with exact commands and expected outcomes.

### Finding 2.3 — Missing mention of security-header parity beyond listed five
- **Line(s):** 35-43, 214-238
- **Description:** Parity table omits adjacent headers often co-reviewed for static sites (HSTS, COOP/COEP/CORP, cache directives).
- **Suggested fix:** Add a “not currently implemented / deferred” table with rationale.

---

## 3) Vercel-specific Accuracy
**Severity: Minor**

### Finding 3.1 — Statement that `vercel.json` headers work for static export is correct
- **Line(s):** 48-53
- **Description:** Accurate for Vercel edge/CDN header injection.
- **Suggested fix:** None required.

### Finding 3.2 — Proposed JSON structure is valid, but matching scope could be clarified
- **Line(s):** 214-241, 286-313
- **Description:** `headers` array structure and key/value layout are valid. `source: "/(.*)"` broadly applies. With redirects and localized routes, behavior is usually acceptable but should be explicitly validated for all final responses.
- **Suggested fix:** Add note to verify headers on: `/`, `/en`, deep docs paths, and redirected host path.

---

## 4) Next.js Hydration Script Analysis
**Severity: Minor**

### Finding 4.1 — Practical risk description is mostly accurate
- **Line(s):** 81-87, 178, 187
- **Description:** Build-variant inline hydration scripts can break strict hash-only policies unless hash management is automated.
- **Suggested fix:** None required.

### Finding 4.2 — Overgeneralized recommendation from hydration behavior
- **Line(s):** 90-101, 180-191
- **Description:** The doc jumps from hydration variability to recommending `'unsafe-inline'` baseline, but does not discuss alternatives (e.g., reducing inline script footprint, build-time extraction tooling, selective policy evolution).
- **Suggested fix:** Add decision matrix with 3 paths: pragmatic unsafe-inline, hybrid transition, strict automated hash pipeline.

---

## 5) Severity Assessment
**Severity: Minor**

### Finding 5.1 — “Low” is defensible under stated assumptions
- **Line(s):** 9, 141-165
- **Description:** For static trusted content and no runtime UGC, “Low” can be justified as defense-in-depth gap.
- **Suggested fix:** None required.

### Finding 5.2 — Severity should be explicitly conditional
- **Line(s):** 118-124, 163-165
- **Description:** Current low rating depends on repository trust and no user content. That dependency is not formalized as trigger conditions.
- **Suggested fix:** Add “Reclassification triggers” (UGC introduction, third-party script/widgets, markdown ingestion changes, CMS adoption) and likely severity bump to Medium.

---

## 6) Actionability
**Severity: Major**

### Finding 6.1 — Config snippets are actionable
- **Line(s):** 192-249, 264-314
- **Description:** Concrete copy/paste snippets are useful.
- **Suggested fix:** None required.

### Finding 6.2 — Recommended baseline weakens current nginx script posture on Vercel
- **Line(s):** 180-191, 220, 292
- **Description:** “Option B recommended baseline” (`script-src 'self' 'unsafe-inline'`) is materially weaker than current nginx strict hashed script policy and may allow injected inline scripts if any injection point appears.
- **Suggested fix:** Recommend phased approach: start with nginx-equivalent hash policy in Report-Only on Vercel, observe violations, then decide between strict automation or constrained fallback.

### Finding 6.3 — No operational runbook for hash maintenance
- **Line(s):** 95-99, 178
- **Description:** Strict option mentions automation need but gives no build/runbook details.
- **Suggested fix:** Provide CI step outline: extract inline scripts from exported HTML, compute hashes, compare/update CSP, fail build on mismatch.

---

## 7) CSP Spec Compliance
**Severity: Minor**

### Finding 7.1 — Directive syntax is well-formed
- **Line(s):** 25, 175, 184, 248, 318-330
- **Description:** Policies are syntactically valid and include strong baseline directives (`default-src`, `base-uri`, `form-action`, `frame-ancestors`, `object-src`).
- **Suggested fix:** None required.

### Finding 7.2 — `X-Frame-Options` duplication with `frame-ancestors`
- **Line(s):** 227-229, 323
- **Description:** Not incorrect; redundant modernly, but can be retained for legacy compatibility.
- **Suggested fix:** Optional note: keep both intentionally for backward compatibility.

### Finding 7.3 — Missing optional but useful CSP directives in policy discussion
- **Line(s):** 175, 184, 248
- **Description:** No discussion of `worker-src`, `child-src`, `manifest-src` hardening (even if ultimately defaulted via `default-src`).
- **Suggested fix:** Add explicit directives where applicable, or document why omitted.

---

## 8) Missing Topics Checklist
**Severity: Major**

### Finding 8.1 — Missing explicit `'unsafe-inline'` + hash interaction explanation
- **Line(s):** Entire doc (not present); relevant decision lines 90-101, 171-191
- **Description:** Critical CSP L2/L3 behavior absent from analysis.
- **Suggested fix:** Add dedicated subsection with browser-version caveats and recommendation implications.

### Finding 8.2 — No CSP reporting directives/strategy
- **Line(s):** Entire doc (not present)
- **Description:** No `report-uri`/`report-to` discussion or Report-Only telemetry plan.
- **Suggested fix:** Add reporting endpoint strategy and phased rollout guidance.

### Finding 8.3 — HSTS not covered
- **Line(s):** 16-21, 35-43, 214-238
- **Description:** `Strict-Transport-Security` omitted from parity set.
- **Suggested fix:** Add HSTS recommendation for apex/custom domain paths where HTTPS is guaranteed.

### Finding 8.4 — Cache-Control security posture omitted
- **Line(s):** Entire doc (not present)
- **Description:** No guidance on caching for HTML/security-sensitive responses.
- **Suggested fix:** Add cache policy recommendations (e.g., tighter HTML caching vs immutable static assets).

### Finding 8.5 — COOP/COEP/CORP not assessed
- **Line(s):** Entire doc (not present)
- **Description:** Isolation headers not evaluated.
- **Suggested fix:** Add applicability assessment; if not needed, document explicit deferral rationale.

### Finding 8.6 — `worker-src`, `child-src`, `manifest-src` absent from hardening analysis
- **Line(s):** 318-330
- **Description:** Directive reference table is helpful but incomplete for modern CSP hardening review.
- **Suggested fix:** Extend table with these directives and recommended values or inheritance rationale.

---

## Overall Verdict
The assessment is generally strong and mostly accurate, especially on static-export constraints and trusted-content threat model. Main gaps are **decision-quality gaps** rather than factual collapse: missing CSP L2/L3 hash/unsafe-inline semantics, missing reporting rollout strategy, and recommending a weaker Vercel baseline without an explicit phased validation path.
