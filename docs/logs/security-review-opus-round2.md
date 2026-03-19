# Security Audit Report — Peer Review (Round 2)

**Report Under Review**: `docs/logs/security-audit-report.md`  
**Reviewer Role**: Principal Security Architect  
**Review Date**: 2026-03-19  
**Review Scope**: Technical accuracy, CVSS v3.1 correctness, completeness, quality  

---

## Verdict: NEEDS REVISION

The report demonstrates strong qualitative security analysis — threat modeling, data-flow reasoning, and classification logic are largely sound. However, **every non-zero CVSS v3.1 score is mathematically incorrect**, with errors ranging from +0.6 to +1.7 points. Additionally, three findings share identical CVSS vectors yet claim different scores, which is a computational impossibility. These errors undermine the report's quantitative credibility and must be corrected before publication.

---

## Issues Found

### Issue 1 — CRITICAL: All CVSS v3.1 Scores Are Mathematically Wrong

Every non-zero CVSS score in the report fails mathematical verification against the CVSS v3.1 Base Score formula. The vectors and claimed scores were independently computed using the standard formula:

| Finding | Claimed Score | Correct Score | Delta | Vector |
|---------|--------------|---------------|-------|--------|
| Finding 1 | 3.8 | **4.8** | +1.0 | AV:N/AC:L/PR:H/UI:R/S:C/C:L/I:L/A:N |
| Finding 5 | 2.6 | **4.3** | +1.7 | AV:N/AC:L/PR:N/UI:R/S:U/C:N/I:L/A:N |
| A1 (CSP) | 5.3 | **6.1** | +0.8 | AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N |
| A2 (Headers) | 3.7 | **4.3** | +0.6 | AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:N/A:N |
| A3 (noreferrer) | 2.6 | **4.3** | +1.7 | AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:N/A:N |
| A4 (Deps) | 3.3 | **4.3** | +1.0 | AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:N/A:N |

**Verification methodology**: CVSS v3.1 specification formula with standard metric values (AV:N=0.85, AC:L=0.77, PR:H with S:C=0.50, PR:N=0.85, UI:R=0.62, C:L=0.22, I:L=0.22, etc.). Reference calculation verified against known baseline AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H = 9.8 ✓.

**What must be corrected**: Either fix the scores to match the stated vectors, or adjust the vectors to produce the intended scores. If the report intended to apply contextual/environmental modifiers to reduce scores, this must be explicitly documented — base scores cannot be arbitrarily adjusted.

### Issue 2 — CRITICAL: A2, A3, A4 Share Identical Vectors but Claim Different Scores

Findings A2, A3, and A4 all use the vector `AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:N/A:N` but claim scores of 3.7, 2.6, and 3.3 respectively. The same vector must produce the same score (4.3). This is a computational impossibility that suggests scores were manually assigned without calculator verification.

**What it should be**: All three should show 4.3, or the vectors should be differentiated to reflect the intended risk differences between these findings.

### Issue 3 — MAJOR: Finding 5 Uses PR:N but Input Is Hardcoded

Finding 5 (`window.location.href` assignment) scores with `PR:N` (No Privileges Required), yet the analysis itself states: _"newLocale is sourced from hardcoded LOCALES array"_ and _"No untrusted runtime input can set newLocale through intended UI path."_

If no attacker-controlled input reaches the sink, there is no exploitable vulnerability and the appropriate score is **0.0** (SAFE PATTERN like Findings 2–4, 6–7). Using PR:N implies an unauthenticated remote attacker can exploit this, which contradicts the analysis.

If the intent is to score the hypothetical future risk (locale source changes), then AC:H should be used (requires code modification), and PR:H (requires commit access) would be appropriate, yielding a much lower score.

**What it should be**: Either 0.0 (consistent with "SAFE PATTERN" classification) or rescored with PR:H/AC:H to reflect the actual exploit preconditions described. The current PR:N directly contradicts the technical analysis.

### Issue 4 — MAJOR: Finding 1 Supply-Chain Risk Under-Classified

Finding 1 is classified as "SAFE PATTERN (Conditional Risk)" at **Low** severity. While the runtime exploitability assessment is correct, the classification insufficiently weights the supply-chain dimension:

- `allowDangerousHtml: true` + `rehypeRaw` + `dangerouslySetInnerHTML` with **no sanitization** creates a high-leverage XSS primitive
- A compromised remark/rehype dependency could inject active HTML/JS into all static pages during build — this is stealthier and harder to detect than a malicious markdown commit
- The absence of CSP (A1) means there is no browser-enforced backstop if this pipeline is compromised
- The combination of "unsanitized HTML pipeline" + "no CSP" represents compound risk that exceeds what "Low" conveys

**What it should be**: Classify as **"Conditional Medium (Supply-Chain/Content Trust)"** or explicitly add a separate finding for the supply-chain attack path through the rehype pipeline. The current "Low" severity does not adequately communicate the blast radius of a pipeline compromise.

### Issue 5 — MAJOR: Finding 1 PR:H Appropriateness

The use of PR:H (High Privileges Required) for Finding 1 is debatable but defensible. PR:H maps to "admin-level" access in CVSS semantics. For a repository context:

- If the repo accepts external pull requests, a malicious contributor only needs a PR merged (arguably PR:L — basic authenticated access)
- If the repo is private with trusted committers only, PR:H is appropriate
- The distinction matters: PR:L with S:C yields 5.4 instead of 4.8

**Recommendation**: The report should explicitly state the trust model assumption (private repo / protected main branch / required reviews) that justifies PR:H. Without this documentation, the metric choice appears arbitrary.

### Issue 6 — MINOR: A1 (Missing CSP) Scope Changed Questionable

A1 uses S:C (Scope Changed), which means exploiting the vulnerability impacts resources beyond the vulnerable component's security scope. For a missing CSP on a static site:

- The "vulnerable component" is the deployment configuration
- The "impacted component" would be the browser rendering context
- S:C is arguably justified since missing headers in the deployment affect the browser security boundary

However, missing security controls are hardening gaps, not traditional vulnerabilities. CVSS is designed for scoring exploitable vulnerabilities, not absent preventive controls. The report should acknowledge this semantic limitation.

**What it should be**: Note explicitly that CVSS was applied as a severity proxy for a hardening gap, not a traditional vulnerability score. The S:C usage is defensible but should be justified in the text.

### Issue 7 — MINOR: Missing Explicit Checks

The report should explicitly state findings (even as N/A) for the following areas to demonstrate completeness:

- **Source map exposure**: Are `.map` files served in production? (Should verify `productionBrowserSourceMaps` in `next.config.ts`)
- **DOM clobbering**: Raw HTML pipeline can permit DOM clobbering primitives (e.g., `<form id="location">`) — should be explicitly assessed
- **Client-side data exposure**: Explicitly confirm that `docs.json` and other static JSON bundles contain no secrets or internal metadata
- **Cookie security**: Explicitly state N/A if no cookies are set
- **Mixed content**: Explicitly confirm no `http://` resource references
- **Next.js/React version advisories**: The statement _"no evidence of known exploitable CVEs"_ is weak — it should reference specific advisory checks performed against Next.js 16.1.6 and React 19.2.3

### Issue 8 — SUGGESTION: Improve Test Case Specificity

The current test cases (TC-01 through TC-05) are well-structured and specific — a significant improvement. Consider adding:

- **TC-06**: DOM clobbering test (raw HTML with `id`/`name` attributes matching global JS properties)
- **TC-07**: Inline script hash stability test (verify theme script SHA-256 doesn't change unexpectedly between builds)
- **TC-08**: Build artifact integrity baseline (hash comparison of generated static output)

---

## Answers to Specific Review Questions

### Q1: Finding 1 CVSS 3.8 with PR:H — Is PR:H correct?

**Conditionally correct.** PR:H is appropriate if the repository enforces branch protection, required reviews, and limits commit access to trusted maintainers. However:
- The mathematical score is wrong: the vector produces **4.8**, not 3.8
- If external PRs are accepted, PR:L (score: 5.4) may be more appropriate
- The report must document the trust model assumption that justifies PR:H

### Q2: Finding 5 CVSS 2.6 with PR:N — Should PR:N be used?

**No.** PR:N is incorrect. The locale input comes from hardcoded constants, not attacker-controlled input. The finding should either be scored 0.0 (consistent with its SAFE PATTERN classification) or use PR:H/AC:H if scoring the hypothetical future risk. The calculated score for the stated vector is actually 4.3, not 2.6.

### Q3: Missing CSP at Medium (5.3) — Appropriate for static site?

**The severity level is defensible, but the score is wrong.** The stated vector produces 6.1, not 5.3. Medium severity is justified specifically because of the unsanitized raw HTML rendering pipeline — without CSP, any content/supply-chain compromise has maximum browser blast radius. For a static site without the raw HTML pipeline, Low-Medium would be more appropriate.

### Q4: Should any findings be reclassified?

**Yes:**
- Finding 1: Elevate from Low to **Conditional Medium** (supply-chain risk dimension)
- Finding 5: Reclassify to **Info/0.0** (consistent with SAFE PATTERN, no attacker-reachable input) or adjust CVSS vector to PR:H/AC:H

### Q5: Should rehypeRaw + allowDangerousHtml be flagged more strongly?

**Yes.** The current classification correctly identifies the conditional risk but under-weights two dimensions:
1. **Plugin compromise** (remark/rehype dependency attack) is stealthier than malicious markdown and can affect all pages — this warrants its own risk register entry or explicit call-out
2. **Compound risk**: unsanitized pipeline + no CSP = no defense-in-depth. Either control alone would substantially reduce blast radius. The report should explicitly state that implementing **either** `rehype-sanitize` **or** CSP would break the attack chain, making both P1 priority

---

## Summary Assessment

| Category | Status |
|----------|--------|
| Qualitative analysis quality | ✅ Strong |
| Threat modeling accuracy | ✅ Sound |
| Classification correctness | ⚠️ Finding 1 under-classified; Finding 5 inconsistent |
| CVSS mathematical accuracy | ❌ All 6 non-zero scores wrong |
| CVSS metric appropriateness | ⚠️ Finding 5 PR:N contradicts analysis |
| Completeness | ⚠️ Missing explicit checks for source maps, DOM clobbering, version advisories |
| Remediation guidance | ✅ Comprehensive and actionable |
| Test cases | ✅ Specific and well-structured (TC-01 through TC-05) |
| Report structure | ✅ Well-organized with appendices |

**Overall Verdict: NEEDS REVISION**

The report's qualitative analysis and remediation guidance are publication-quality. However, the CVSS scoring errors are systemic and must be corrected — they affect every scored finding and include the impossibility of identical vectors yielding different scores. After CVSS correction and the classification adjustments noted above, this report would merit APPROVE status.
