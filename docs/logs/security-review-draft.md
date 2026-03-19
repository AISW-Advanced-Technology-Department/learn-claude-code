# Factual Accuracy Review — Security Research Report

## Scope
Review based strictly on the provided **verified facts** (browser release data, MDN/WHATWG behavior, OWASP/NVD severity context, and Referer leakage implications).

## Claim-by-Claim Verdicts

### Claim 1: Browser version numbers for implicit `noopener`
**Report claim:** Safari 12.1+ (Early 2019), Firefox 79+ (Mid-2020), Chrome 88+ (Early 2021), Edge 88+ (Early 2021).  
**Verdict:** **CORRECT**

**Justification:**
- **Safari 12.1**: released **2019-03-25** (macOS 10.14.4 / iOS 12.2), implicit `noopener` confirmed (Apple release notes, WebKit).
- **Firefox 79**: released **2020-07-28**, implicit `noopener` confirmed (Firefox 79 notes / MDN ecosystem references).
- **Chrome 88**: released **2021-01-19**, implicit `noopener` confirmed (MDN + Chromium ecosystem sources).
- **Edge 88+**: Chromium-based, so timing aligns with Chrome 88-era behavior.

---

### Claim 2: `noopener` vs `noreferrer` Referer behavior
**Report claim:** `noopener` still sends `Referer`; `noreferrer` suppresses `Referer`; table states `noreferrer` nullifies `window.opener`.  
**Verdict:** **CORRECT**

**Justification:**
- `rel="noopener"` affects opener relationship only (sets `window.opener` to `null`) and **does not** suppress `Referer`.
- `rel="noreferrer"` suppresses `Referer` and, per WHATWG HTML semantics, **implies noopener behavior**.
- Therefore, marking `noreferrer` as nullifying `window.opener` is factually correct.

---

### Claim 3: “The difference is purely privacy, not security”
**Verdict:** **INCORRECT** (overly absolute)

**Justification:**
- Referer leakage is not always “privacy-only.” It can become a **security issue** if URLs contain sensitive data (tokens, reset links, API keys, session identifiers).
- This is consistent with:
  - OWASP guidance on query-string information exposure,
  - PortSwigger’s treatment of cross-domain Referer leakage,
  - MDN’s explicit “privacy and security concerns” framing.
- Correct framing: impact is context-dependent; privacy-only in many benign URL patterns, but potentially security-relevant when sensitive URL data exists.

---

### Claim 4: Severity verdict “Info” for missing `noreferrer` on links to `github.com`
**Verdict:** **NEEDS NUANCE**

**Justification:**
- If originating URLs do **not** carry sensitive query/path data, missing `noreferrer` is typically an **informational/privacy-hardening** issue.
- If sensitive URL data exists, leakage can be security-relevant; severity may rise above “Info.”
- So “Info” can be reasonable for the stated `github.com` context **only with explicit assumptions** about non-sensitive source URLs.

---

## Additional Items (Claim 5)

1. **“OWASP classification: Reverse tabnabbing is Medium”**
   - **Needs correction/precision.** OWASP describes reverse tabnabbing as a client-side vulnerability pattern and recommends mitigations, but CVSS scoring authority typically comes from CVE/NVD records.
   - Provided verified CVE example (**CVE-2019-25155**) is **CVSS 3.1 = 6.1 (Medium)**, vector `AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N`.
   - Therefore, citing “~5.2” is inconsistent with the provided NVD-backed example.

2. **Table entry: `noreferrer` nullifies `window.opener`**
   - **Correct per spec behavior** (`noreferrer` implies noopener effect).

3. **“Referer leakage is a privacy matter, not a security vulnerability”**
   - **Not fully accurate.** It is conditional: often privacy-only, but can be security-relevant when sensitive URL data is exposed.

4. **Optional nuance for completeness**
   - `rel="noopener noreferrer"` is functionally redundant in modern engines for opener protection, but commonly retained for legacy compatibility and explicitness.

## Overall Assessment
The report is **mostly accurate on browser-version chronology and `rel` semantics**, but contains a **material overstatement** by treating Referer leakage as categorically non-security. Its severity conclusions should be reframed as **context-dependent**. The CVSS discussion should align with cited NVD evidence (e.g., 6.1 Medium for the provided CVE) rather than approximate lower values.
