# CVSS v3.1 Compliance Review

## Executive Summary

This document reviews the provided security audit draft for CVSS v3.1 scoring accuracy and severity classification consistency. The review identified discrepancies between the documented vectors and the calculated scores in 8 out of 10 findings. Corrections are provided below to align with the CVSS v3.1 specification.

**Assessment Context:**
- Application: Next.js Static Export
- Deployment: Vercel (Cloud/CDN)
- Tooling: Python (Local/CI)

---

## Finding 1: Missing HTTP Security Headers

### 1. Analysis
- **Vector Provided:** `AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:L/A:N`
- **Scenario:** Missing hardening headers (CSP, HSTS, etc.) in `vercel.json`.
- **Critique:** The vector correctly identifies network exposure (AV:N), low complexity (AC:L), and lack of authentication (PR:N). Missing headers generally allow for attacks impacting Confidentiality and Integrity (e.g., XSS, MITM), justifying C:L/I:L.

### 2. Verify Score
- **Claimed Score:** 5.3
- **Calculated Score:** **6.5**
- **Discrepancy:** The claimed score (5.3) is significantly lower than the standard calculation for this vector (6.5).

### 3. Verify Severity
- **Claimed Severity:** Medium
- **Actual Severity:** Medium (4.0 - 6.9)
- **Status:** Consistent (both are Medium).

### 4. Corrections
- **Correct Score:** 6.5
- **Explanation:** Recalculated based on the provided vector.

---

## Finding 2: Redirect Pattern Is Not a Practical Open Redirect

### 1. Analysis
- **Vector Provided:** `AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:N`
- **Scenario:** Hardcoded redirect safeguards against open redirect.
- **Critique:** The vector reflects "No Impact" (C:N/I:N/A:N), which is appropriate for a finding that describes a non-vulnerability or a mitigated risk.

### 2. Verify Score
- **Claimed Score:** 0.0
- **Calculated Score:** 0.0
- **Discrepancy:** None.

### 3. Verify Severity
- **Claimed Severity:** Info
- **Actual Severity:** None (0.0)
- **Status:** Consistent. "Info" is an appropriate label for 0.0 findings in audit reports.

### 4. Corrections
- **Status:** **Correct**. No changes needed.
- **Special Attention:** Yes, 0.0 is justified as the finding explicitly states the pattern is "Not a Practical Open Redirect," meaning no vulnerability exists.

---

## Finding 3: `rehypeRaw` + Dangerous HTML

### 1. Analysis
- **Vector Provided:** `AV:N/AC:H/PR:H/UI:R/S:C/C:L/I:L/A:N`
- **Scenario:** Build-time XSS risk via repository markdown.
- **Critique:**
    - **AV:N:** Correct (git/repo access).
    - **AC:H:** Plausible if exploitation requires bypassing code review or specific build conditions.
    - **PR:H:** Correct (requires commit access).
    - **S:C:** Correct (XSS implies scope change).

### 2. Verify Score
- **Claimed Score:** 3.8
- **Calculated Score:** **4.0**
- **Discrepancy:** 3.8 is mathematically incorrect for this vector.

### 3. Verify Severity
- **Claimed Severity:** Low
- **Actual Severity:** **Medium** (4.0 falls into Medium range).
- **Status:** Inconsistent.

### 4. Corrections
- **Correct Score:** 4.0
- **Correct Severity:** Medium
- **Explanation:** Recalculated. The jump from 3.9 (Low) to 4.0 (Medium) changes the severity classification.

---

## Finding 4: Inline Theme Script Weakens CSP

### 1. Analysis
- **Vector Provided:** `AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N`
- **Scenario:** Inline script potentially enabling XSS.
- **Critique:**
    - **S:C (Scope Changed):** The audit claims S:C, which usually results in a higher score (6.1). The claimed score (5.4) corresponds to Scope Unchanged (S:U).
    - **Context:** An inline script itself is a "weakness" that facilitates XSS, but unless it *is* an active XSS payload, it doesn't inherently change scope. However, if treating it as "Stored XSS/Pivot", S:C is valid.
    - **Mismatch:** The provided score (5.4) matches the vector *only if* S is changed to U (and calculated precisely as 5.3, rounded to 5.3).

### 2. Verify Score
- **Claimed Score:** 5.4
- **Calculated Score:** **6.1** (with S:C) / **5.3** (with S:U)
- **Discrepancy:** The claimed score (5.4) is closer to S:U (5.3) than S:C (6.1).

### 3. Verify Severity
- **Claimed Severity:** Medium
- **Actual Severity:** Medium (in both cases).
- **Status:** Consistent severity, inconsistent vector/score.

### 4. Corrections
- **Correct Vector:** `AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:L/A:N`
- **Correct Score:** 5.3
- **Explanation:** Changed `S:C` to `S:U` to reflect the vulnerability as a "weakness" rather than an active cross-scope attack. The score is corrected to 5.3.

---

## Finding 5: `skipLibCheck: true`

### 1. Analysis
- **Vector Provided:** `AV:L/AC:H/PR:H/UI:N/S:U/C:N/I:L/A:N`
- **Scenario:** Reduced type checking in build.
- **Critique:** Vector is reasonable for a local build configuration issue.

### 2. Verify Score
- **Claimed Score:** 2.7
- **Calculated Score:** **1.9**
- **Discrepancy:** Significant. 2.7 is likely a miscalculation or typo.

### 3. Verify Severity
- **Claimed Severity:** Low
- **Actual Severity:** Low
- **Status:** Consistent severity.

### 4. Corrections
- **Correct Score:** 1.9
- **Explanation:** Recalculated.

---

## Finding 6: `allowJs: true`

### 1. Analysis
- **Vector Provided:** `AV:L/AC:H/PR:H/UI:N/S:U/C:N/I:N/A:N`
- **Scenario:** Permissive compiler setting.
- **Critique:** Impacts are set to None (N), resulting in 0.0.

### 2. Verify Score
- **Claimed Score:** 0.0
- **Calculated Score:** 0.0
- **Discrepancy:** None.

### 3. Verify Severity
- **Claimed Severity:** Info
- **Actual Severity:** None
- **Status:** Consistent.

### 4. Corrections
- **Status:** **Correct**. No changes needed.

---

## Finding 7: `tsx` in Production Dependencies

### 1. Analysis
- **Vector Provided:** `AV:N/AC:H/PR:N/UI:N/S:U/C:L/I:N/A:N`
- **Scenario:** Dev tool in prod deps.
- **Critique:** Vector implies network exposure (AV:N) and low confidentiality impact (C:L). Plausible for supply chain surface area.

### 2. Verify Score
- **Claimed Score:** 3.3
- **Calculated Score:** **3.7**
- **Discrepancy:** Minor calculation error.

### 3. Verify Severity
- **Claimed Severity:** Low
- **Actual Severity:** Low
- **Status:** Consistent.

### 4. Corrections
- **Correct Score:** 3.7
- **Explanation:** Recalculated.

---

## Finding 8: Next.js Version Behind

### 1. Analysis
- **Vector Provided:** `AV:N/AC:H/PR:N/UI:N/S:U/C:L/I:N/A:N`
- **Scenario:** Patch version outdated.
- **Critique:** Same vector as Finding 7. Appropriate for theoretical risk.

### 2. Verify Score
- **Claimed Score:** 3.1
- **Calculated Score:** **3.7**
- **Discrepancy:** Minor calculation error.

### 3. Verify Severity
- **Claimed Severity:** Low
- **Actual Severity:** Low
- **Status:** Consistent.

### 4. Corrections
- **Correct Score:** 3.7
- **Explanation:** Recalculated.

---

## Finding 9: Python Dependencies Open-Ended (`>=`)

### 1. Analysis
- **Vector Provided:** `AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:L/A:L`
- **Scenario:** Supply chain risk via `pip install`.
- **Critique:**
    - **AV:N (Network):** Correct. The attack vector is the network (PyPI registry). Even if `requirements.txt` is local, the *vulnerability* allows fetching malicious code from the network. **AV:L would be incorrect** as it implies the attacker needs local access to exploit it.
    - **UI:N (User Interaction):** Incorrect. `requirements.txt` does not install itself. A user (developer) or CI process must run `pip install`. This requires **UI:R**.
    - **Impact (C:L/I:L/A:L):** Low. Malicious packages typically execute arbitrary code (`setup.py`), leading to **High** impact (C:H/I:H/A:H) on the build environment.

### 2. Verify Score
- **Claimed Score:** 5.9
- **Calculated Score:** **7.3** (using the *provided* vector).
- **Discrepancy:** Major. The claimed score (5.9) does not match the provided vector (7.3).

### 3. Verify Severity
- **Claimed Severity:** Medium
- **Actual Severity:** High (7.3)
- **Status:** Inconsistent.

### 4. Corrections
- **Correct Vector:** `AV:N/AC:L/PR:N/UI:R/S:U/C:H/I:H/A:H`
- **Correct Score:** **8.8**
- **Correct Severity:** **High**
- **Explanation:**
    - Changed `UI:N` to `UI:R` (installation requires action).
    - Changed Impacts to `H/H/H` (RCE is typical for malicious packages).
    - If a lower severity "volatility" risk is intended, impacts could remain Low, but `UI` must be `R`. (With UI:R and Low impacts, score is 5.5). However, for a security audit, we assume the worst-case exploit of the vulnerability.
    - **Recommendation:** Use `AV:N/AC:L/PR:N/UI:R/S:U/C:H/I:H/A:H` (Score 8.8) to reflect the true risk of RCE. If strictly assessing "volatility" without confirmed exploit, `AC:H` might be applied (Score 7.5).

---

## Finding 10: `incremental: true`

### 1. Analysis
- **Vector Provided:** `AV:L/AC:H/PR:H/UI:N/S:U/C:N/I:L/A:N`
- **Scenario:** Build cache staleness.
- **Critique:** Vector appropriate.

### 2. Verify Score
- **Claimed Score:** 2.6
- **Calculated Score:** **1.9**
- **Discrepancy:** Calculation error.

### 3. Verify Severity
- **Claimed Severity:** Low
- **Actual Severity:** Low
- **Status:** Consistent.

### 4. Corrections
- **Correct Score:** 1.9
- **Explanation:** Recalculated.

---

## Summary of Corrections Required

| Finding | Field | From | To |
|---|---|---|---|
| **1** | Score | 5.3 | **6.5** |
| **3** | Score | 3.8 | **4.0** |
| **3** | Severity | Low | **Medium** |
| **4** | Vector | S:C | **S:U** (to match score) |
| **5** | Score | 2.7 | **1.9** |
| **7** | Score | 3.3 | **3.7** |
| **8** | Score | 3.1 | **3.7** |
| **9** | Vector | UI:N, Impacts L | **UI:R**, **Impacts H** |
| **9** | Score | 5.9 | **8.8** |
| **9** | Severity | Medium | **High** |
| **10** | Score | 2.6 | **1.9** |
