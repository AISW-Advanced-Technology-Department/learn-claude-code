# Security Audit Report: Learn Claude Code

**Date:** 2026-03-19
**Target:** Learn Claude Code (Next.js Static Export)
**Auditor:** Offensive Security Specialist

## 1. Executive Summary

The application is a low-risk static documentation site. However, the use of `dangerouslySetInnerHTML` combined with `rehype-raw` in the documentation renderer presents a significant **Stored XSS** vulnerability if the source markdown files are not strictly controlled. An attacker who can contribute to the repository (via Pull Request) can inject arbitrary JavaScript that executes on the domain.

Other findings related to build scripts and locale handling are largely false positives or low-risk maintenance issues due to the static nature of the deployment.

---

## 2. Analysis of Reported Findings

### Finding 1: `dangerouslySetInnerHTML` in `doc-renderer.tsx`
*   **Exploitable:** **YES**
*   **Attack Scenario:** An attacker submits a Pull Request adding a documentation file (or modifying an existing one) with the following content: `<img src=x onerror=alert(document.domain)>`. Because `rehype-raw` is used with `allowDangerousHtml: true` and no sanitization schema is applied, the HTML is rendered as-is. When a victim views the deployment preview or the production site, the script executes.
*   **Severity:** **High** (Context-dependent: Critical if repo is public open-source; Medium if internal trusted team only).
*   **Recommendation:** Implement `rehype-sanitize` immediately after `rehype-raw`. Define a strict schema that allows only necessary tags (e.g., `b`, `i`, `code`, `pre`) and attributes, stripping all event handlers and script tags.

### Finding 2: `dangerouslySetInnerHTML` in `layout.tsx` (Dark Mode Script)
*   **Exploitable:** **NO**
*   **Attack Scenario:** The script reads `localStorage.getItem('theme')` and adds a CSS class. It does not output the value to the DOM or use it in a sink like `eval()`. Even if an attacker controls `localStorage` (which requires a separate XSS), they cannot escalate privileges via this script.
*   **Severity:** **Info**
*   **Recommendation:** No immediate fix required. For cleaner code, consider moving this logic to a `ThemeProvider` component or using a library like `next-themes`.

### Finding 3: `RegExp.exec` in `extract-content.ts`
*   **Exploitable:** **NO**
*   **Attack Scenario:** This script runs only at **build time**. A ReDoS attack here would only delay the build process (CI/CD), acting as a denial of service against the developer, not the end-user. Additionally, the regex `/"name"\s*:\s*"(\w+)"/g` is simple and unlikely to be vulnerable to catastrophic backtracking.
*   **Severity:** **Info**
*   **Recommendation:** Use a proper JSON parser (`JSON.parse`) instead of regex to robustly extract data from files.

### Finding 4: `fs` operations in `extract-content.ts`
*   **Exploitable:** **NO**
*   **Attack Scenario:** The script reads files relative to `__dirname`. Path traversal would require the attacker to control the filenames returned by `fs.readdirSync`. Since these filenames come from the repository structure itself, an attacker would need to commit a malicious filename or symlink. This is a build-time concern, not a runtime vulnerability.
*   **Severity:** **Info**
*   **Recommendation:** Ensure the CI pipeline validates that no symlinks exist in the repository to prevent arbitrary file reads during the build process.

### Finding 5: `window.location.href` in `header.tsx`
*   **Exploitable:** **NO**
*   **Attack Scenario:** The `pathname` variable comes from Next.js `usePathname()` which returns a safe path (e.g., `/en/docs`). The `locale` is from a controlled context. The replacement operation `pathname.replace(...)` cannot be manipulated to produce an external URL (Open Redirect) because `usePathname` does not return the protocol/host.
*   **Severity:** **Info**
*   **Recommendation:** Use Next.js `router.push()` or `<Link>` components for client-side navigation to improve performance, rather than forcing a full page reload with `window.location`.

### Finding 6: `as any` type coercion in `i18n.tsx`
*   **Exploitable:** **NO**
*   **Attack Scenario:** This is a TypeScript build-time suppression. It may lead to runtime errors (crashes) if the translation keys are missing, but it does not introduce a security vulnerability like XSS or injection.
*   **Severity:** **Info**
*   **Recommendation:** Define proper interfaces for the translation JSON structure to ensure type safety.

### Finding 7: Dynamic property access `metaMessages[locale]` in `layout.tsx`
*   **Exploitable:** **NO**
*   **Attack Scenario:** The `locale` variable comes from `params.locale`. In a static export (`output: "export"`), `params` are generated at build time by `generateStaticParams`, which strictly defines the allowed locales (`['en', 'zh', 'ja']`). It is impossible for an arbitrary string to reach this code path in production.
*   **Severity:** **Info**
*   **Recommendation:** None. The static generation guarantees input validity.

---

## 3. Missed Vulnerabilities & Additional Risks

### 1. Reverse Tabnabbing (Medium Severity)
The `doc-renderer.tsx` configuration uses `remark-gfm` but does not explicitly mention `rehype-external-links` or similar plugins.
*   **Risk:** External links in markdown (e.g., `[Link](https://malicious.com)`) typically render as `<a href="...">`. If they open in a new tab (`target="_blank"`) without `rel="noopener noreferrer"`, the target site can control the parent window via `window.opener.location = ...`.
*   **Recommendation:** Add `rehype-external-links` to the unified pipeline with configuration `{ target: '_blank', rel: ['noopener', 'noreferrer'] }`.

### 2. Lack of Content Security Policy (CSP) (High Severity)
There is no evidence of CSP headers in `next.config.ts` or `vercel.json`.
*   **Risk:** Without a CSP, the impact of the XSS vulnerability in Finding #1 is maximized. An attacker can load external scripts, exfiltrate data, or frame the site.
*   **Recommendation:** Configure a strict CSP (e.g., `default-src 'self'; script-src 'self' 'unsafe-inline';`) in `vercel.json` headers. Since it's a static site, this is the primary line of defense.

### 3. Supply Chain Risk (Medium Severity)
The project relies on a complex chain of text processing libraries (`unified`, `remark`, `rehype`).
*   **Risk:** Vulnerabilities in these parsers (e.g., prototype pollution in how they handle ASTs) could lead to XSS.
*   **Recommendation:** Regularly audit dependencies with `npm audit` and pin versions.

### 4. Clickjacking (Low Severity)
No `X-Frame-Options` or CSP `frame-ancestors` headers are configured.
*   **Risk:** The site could be framed by a malicious site to trick users (e.g., into clicking "Copy Code" buttons that actually trigger hidden actions).
*   **Recommendation:** Add `X-Frame-Options: DENY` or `frame-ancestors 'none'` to the response headers.

## 4. Conclusion

The application is generally secure due to its static architecture. The **Critical** finding is the unsafe usage of `rehype-raw` in `doc-renderer.tsx`, which allows Stored XSS via markdown files. Fixing this by adding `rehype-sanitize` and implementing a Content Security Policy (CSP) will address the most significant risks.
