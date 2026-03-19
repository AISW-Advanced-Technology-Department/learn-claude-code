# Web Standards & Security Verification: Reverse Tabnabbing Analysis

## Executive Summary
This document provides a verified analysis of the draft security review concerning `rel="noopener"` and `rel="noreferrer"` attributes, cross-referencing claims against WHATWG specifications and browser release history.

## Task Analysis & Verdicts

### Task 1: Browser Versions (Implicit `noopener`)
- **Verdict**: **CORRECT**
- **Analysis**: The draft's claim regarding browser versions that implicitly apply `noopener` behavior to `target="_blank"` links aligns perfectly with historical release data:
    - **Safari 12.1+**: Confirmed (Released 2019-03-25 with macOS 10.14.4).
    - **Firefox 79+**: Confirmed (Released 2020-07-28).
    - **Chrome 88+**: Confirmed (Released 2021-01-19).
    - **Edge 88+**: Confirmed (Aligns with Chromium 88).
- **Justification**: These versions mark the normative change where `target="_blank"` implies `rel="noopener"` by default, mitigating the tabnabbing vulnerability for the vast majority of modern traffic.

### Task 2: `noopener` vs `noreferrer` Behavior
- **Verdict**: **CORRECT**
- **Analysis**: The draft accurately reflects the WHATWG HTML Living Standard.
    - **Spec Reference**: The specification for `noreferrer` states it must create a new top-level browsing context with the `opener` attribute set to null (effectively `noopener`) AND prevent the `Referer` header from being sent.
    - **Key Distinction**: The draft correctly identifies that `noreferrer` is a superset of `noopener`'s security protections, debunking the common misconception that they are orthogonal.

### Task 3: "Purely Privacy, Not Security" Claim
- **Verdict**: **NEEDS NUANCE** (Draft's "INCORRECT" is technically valid but contextually rigid)
- **Analysis**:
    - **Technical Reality**: `rel="noreferrer"` *always* provides the security benefit of `noopener` (nullifying `window.opener`). Therefore, describing it as "purely privacy" is technically incorrect because it inherently includes a critical security control.
    - **Contextual Reality**: In the specific context of linking to a trusted domain like `github.com` (which is unlikely to host malicious reverse-tabnabbing scripts) from a source URL with no sensitive tokens, the *observable benefit* is indeed primarily privacy (hiding the source graph).
    - **Recommendation**: The verdict should be **NEEDS NUANCE**. While the original "purely privacy" claim ignores the security mechanism, the *practical risk* in the specific context (GitHub links) is negligible. However, strict adherence to accuracy requires acknowledging the dual benefit.

### Task 4: Severity "Info" Classification
- **Verdict**: **NEEDS NUANCE**
- **Analysis**: The draft's hesitation to accept "Info" without qualification is sound.
    - **Legacy Context**: For older browsers (pre-2021), this is a **Medium** severity vulnerability (CVSS ~6.1), allowing phishing attacks via `window.opener`.
    - **Modern Context**: For modern browsers, the risk is **Info/None** because the browser enforces `noopener` by default.
    - **Conclusion**: A global "Info" rating is dangerous if the user base includes legacy browsers or enterprise environments with slow update cycles. The "NEEDS NUANCE" verdict properly captures this dependency.

### Task 5: Additional Items (CVSS & OWASP)
- **Verdict**: **VALID CRITIQUE**
- **Analysis**:
    - **CVSS Scoring**: The draft's critique of the "~5.2" estimate is fair. CVE-2019-25155 provides a concrete precedent of **6.1 (Medium)** for DOM-based reverse tabnabbing. Citing a real CVE is superior to estimating.
    - **OWASP vs. NVD**: The draft correctly distinguishes between OWASP (which classifies risks/categories, e.g., "Medium") and NVD (which assigns specific numerical scores to CVEs). This distinction is crucial for accurate reporting.

### Task 6: Missing Nuances
The draft should explicitly address the following to be complete:
1.  **The "Implicit Noopener" Era**: The most critical nuance is that for 95%+ of users today, the vulnerability is mitigated at the browser level. The report should explicitly state that `rel="noopener"` is becoming a defense-in-depth measure for legacy support rather than a primary control for modern clients.
2.  **Referrer-Policy Header**: The draft focuses on `rel` attributes but omits the `Referrer-Policy` HTTP header, which is the modern, site-wide standard for controlling referrer leakage. This is relevant to the "privacy" aspect of the discussion.
