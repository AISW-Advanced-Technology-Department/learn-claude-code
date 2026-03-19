# CVSS v3.1 Specification Semantics Review

**Date:** 2026-03-19  
**Document Under Review:** Adjudication Document (Q1, Q2, Q3 Finding 5, Q4 A1, Q5 A2/A3/A4)

---

## Scope and Method

This review evaluates the adjudication document’s CVSS v3.1 reasoning against FIRST CVSS v3.1 Specification semantics and User Guide guidance for a specific implementation context:

- Next.js static export documentation site
- No server runtime, API routes, forms, or database
- Build-time markdown ingestion from `docs/`
- HTML rendering via `dangerouslySetInnerHTML` with `remarkRehype({ allowDangerousHtml: true })` and `rehypeRaw`
- No runtime user-input channels
- Public web access

The analysis is organized into six requested areas. Each area includes:

1. **Finding** (Material issue / No issue)
2. **Explanation** with citations
3. **Correction** (where applicable)

Citations use bracketed references such as [Spec §2.1.3].

---

## Area 1: PR:H for Finding 1 (`dangerouslySetInnerHTML` + build-time markdown)

### Finding
**Material issue** (with partial defensibility in implementation-specific risk framing).

### Explanation
The adjudication’s core rationale for PR:H is that exploitation requires merge rights or equivalent high-trust pipeline compromise. That practical observation is valid in this architecture, but the formal CVSS framing used to justify it is problematic.

1. **Vulnerable component semantics are misapplied.**  
   CVSS states exploitability metrics are scored relative to the **vulnerable component** [Spec §2.1]. In this case, the flaw under analysis is unsanitized HTML rendering in application code (`dangerouslySetInnerHTML` with dangerous HTML processing). That is a property of the web application implementation, not of SCM/CI governance itself.

2. **XSS framing in the User Guide anchors vulnerable component as the web application.**  
   User Guide Example 4 explicitly frames web-app vulnerabilities (including XSS/URL redirection) as vulnerabilities in the web application that impact user browsers [User Guide §3.5, Example 4]. This supports treating the vulnerable component as the web application layer.

3. **PR metric semantics create tension in static-content pipelines.**  
   PR measures privileges an attacker must possess **before exploiting the vulnerability** on the vulnerable component [Spec §2.1.3]. The web app has no authentication/authorization boundary, which in strict interpretation pushes PR toward None (N). The adjudication instead maps required upstream content-modification rights to PR:H.

4. **This is not a pure library-in-isolation score.**  
   User Guide library scoring guidance allows worst-case assumptions when implementation context is unknown [User Guide §3.7]. Here, implementation context is known and constrained: the only injection path is build-time content control. Therefore, an implementation-specific score may reasonably account for that constraint, but should clearly state this is a contextual narrowing—not a redefinition of vulnerable component semantics.

5. **Practice vs. specification strictness.**  
   In real-world stored-XSS scoring practice, PR often reflects who can inject stored content (e.g., PR:N for public posting, PR:L for authenticated contributors). In this case, content injection requires high trust in repository/pipeline operations. That makes PR:H operationally defensible as a conservative implementation-specific interpretation, but not “spec-definitive” under a strict vulnerable-component reading.

6. **Potential vulnerability-chaining concern.**  
   If exploitability requires prior compromise of separate systems (e.g., SCM/CI), the score can risk blending vulnerabilities in a chain. CVSS guidance cautions around chaining semantics [User Guide §3.4]. If no independent attacker-controlled injection channel exists, one could argue this may not cleanly map to a standalone base-score vulnerability in the deployed app context.

### Correction
- **Correct the vulnerable-component definition**: It should be the web application implementation containing unsafe rendering logic, not “content/build trust domain” as the primary vulnerable component [Spec §2.1; User Guide §3.5].
- **Reframe PR discussion explicitly as a semantic tradeoff**:
  - **Spec-pure reading:** PR:N (no auth boundary on vulnerable web component) [Spec §2.1.3].
  - **Implementation-constrained pragmatic reading:** PR:H (only privileged content maintainers can introduce malicious payloads).
- **Do not present PR:H as unequivocally definitive.** Present it as a context-sensitive judgment with acknowledged tension.
- Consider whether this should be treated as **N/A in base scoring** absent a direct attacker injection path, depending on adjudication policy for chain-dependent conditions [User Guide §3.4].

---

## Area 2: Scope Changed (S:C) rationale

### Finding
**Minor issue (reasoning flaw), conclusion correct.**

### Explanation
The adjudication concludes S:C, which is correct for web-app XSS/redirect classes where browser-side impacts occur across security scopes [Spec §2.2; User Guide §3.5, Example 4].

However, the adjudication’s stated rationale depends on an incorrect vulnerable-component definition (“content/build trust domain”). Even if that definition is corrected to “web application” (as required by CVSS semantics for this flaw), S:C still holds because the impacted component is the victim browser in a different security scope [Spec §2.2; User Guide §3.5, Example 4].

So the result is robust, but the explanatory path is semantically inconsistent.

### Correction
- Keep **S:C**.
- Replace rationale with: “Vulnerability is in the web application; impact occurs in user browser context across security scope boundaries” [Spec §2.2; User Guide §3.5, Example 4].

---

## Area 3: Q3 Finding 5 PR correction (`window.location.href` with hardcoded locales)

### Finding
**Material issue.**

### Explanation
The adjudication changes PR:N to PR:H on grounds that only source-code editors can alter redirect behavior. This shift does not resolve the underlying category error.

If redirect destinations are hardcoded constants and cannot be influenced by attacker-controlled runtime input, there is no exploitable redirect vulnerability in the deployed application behavior. CVSS scores vulnerabilities, not mere code patterns or hypothetical behavior requiring source modification by trusted maintainers.

- Original PR:N claim implied external attacker exploitability without privileged code changes.
- Corrected PR:H claim still presumes “exploit” equals editing source code.

Editing source code to alter behavior is software development activity, not exploitation of a vulnerability in the released artifact. Therefore, the issue should be classified as non-vulnerable (or informational/code-quality), not rescored with PR:H.

### Correction
- Mark this item **N/A (not a vulnerability)** for CVSS purposes.
- If retained in report, label as **code quality / design observation** rather than security vulnerability.

---

## Area 4: Q4 A1 Missing CSP

### Finding
**No material issue.**

### Explanation
The adjudication is substantially correct:

1. **Missing CSP alone is not a direct vulnerability.** CVSS measures vulnerability severity, not baseline control completeness [User Guide §2.1].
2. **Arithmetic correction is correct.** The stated vector `AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N` computes to **6.1**, not 5.3.
3. **Conditional “if forced” alternative with AC:H is reasonable.** This reflects additional preconditions (e.g., another exploit path) beyond attacker direct control, consistent with AC semantics [Spec §2.1.2].

Overall, this section demonstrates proper distinction between control-gap assessment and exploitability-scored vulnerability.

### Correction
No substantive correction required. Optional enhancement: explicitly cite CVSS scope of applicability to reduce future scoring drift.

---

## Area 5: Q5 A2/A3/A4 identical vectors

### Finding
**Mostly correct; minor precision issue.**

### Explanation
The adjudication correctly identifies score arithmetic normalization:

- `AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:N/A:N` = **4.3** (not 3.7/2.6/3.3).

This correction is valid.

Use of AC:H variants for differentiation can also be valid if specific findings truly depend on attacker-external conditions [Spec §2.1.2]. For example, if exploitation requires environmental conditions not under attacker control, AC:H may be justified.

A4 as N/A (unproven dependency/program-level process concern) is also appropriate when no concrete exploitable vulnerability is demonstrated.

The minor issue is analytical precision: each AC:H adjustment should be explicitly tied to concrete, finding-specific preconditions rather than applied as broad normalization.

### Correction
- Keep arithmetic correction to **4.3** where vector remains AC:L.
- Where AC:H is used, add explicit per-finding precondition statements mapped to AC definition language [Spec §2.1.2].
- Keep A4 as **N/A** if no exploitable defect is evidenced.

---

## Area 6: Internal consistency

### Finding
**Material issue (systemic semantic inconsistency).**

### Explanation
There is a cross-section contradiction in vulnerable-component framing:

1. Q1 justifies PR:H via “content/build trust domain.”
2. Q3 justifies PR:H via “source-code editors can alter behavior.”

These are not the same component definition, and both diverge from the CVSS model that exploitability is scored against the vulnerable component containing the flaw [Spec §2.1]. In both cases, the flaw is described in application behavior/code, while PR justification is shifted upstream to governance/editorship domains.

This pattern suggests outcome-driven redefinition of vulnerable component to reach desired PR values, rather than first-principles application of CVSS semantics.

Notably, Scope conclusions survive this inconsistency because XSS/redirect-style browser impact remains cross-scope under proper framing [Spec §2.2; User Guide §3.5, Example 4]. But PR and overall exploitability conclusions become unstable and less reproducible.

### Correction
- Standardize vulnerable-component identification methodology:
  1. Identify component containing flaw (software behavior/implementation).
  2. Score exploitability relative to that component [Spec §2.1].
  3. If implementation constraints (e.g., trusted content-only ingestion) materially affect exploitability, document as **contextual assumptions**—not as component redefinition.
- Add a consistency rule: identical semantic classes (stored content handling, redirect handling) must use a consistent vulnerable-component model unless explicitly justified.

---

## Overall Conclusion

The adjudication document contains a mix of correct outcomes and semantic framing errors:

- It is strongest on arithmetic corrections and on identifying non-vulnerability cases (missing CSP, some process-only findings).
- Its main weakness is inconsistent and spec-inaccurate vulnerable-component framing used to force PR:H outcomes.
- In the static-site/build-time context, PR:H can be argued pragmatically, but should be presented as a bounded implementation judgment with explicit acknowledgment of CVSS semantic tension.
- For findings requiring source modification without attacker-controlled runtime influence, N/A is more correct than PR re-scaling.

---

## Summary of Findings

| Area | Topic | Finding | Assessment | Required Action |
|---|---|---|---|---|
| 1 | PR:H for build-time markdown XSS (Finding 1) | **Material issue** | Vulnerable component misdefined; PR:H may be pragmatically defensible but not spec-definitive | Correct component framing; present PR interpretation tradeoff; consider N/A if chain-dependent |
| 2 | Scope Changed rationale (Q2) | **Minor issue** | Conclusion S:C is correct, reasoning uses wrong component framing | Keep S:C; rewrite rationale per web-app→browser scope model |
| 3 | PR correction for hardcoded redirect (Finding 5) | **Material issue** | Both PR:N and PR:H scoring approaches misclassify a likely non-vulnerability | Mark N/A; classify as code-quality/informational unless exploit path exists |
| 4 | Missing CSP (A1) | **No issue** | Correctly treated as control gap; math correction to 6.1 is accurate; conditional AC:H framing reasonable | No substantive change needed |
| 5 | A2/A3/A4 vector normalization | **Minor issue** | 4.3 correction is right; AC:H differentiation plausible but needs tighter per-finding justification; A4 N/A reasonable | Add explicit AC:H precondition mapping per finding |
| 6 | Internal consistency across Q1/Q3 | **Material issue** | Systemic component-framing inconsistency used to justify PR outcomes | Enforce consistent vulnerable-component method across findings |

---

## Citation Index

- [Spec §2.1] CVSS v3.1 Base Metrics – Exploitability metrics are scored relative to the vulnerable component.  
- [Spec §2.1.2] Attack Complexity definitions (including conditions beyond attacker control).  
- [Spec §2.1.3] Privileges Required definitions and guidance.  
- [Spec §2.2] Scope definition (changed vs unchanged security scope).  
- [User Guide §2.1] CVSS measures severity of vulnerabilities (not generic best-practice gaps).  
- [User Guide §3.4] Vulnerability chaining considerations.  
- [User Guide §3.5, Example 4] Scope change example: web-app vulnerabilities impacting browsers (XSS/redirect).  
- [User Guide §3.7] Library scoring (reasonable worst case) vs implementation-specific rescoring.

