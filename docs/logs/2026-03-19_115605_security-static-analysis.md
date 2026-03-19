# Security Static Analysis Report — Consolidated

**Date:** 2026-03-19  
**Scope:** 24 frontend files in `web/src/` and `web/scripts/`  
**Reviewers:** Gemini 3 Pro (Defense-in-Depth Analyst), GPT-5.3-Codex (Secure Architecture Reviewer)  
**Methodology:** Manual static analysis across 10 security categories

---

## Executive Summary

**24 files analyzed. 1 actionable finding (Medium). 6 safe patterns confirmed. No critical or high severity issues.**

The codebase follows secure patterns overall: static site generation, build-time content pipelines, hardcoded configuration, and no runtime user input flowing into dangerous sinks. The single actionable finding relates to the markdown rendering pipeline which permits raw HTML through `dangerouslySetInnerHTML`.

---

## Per-File Analysis

### 1. `web/src/components/docs/doc-renderer.tsx`
- **Line 22:** `allowDangerousHtml: true` — enables raw HTML passthrough in remark-rehype
- **Line 23:** `rehypeRaw` — parses raw HTML within markdown
- **Line 87:** `dangerouslySetInnerHTML={{ __html: html }}`
- **Issue:** Build-time/Stored XSS risk via markdown content pipeline
- **Severity:** ⚠️ **Medium**
- **Details:** The markdown-to-HTML pipeline explicitly allows raw HTML (`allowDangerousHtml: true` + `rehypeRaw`), and the result is rendered via `dangerouslySetInnerHTML`. While the data source is build-time static JSON (`docs.json`), a malicious markdown document containing `<script>` tags or event handlers could execute client-side JavaScript if committed to the repository or if the generation pipeline is compromised.
- **Recommendation:** Add `rehype-sanitize` to the unified pipeline, or remove `rehypeRaw` + set `allowDangerousHtml: false` if raw HTML is not required.

### 2. `web/src/app/[locale]/layout.tsx`
- **Lines 41–48:** `<script dangerouslySetInnerHTML={{ __html: \`...\` }} />`
- **Severity:** ℹ️ **Info** (Safe Pattern)
- **Details:** Hardcoded inline script for dark mode FOUC prevention. No interpolated variables or user input. Standard Next.js pattern.

- **Line 22:** `metaMessages[locale] || metaMessages.en` — dynamic property access with route param
- **Severity:** ℹ️ **Info** (Safe Pattern)
- **Details:** Falls back to `en` for unknown locales. No code execution path from unexpected keys.

### 3. `web/src/hooks/useDarkMode.ts`
- **No issues found.** Pure React hook using MutationObserver on document class.

### 4. `web/src/hooks/useSimulator.ts`
- **No issues found.** Pure state management hook with timer logic.

### 5. `web/src/hooks/useSteppedVisualization.ts`
- **No issues found.** Pure state management hook with interval auto-play.

### 6. `web/src/components/layout/header.tsx`
- **Line 45:** `window.location.href = newPath`
- **Severity:** ℹ️ **Info** (Safe Pattern)
- **Details:** `newPath` constructed from `pathname.replace()` with hardcoded locale values from `LOCALES` array (`["en", "zh", "ja"]`). Not an open redirect — locale source is a hardcoded allowlist, and pathname is from Next.js router (same-origin).

### 7. `web/src/components/layout/sidebar.tsx`
- **No issues found.** Static navigation component.

### 8. `web/src/lib/constants.ts`
- **No issues found.** Static data definitions only.

### 9. `web/src/lib/i18n.tsx`
- **Lines 28–30:** `(messages as any)[namespace]` / `(ns as any)[key]`
- **Severity:** ℹ️ **Info** (Code Quality, not Security)
- **Details:** Read-only access on statically imported JSON. No prototype pollution risk — `namespace` and `key` are developer-provided string literals, not user input.

### 10. `web/src/lib/i18n-server.ts`
- **No issues found.** Same safe translation lookup pattern as i18n.tsx.

### 11. `web/src/lib/utils.ts`
- **No issues found.** Simple `cn()` className utility (3 lines).

### 12. `web/src/types/agent-data.ts`
- **No issues found.** TypeScript type/interface definitions only.

### 13. `web/src/data/execution-flows.ts`
- **No issues found.** Static flow chart data (FlowNode/FlowEdge objects).

### 14. `web/src/app/page.tsx`
- **No issues found.** Simple `redirect("/en/")` call.

### 15. `web/src/app/[locale]/page.tsx`
- **No issues found.** Standard homepage component with static data rendering.

### 16. `web/src/app/[locale]/(learn)/layout.tsx`
- **No issues found.** Simple layout wrapper (Sidebar + children).

### 17. `web/src/app/[locale]/(learn)/[version]/page.tsx`
- **No issues found.** Server component with static params generation.

### 18. `web/src/app/[locale]/(learn)/[version]/client.tsx`
- **No issues found.** Client component for tabbed content display.

### 19. `web/src/app/[locale]/(learn)/[version]/diff/page.tsx`
- **No issues found.** Simple diff page wrapper.

### 20. `web/src/app/[locale]/(learn)/[version]/diff/diff-content.tsx`
- **No issues found.** Diff visualization with static version data.

### 21. `web/src/app/[locale]/(learn)/layers/page.tsx`
- **No issues found.** Layers overview page with static data.

### 22. `web/src/app/[locale]/(learn)/timeline/page.tsx`
- **No issues found.** Timeline page wrapper.

### 23. `web/src/app/[locale]/(learn)/compare/page.tsx`
- **No issues found.** Version comparison page using hardcoded LEARNING_PATH options.

### 24. `web/scripts/extract-content.ts`
- **Line 88:** `toolPattern.exec(source)` — `RegExp.prototype.exec()`, NOT `child_process.exec()`
- **Severity:** ℹ️ **Info** (False Positive)

- **Lines 258–266:** `fs.mkdirSync()`, `fs.writeFileSync()` — build-time file writes
- **Severity:** ℹ️ **Info** (Safe Pattern)
- **Details:** Build-time content extraction script. All paths derived from `__dirname`. No user input influences paths or content.

---

## Security Category Coverage (10/10)

| # | Category | Result |
|---|----------|--------|
| 1 | Code Injection (`eval`, `new Function`, `document.write`) | ✅ **None found** |
| 2 | External Data Exfiltration (`fetch`, `axios`, `XMLHttpRequest`) | ✅ **None found** |
| 3 | Crypto Mining (WebSocket, mining pools) | ✅ **None found** |
| 4 | Shell Command Execution (`child_process`, `exec`, `spawn`) | ✅ **None found** (Finding 3 = RegExp.exec) |
| 5 | Suspicious File System Access | ✅ **Safe** (build-time only, Finding 4) |
| 6 | Base64 Encoded Strings | ✅ **None found** |
| 7 | Obfuscated Code | ✅ **None found** |
| 8 | Backdoors / Reverse Shells | ✅ **None found** |
| 9 | XSS Vulnerabilities | ⚠️ **1 Medium** (Finding 1: `dangerouslySetInnerHTML` + `rehypeRaw`) |
| 10 | Prototype Pollution | ✅ **None found** |

---

## Recommendations Summary

| Priority | Recommendation | File |
|----------|---------------|------|
| **Medium** | Add `rehype-sanitize` to markdown pipeline or disable `allowDangerousHtml`/`rehypeRaw` | `doc-renderer.tsx` |
| **Low** | Consider CSP headers with nonce/hash for inline scripts | `layout.tsx` |
| **Low** | Type `locale` param with explicit union type for early validation | `layout.tsx` |
| **Low** | Replace `as any` casts with typed key lookups | `i18n.tsx` |
| **Low** | Consider `router.push()` instead of `window.location.href` for SPA navigation | `header.tsx` |

---

## Overall Assessment

**Security Posture: Secure** — The application's SSG architecture significantly reduces attack surface. The single medium finding is a defense-in-depth concern (build-time content trust), not an actively exploitable runtime vulnerability.

## Sub-agent Logs

- `security-review-gemini.md` — Gemini 3 Pro (Defense-in-Depth Analyst): Completed. All 7 findings classified as Safe/Info.
- `security-review-gpt.md` — GPT-5.3-Codex (Secure Architecture Reviewer): Completed. 1 Medium finding (doc-renderer.tsx), 6 safe patterns.
- `security-review-opus` — Claude Opus 4.6 (Offensive Security Auditor): Timed out (agent hung >30 min). Report not available.
