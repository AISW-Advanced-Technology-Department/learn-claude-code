# target="_blank" Security Research Report

**Date**: 2026-03-19
**Role**: Browser Security Specialist

## Research Summary

### 1. Does `target="_blank"` imply `noopener` by default?

**Yes.** All modern browsers now implicitly apply `rel="noopener"` when `target="_blank"` is used:

| Browser | Version | Date |
|---------|---------|------|
| Safari | 12.1+ | Early 2019 |
| Firefox | 79+ | Mid-2020 |
| Chrome | 88+ | Early 2021 |
| Edge (Chromium) | 88+ | Early 2021 |

**Sources**: [MDN rel="noopener"](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/rel/noopener), [Stefan Judis blog](https://www.stefanjudis.com/today-i-learned/target-blank-implies-rel-noopener/)

### 2. Does `noopener` prevent the Referer header?

**No.** `rel="noopener"` only nullifies `window.opener`. The `Referer` header is **still sent**. You need `rel="noreferrer"` to suppress the Referer header.

| Attribute | `window.opener` | Referer header |
|-----------|-----------------|----------------|
| `noopener` | ✗ null | ✓ sent |
| `noreferrer` | ✗ null | ✗ suppressed |
| `noopener noreferrer` | ✗ null | ✗ suppressed |

### 3. Security difference between `noopener` and `noopener noreferrer` today

- **`noopener`**: Prevents reverse tabnabbing (already implicit in modern browsers). Referer is still sent.
- **`noopener noreferrer`**: Same tabnabbing protection + hides the originating URL from the destination.

The difference is **primarily privacy**, not security. `noreferrer` adds no tabnabbing protection beyond what `noopener` already provides. It controls whether the destination site can see which page linked to it. **Caveat**: If the referring URL contains sensitive data (tokens, session IDs, internal paths), Referer leakage can have indirect security implications. Additionally, `Referrer-Policy` headers can also control this behavior independently.

### 4. Is missing `noreferrer` a security concern when linking to github.com?

**No, it is a privacy consideration only.** The security risk (reverse tabnabbing via `window.opener`) is already mitigated by:
1. Modern browsers implicitly applying `noopener`
2. GitHub.com being a trusted, non-malicious destination

Missing `noreferrer` only means GitHub can see the referring URL in its analytics. This is a **privacy** matter, not a security vulnerability. An attacker would need to compromise GitHub itself to exploit the `window.opener` path—at which point the Referer header is the least of your problems.

### 5. Verdict: Severity of missing `noreferrer`

**"Info" (Informational)** — rationale:

| Factor | Assessment |
|--------|------------|
| `window.opener` risk | None (implicit `noopener` in all modern browsers since 2021) |
| Destination trust | GitHub.com — trusted first-party |
| Referer leakage | Privacy, not security |
| OWASP classification | Reverse tabnabbing is Medium, but that refers to missing `noopener`, which is already mitigated |
| Practical exploitability | None in modern browsers; edge cases exist for legacy browsers/webviews |

Missing `noreferrer` on links to trusted sites like github.com is at most an **informational best-practice note**, not a vulnerability. Adding it is harmless and good hygiene, but flagging its absence as a security finding would be a false positive. **Note**: Severity could increase to Low if (a) the referring URL leaks sensitive data, (b) legacy browser support is required, or (c) links are user-controlled/subject to open redirects.

## References

- [OWASP: Reverse Tabnabbing](https://owasp.org/www-community/attacks/Reverse_Tabnabbing)
- [OWASP WSTG-CLNT-14](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/11-Client-side_Testing/14-Testing_for_Reverse_Tabnabbing)
- [Chrome Lighthouse: External anchors](https://developer.chrome.com/docs/lighthouse/best-practices/external-anchors-use-rel-noopener)
- [MDN: rel="noopener"](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Attributes/rel/noopener)
- [ZAP Alert 10108](https://www.zaproxy.org/docs/alerts/10108/)
