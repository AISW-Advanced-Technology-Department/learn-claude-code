# Security Review — Next.js Frontend (`web/`)

Scope: 24 frontend files reviewed. This report validates the 7 flagged findings and confirms coverage across 10 requested security categories.

## Finding 1 — `src/components/docs/doc-renderer.tsx` line 87
```tsx
dangerouslySetInnerHTML={{ __html: html }}
```
**Verdict:** Real vulnerability (stored/build-time XSS risk)  
**Severity:** **Medium**

**Justification:**
- `dangerouslySetInnerHTML` is a direct HTML sink.
- Markdown is rendered with `remarkRehype({ allowDangerousHtml: true })` + `rehypeRaw`, which explicitly permits raw HTML from markdown into rendered DOM.
- Current runtime data source is static build-time JSON (`docs.json`), so exploitability depends on supply-chain/content-author trust, not end-user input.
- If a malicious/compromised markdown doc is committed (or generation pipeline is compromised), script-bearing HTML can execute client-side.

**Recommendations:**
1. Prefer safe markdown rendering: disable dangerous HTML (`allowDangerousHtml: false`) and remove `rehypeRaw` unless strictly required.
2. If raw HTML support is required, sanitize output with `rehype-sanitize` using a strict allowlist.
3. Add CI checks for docs content policy (deny `<script>`, event handlers, `javascript:` URLs).
4. Consider CSP hardening (`script-src` with nonce/hash, no unsafe-inline where possible).

---

## Finding 2 — `src/app/[locale]/layout.tsx` lines 41–48
```tsx
<script dangerouslySetInnerHTML={{ __html: `...` }} />
```
**Verdict:** Safe pattern (with caveat)  
**Severity:** **Low**

**Justification:**
- Inline script is fully hardcoded; no untrusted interpolation.
- Purpose is anti-FOUC theme initialization.
- No direct user-controlled data reaches script body.
- Residual concern: CSP compatibility and future regressions if interpolation is added later.

**Recommendations:**
1. Keep script static; do not inject dynamic/user data.
2. If CSP is enforced, use nonce/hash-based inline allowance.
3. Add code comment/guardrail noting this script must remain constant.

---

## Finding 3 — `scripts/extract-content.ts` line 88
```ts
while ((m = toolPattern.exec(source)) !== null) {
```
**Verdict:** Safe pattern  
**Severity:** **Info**

**Justification:**
- This is `RegExp.prototype.exec`, not command execution.
- No shell/process invocation involved.
- Build-time parsing logic only.

**Recommendations:**
- No security change required.
- Optional: rename variable/comments for clarity to avoid false positives.

---

## Finding 4 — `scripts/extract-content.ts` lines 258–266
```ts
fs.mkdirSync(OUT_DIR, { recursive: true });
fs.writeFileSync(indexPath, JSON.stringify(index, null, 2));
fs.writeFileSync(docsPath, JSON.stringify(docs, null, 2));
```
**Verdict:** Safe pattern  
**Severity:** **Info**

**Justification:**
- File writes target deterministic internal paths derived from `__dirname`.
- No user-supplied path input or traversal influence.
- Build-time generation script, not runtime request path.

**Recommendations:**
- Keep path construction deterministic.
- Optional defense-in-depth: ensure resolved targets stay under expected output directory before write.

---

## Finding 5 — `src/components/layout/header.tsx` line 45
```ts
window.location.href = newPath;
```
**Verdict:** Safe pattern  
**Severity:** **Low**

**Justification:**
- Destination path is derived from current pathname plus locale replacement from hardcoded `LOCALES`.
- No external protocol/domain/user input used to form redirect target.
- This is same-origin navigation, not open redirect in current form.

**Recommendations:**
1. Keep locale source constrained to hardcoded allowlist.
2. Optionally use Next.js router navigation (`router.push`) for consistency and reduced full reload behavior.

---

## Finding 6 — `src/lib/i18n.tsx` lines 28–30
Dynamic property access with `as any`.

**Verdict:** Safe pattern (type-safety smell, not security bug)  
**Severity:** **Info**

**Justification:**
- Access is against imported local message JSON objects (`en/zh/ja`) under app control.
- No prototype mutation path or user-controlled object keys observed.
- Risk is runtime fallback/undefined behavior, not direct exploit.

**Recommendations:**
1. Replace `as any` with typed keys (`keyof`) and stricter namespace typing.
2. Keep fallback behavior explicit to avoid silent misses.

---

## Finding 7 — `src/app/[locale]/layout.tsx` line 22
Dynamic property access on `metaMessages` with route param locale.

**Verdict:** Safe pattern  
**Severity:** **Low**

**Justification:**
- Access pattern: `metaMessages[locale] || metaMessages.en`.
- Unknown locale values safely fall back to `en`; no code execution sink.
- Used for metadata selection only.

**Recommendations:**
1. Validate/narrow locale param against explicit union (`'en'|'zh'|'ja'`) early.
2. Consider typing `locale` from route params with schema validation for robustness.

---

## Security Category Coverage (10/10)

1. **Code Injection** — **No confirmed issue** in reviewed findings.  
2. **External Data Exfiltration** — **No indicators found** (no suspicious outbound exfil patterns).  
3. **Crypto Mining** — **No indicators found**.  
4. **Shell Command Execution** — **No issue found**; Finding 3 is regex exec, not process exec.  
5. **File System Access** — **Reviewed**; Finding 4 is controlled build-time writes (safe).  
6. **Base64 Strings** — **No suspicious encoded payload patterns identified** in flagged scope.  
7. **Obfuscated Code** — **No indicators found**.  
8. **Backdoors** — **No indicators found**.  
9. **XSS** — **Confirmed risk** in Finding 1 due to raw HTML pipeline + HTML sink (`dangerouslySetInnerHTML`).  
10. **Prototype Pollution** — **No indicators found** in provided findings.

## Overall Assessment
- **Confirmed vulnerability:** 1 (Finding 1, Medium)  
- **Safe patterns / false positives:** 6  
- Primary actionable item is hardening markdown-to-HTML rendering and sanitization path.
