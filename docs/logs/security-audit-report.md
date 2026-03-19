# Security Audit Report — learn.shareai.run

**Application**: Learn Claude Code (Next.js Static Export)  
**Audit Date**: 2026-03-19  
**Auditor**: Senior Offensive Security Auditor (Automated)  
**Scope**: Full client-side codebase + build tooling  
**Framework**: Next.js 16.1.6, React 19.2.3, Static Export  

---

## Executive Summary

This assessment reviewed a fully static Next.js export deployed on Vercel, with no runtime server-side execution, no API routes, no backend database connectivity, and no direct user input forms.

The architectural posture materially reduces classical web exploitation pathways such as SQL injection, server-side template injection, command injection, SSRF, and authentication/session compromise scenarios.

The assessed attack surface is concentrated in client-side rendering, static asset integrity, deployment configuration, and content trust boundaries in the build pipeline.

The seven flagged items were analyzed with full data-flow tracing and exploitability modeling specific to static export constraints.

Of the seven findings, none constitute an immediately exploitable critical or high-severity vulnerability under current trust assumptions.

Finding 1 (`dangerouslySetInnerHTML` fed by markdown content parsed with `allowDangerousHtml: true` and `rehypeRaw`) is the most security-relevant item.

However, it is presently bounded by a trusted-content model: markdown is sourced from repository-controlled files at build time and not from runtime user input.

As implemented, Finding 1 should be treated as a **conditional risk** rather than an active internet-facing vulnerability.

The remaining findings are predominantly safe patterns or implementation details that scanners often over-classify when contextual controls are not considered.

The largest actionable risk in the current deployment is **absence of security headers**, especially a Content Security Policy (CSP).

Without CSP, any future HTML/content injection bug introduced through code changes, dependency behavior changes, or supply-chain content poisoning would have higher blast radius in the browser.

The lack of additional baseline headers (e.g., `X-Content-Type-Options`, `Referrer-Policy`, clickjacking protections via `frame-ancestors` or `X-Frame-Options`, `Permissions-Policy`) is a notable hardening gap.

External links already use `rel="noopener"`, which meaningfully mitigates reverse-tabnabbing; adding `noreferrer` would further reduce referral-data leakage to third-party destinations.

The dependency posture appears typical for a modern frontend project, but no evidence was provided that systematic dependency vulnerability management is enforced as part of CI.

Overall risk posture is **Low**, with a **Low-to-Medium hardening priority** driven by preventative controls rather than detected active exploitation paths.

If repository content trust is weakened (e.g., unreviewed external content ingestion), risk associated with the markdown rendering pipeline would escalate rapidly and should be reclassified.

## Methodology

The audit used static-analysis-first methodology with threat modeling adapted for a static-export deployment model.

Analysis inputs included source snippets, explicit scan findings, framework/runtime constraints, and deployment configuration details.

No assumptions were made about hidden backend behavior because the deployment is explicitly static and serverless at runtime for application logic.

Each finding was evaluated with the following steps:

1. Source/sink identification (data origin, transformations, and final security-sensitive sink).

2. Trust-boundary mapping (developer-controlled vs attacker-controlled data paths).

3. Runtime reachability assessment under static-export constraints.

4. Exploitability scoring under CVSS v3.1 semantics adjusted for practical preconditions.

5. Defense-in-depth recommendation mapping, including controls that reduce future regression impact.

This report intentionally avoids generic false positives that assume runtime input channels not present in the examined architecture.

Where a finding is currently safe but fragile under future changes, the report explicitly marks it as a conditional or trust-dependent pattern.

## Finding Analysis

### Finding 1: dangerouslySetInnerHTML in doc-renderer.tsx

- **Classification**: CONDITIONAL RISK (Trust-Boundary Dependent)
- **Severity**: Medium
- **CVSS v3.1 Score**: 4.8 (AV:N/AC:L/PR:H/UI:R/S:C/C:L/I:L/A:N)
- **Technical Analysis**:
  - Security sink: React `dangerouslySetInnerHTML` writes parser output directly into DOM.
  - Primary source: `docsData` statically imported from generated `docs.json`.
  - Upstream generation: markdown from repository `docs/` is transformed at build time via unified pipeline.
  - Transformation chain: `remarkParse` → `remarkGfm` → `remarkRehype({ allowDangerousHtml: true })` → `rehypeRaw` → `rehypeHighlight` → `rehypeStringify`.
  - `allowDangerousHtml: true` + `rehypeRaw` permits raw HTML in markdown to survive parsing and be emitted in final HTML.
  - At runtime, no user-controlled input feeds this pipeline; content is prebuilt static JSON.
  - Because site is static export, there is no runtime endpoint for attacker-submitted markdown.
  - Exploit precondition therefore shifts from remote anonymous attacker to content-supply attacker (e.g., malicious commit, compromised CI, compromised content source).
  - If a malicious `<script>` or event-handler-bearing HTML is introduced into trusted markdown and merged/deployed, client-side script execution could occur in users’ browsers.
  - Impact domain under such a compromise includes DOM integrity, potential credential phishing UI overlays, and data exfiltration of any browser-accessible tokens.
  - Current app stores only theme preference in localStorage, so immediate data-theft blast radius is limited today.
  - Nevertheless, trust-boundary violations here are historically high leverage because they become latent XSS primitives for future feature additions.
  - The post-processing step performs regex string rewrites; it does not sanitize HTML and should not be considered a security control.
  - From an offensive perspective, exploitation would require compromised maintainer account, CI token, poisoned dependency, or malicious accepted contribution. If such compromise occurs, payload execution could be immediate and persistent across all page visitors until rollback.
  - Conclusion: Not directly exploitable by internet users under current architecture, but structurally risky if content trust assumptions change.
- **Recommendations**:
  - Preferred: remove raw HTML support by setting `allowDangerousHtml: false` and removing `rehypeRaw` unless raw HTML is a strict product requirement.
  - If raw HTML must remain, enforce sanitization with `rehype-sanitize` using an explicit schema that permits only required tags/attributes.
  - Forbid script-capable attributes (`on*`), `javascript:` URLs, and dangerous SVG/MathML nodes unless explicitly required.
  - Add content governance controls: CODEOWNERS for docs content, mandatory reviewer approval, and signed commits for sensitive branches.
  - Integrate automated content security linting in CI to reject high-risk HTML patterns in markdown and generated JSON artifacts.
  - Add strict CSP with nonce/hash strategy to constrain script execution if malicious HTML slips through.
  - Create a regression test suite with representative malicious markdown payloads and assert rendered output is neutralized.
  - Document the trust model in `SECURITY_AUDIT.md` or equivalent so future maintainers understand why this is safe only under controlled content ingestion.

### Finding 2: dangerouslySetInnerHTML in layout.tsx

- **Classification**: SAFE PATTERN
- **Severity**: Info
- **CVSS v3.1 Score**: 0.0 (N/A — Hardcoded Static Inline Script, No Injection Vector)
- **Technical Analysis**:
  - Security sink: inline `<script>` created with `dangerouslySetInnerHTML` in layout.
  - Script body is hardcoded template literal with zero variable interpolation.
  - No attacker-controlled input, route parameter, query parameter, or storage value is injected into script source code.
  - Logic only reads `localStorage.getItem("theme")` and toggles `document.documentElement.classList` accordingly.
  - Values checked are strict string comparisons against known constants (`dark`) and media query fallback.
  - No dynamic script construction (`eval`, `Function`) is present.
  - Therefore this usage is not an XSS sink in its current form.
  - Primary security tradeoff is operational: inline scripts complicate adoption of strict CSP without `unsafe-inline` or script hashes/nonces.
  - Because this script is deterministic, hash-based CSP allowance is feasible and preferred over broad `unsafe-inline`.
  - Conclusion: Safe implementation, but should be optimized for CSP compatibility.
- **Recommendations**:
  - Retain functionality but move to CSP-friendly model: precompute a `sha256-...` script hash and include it in `Content-Security-Policy`.
  - Alternative: externalize boot script to static file and allow only self-hosted script sources under CSP.
  - Keep script minimal and deterministic; prohibit future interpolation in this block through lint rule or code review checklist.
  - Add a security unit test/snapshot ensuring script body remains static and free of dynamic placeholders.

### Finding 3: RegExp.exec in extract-content.ts

- **Classification**: SAFE PATTERN
- **Severity**: Info
- **CVSS v3.1 Score**: 0.0 (N/A — Build-Time Regex Iteration, Not Command Execution)
- **Technical Analysis**:
  - The flagged API is JavaScript `RegExp.prototype.exec`, not Node `child_process.exec`.
  - Pattern `"name"\s*:\s*"(\w+)"` is used to iterate matches in source text during build processing.
  - Execution context is offline build script under `web/scripts/`, not browser runtime and not deployment runtime.
  - No shell invocation or process spawning occurs in this snippet.
  - No command injection primitive exists because no command interpreter is involved.
  - Potential concern would be ReDoS if regex were catastrophic and attacker-controlled huge input was accepted at runtime.
  - That concern is inapplicable here due to controlled build-time sources and relatively simple regex.
  - Conclusion: Scanner classification as `exec` risk is a false positive.
- **Recommendations**:
  - Keep variable naming explicit (e.g., `regexMatch`) to reduce scanner/operator confusion with shell `exec`.
  - Optionally annotate with comment clarifying that this is regex iteration, not process execution.
  - Maintain build-source trust controls to avoid maliciously oversized payload files causing CI resource pressure.

### Finding 4: fs operations in extract-content.ts

- **Classification**: SAFE PATTERN
- **Severity**: Info
- **CVSS v3.1 Score**: 0.0 (N/A — Controlled Build-Time File Writes)
- **Technical Analysis**:
  - Operations observed: `fs.mkdirSync` and `fs.writeFileSync` for generated JSON assets.
  - Path derivation uses static joins from `__dirname` and fixed directory segments.
  - No user-provided path fragments are concatenated into output paths.
  - No runtime endpoint exposes these file operations to remote callers.
  - Execution is limited to build pipeline where repository and script code define behavior.
  - Path traversal risk is absent under current constants because attacker cannot influence path resolution through HTTP input.
  - Potential risk category is CI compromise or malicious code commit, which is broader supply-chain risk rather than application runtime vulnerability.
  - Conclusion: No direct vulnerability in current implementation.
- **Recommendations**:
  - Retain strict path construction from immutable constants and avoid future introduction of CLI/path arguments without validation.
  - Use least-privilege CI tokens and immutable build environments to reduce impact of script tampering.
  - Consider integrity checks on generated artifacts (hashing in CI) to detect unexpected build output mutation.

### Finding 5: window.location.href assignment in header.tsx

- **Classification**: SAFE PATTERN
- **Severity**: Info
- **CVSS v3.1 Score**: 0.0 (N/A — Input sourced from hardcoded constant array; no runtime exploit vector)
- **Technical Analysis**:
  - Sink: assignment to `window.location.href`, which can be dangerous if destination is attacker-controlled.
  - In this implementation, `newLocale` is sourced from hardcoded `LOCALES` array (`en`, `zh`, `ja`).
  - Path template uses current `pathname` from Next navigation hook and replaces leading locale segment.
  - No query string parsing or external URL concatenation is used.
  - No untrusted runtime input can set `newLocale` through intended UI path.
  - Because values are fixed locale codes, open redirect to external domains is not feasible via normal execution.
  - Residual technical risk: if future refactor allows arbitrary locale values (e.g., from URL/query/user profile), this sink could become redirect gadget.
  - Residual UX/security tradeoff: full-page navigation instead of router transition may have minor phishing-resilience implications only if route validation regresses.
  - Conclusion: Currently safe with low residual risk contingent on locale source immutability.
- **Recommendations**:
  - Defense-in-depth: validate `newLocale` against a constant allowlist before constructing destination path.
  - Prefer framework navigation (`router.push`) with explicit typed locale union to reduce accidental broadening of accepted values.
  - Normalize path computation to avoid edge-case malformed paths in future route changes.
  - Add unit tests asserting destination always starts with `/(en|zh|ja)/` and never includes protocol delimiters (`://`).

### Finding 6: Type coercion with `as any` in i18n.tsx

- **Classification**: SAFE PATTERN (Type Safety Smell, Not Security Flaw)
- **Severity**: Info
- **CVSS v3.1 Score**: 0.0 (N/A — Compile-Time Type Relaxation Only)
- **Technical Analysis**:
  - Code uses `(messages as any)[namespace]` and `(ns as any)[key]` for translation lookup.
  - Data source is statically imported locale JSON files bundled at build time.
  - Keys are developer-authored literals in component code, not user-controlled strings from requests.
  - Security impact of `as any` is indirect: it may hide typing errors, increasing chance of runtime fallback behavior.
  - No injection sink, code execution path, or privilege boundary crossing is created by this cast.
  - Potential outcome is incorrect or missing translations, not confidentiality/integrity compromise.
  - Conclusion: Not a security vulnerability under current data model.
- **Recommendations**:
  - Improve robustness by replacing `any` with typed dictionaries and constrained key unions.
  - Enable stricter TypeScript options where feasible to detect translation-key drift earlier.
  - Keep fallback behavior (`return key`) but log missing keys in development to catch quality regressions.

### Finding 7: Dynamic property access in layout.tsx

- **Classification**: SAFE PATTERN
- **Severity**: Info
- **CVSS v3.1 Score**: 0.0 (N/A — Constrained Enum-Like Key Access)
- **Technical Analysis**:
  - Expression `metaMessages[locale] || metaMessages.en` accesses static message map by route locale.
  - `locale` route parameter is statically constrained via `generateStaticParams()` to `en`, `zh`, `ja`.
  - With static export, only pre-rendered routes exist; arbitrary locale expansion is not served dynamically by app logic.
  - Fallback to English further reduces potential undefined behavior.
  - No prototype pollution vector is present because object keys are statically imported and route space is bounded.
  - No attacker-controlled object path traversal occurs.
  - Conclusion: Safe dynamic lookup with explicit fallback.
- **Recommendations**:
  - Optionally enforce locale typing (`type Locale = "en" | "zh" | "ja"`) end-to-end for maintainability.
  - Keep fallback behavior and add tests for unsupported locale routing behavior in static artifacts.

## Additional Findings

### A1: Missing Content Security Policy (CSP)

- **Severity**: Medium
- **CVSS v3.1 Score**: 4.7 (AV:N/AC:H/PR:N/UI:R/S:C/C:L/I:L/A:N) — AC:H because exploitability requires a pre-existing injection vulnerability
- **Technical Analysis**:
  - No CSP is configured in `next.config.ts`, `vercel.json`, or static headers artifacts.
  - In a static site, CSP is still one of the most effective browser-enforced mitigations against script execution from injected markup.
  - Given markdown rendering includes raw HTML support in current pipeline, CSP absence increases impact of any future trust-boundary failure.
  - Inline theme script can be accommodated via hash-based CSP without enabling broad `unsafe-inline`.
  - Risk is preventative/hardening-oriented today but materially important for resilience.
- **Recommendations**:
  - Adopt restrictive baseline CSP, e.g. `default-src 'self'; script-src 'self' 'sha256-...'; object-src 'none'; base-uri 'self'; frame-ancestors 'none';`.
  - Set `img-src`/`style-src`/`font-src` explicitly based on actual asset requirements.
  - Avoid wildcard hosts and avoid `unsafe-inline`/`unsafe-eval` unless strictly unavoidable.
  - Automate CSP validation in CI against built static output.

### A2: Missing Baseline Security Headers

- **Severity**: Low
- **CVSS v3.1 Score**: 3.1 (AV:N/AC:H/PR:N/UI:R/S:U/C:L/I:N/A:N) — AC:H because exploitability requires combination with another vulnerability
- **Technical Analysis**:
  - No evidence of `X-Content-Type-Options: nosniff`.
  - No evidence of explicit clickjacking protections (`frame-ancestors` in CSP and/or `X-Frame-Options`).
  - No evidence of `Referrer-Policy` tuning for privacy boundaries.
  - No evidence of `Permissions-Policy` minimization for browser feature exposure.
  - No evidence of explicit HSTS policy management at application/deployment config layer.
  - Individually these are hardening controls; together they provide layered protection and policy clarity.
- **Recommendations**:
  - Configure headers in Vercel (`vercel.json` headers section) or edge middleware equivalent compatible with static deployment.
  - Set `X-Content-Type-Options: nosniff` universally.
  - Set `Referrer-Policy: strict-origin-when-cross-origin` or stricter based on analytics requirements.
  - Use `Permissions-Policy` to disable unused features (camera, microphone, geolocation, etc.).
  - Enforce clickjacking defense via `frame-ancestors 'none'` in CSP; optionally keep `X-Frame-Options: DENY` for legacy coverage.
  - If HTTPS-only on apex/custom domain is guaranteed, enforce HSTS with preload considerations validated operationally.

### A3: External Links Missing `noreferrer`

- **Severity**: Info
- **CVSS v3.1 Score**: 0.0 (N/A — Privacy best practice; `noopener` already mitigates primary risk)
- **Technical Analysis**:
  - Links already use `rel="noopener"`, mitigating reverse-tabnabbing by breaking `window.opener`.
  - Absence of `noreferrer` means destination sites may still receive full referrer URLs depending on browser policy and site-wide referrer policy.
  - This is primarily a privacy/data-minimization concern rather than direct code-execution risk.
- **Recommendations**:
  - Use `rel="noopener noreferrer"` consistently for external links opened in new tabs/windows.
  - Pair with global `Referrer-Policy` to enforce uniform referral behavior.

### A4: Dependency Security Program Not Evidenced

- **Severity**: Low
- **CVSS v3.1 Score**: N/A (Program governance gap, not a directly scorable vulnerability)
- **Technical Analysis**:
  - No direct evidence was provided of recurring dependency scanning, SBOM generation, or CI gate thresholds.
  - Frontend ecosystems are supply-chain intensive; latent vulnerability introduction often occurs through transitive dependencies.
  - Static-export architecture limits some runtime exploit classes but does not eliminate malicious package or compromised build tooling risk.
- **Recommendations**:
  - Enable automated `npm audit`/GitHub Dependabot alerts with triage SLA.
  - Add lockfile integrity and deterministic build enforcement in CI.
  - Generate SBOM (e.g., CycloneDX) per release and retain for incident response.
  - Define severity-based patch windows (Critical: 24-72h, High: <=7d, Medium: <=30d).

## Missing Security Controls

| Control | Status | Security Impact |
|---------|--------|-----------------|
| Content Security Policy (CSP) | Missing | High defensive value for any DOM injection contingency; should be prioritized first. |
| X-Content-Type-Options | Missing | Prevents MIME sniffing ambiguity and reduces certain content-type confusion vectors. |
| Referrer-Policy | Missing/Not evidenced | Improves privacy and limits URL data leakage to third parties. |
| Frame Embedding Control | Missing/Not evidenced | Mitigates clickjacking (`frame-ancestors`/`X-Frame-Options`). |
| Permissions-Policy | Missing/Not evidenced | Reduces browser feature exposure not required by static docs site. |
| HSTS | Not evidenced in app config | Should be explicitly validated at edge/domain level for HTTPS enforcement. |
| Subresource Integrity (SRI) | Not evidenced | Recommended when loading any third-party hosted JS/CSS assets. |
| Trusted Types | Not configured | Can further constrain DOM XSS sinks in modern browsers where compatible. |

### Priority Hardening Roadmap

- P1 (Immediate): Deploy CSP with least-privilege directives and explicit hash for theme inline bootstrap script.
- P1 (Immediate): Add `nosniff`, `Referrer-Policy`, clickjacking defense, and `Permissions-Policy` headers.
- P2 (Near-term): Harden markdown pipeline with sanitization or disable raw HTML parsing.
- P2 (Near-term): Add CI security checks for markdown payload safety and generated artifact inspection.
- P3 (Mid-term): Formalize dependency governance, SBOM lifecycle, and security update SLAs.
- P3 (Mid-term): Add automated regression tests validating locale/version route constraints and navigation safety invariants.

## Dependency Analysis

The application stack (Next.js + React + unified/remark/rehype ecosystem) is modern and widely used, but also transitive-dependency heavy.
No direct evidence was provided of known exploitable CVEs in the current lockfile at audit time, but this does not substitute for active monitoring.
Parser/rendering chains (`remark`, `rehype`) should be treated as high-scrutiny dependencies due to direct influence on HTML generation.
Highlighting libraries and markdown plugins may expand parser attack surface over time when defaults change between releases.
Static export reduces runtime attack vectors but build-time compromise remains a meaningful risk class.
Build-integrity controls (pinning, lockfile verification, provenance validation where possible) are important for this architecture.
Recommended ongoing controls include:

- Continuous dependency scanning in CI and repository security settings.
- Automated PRs for patch/minor updates with mandatory CI + smoke-test execution.
- Manual review for major version upgrades affecting parser/sanitizer behavior.
- Provenance-aware package retrieval and integrity verification where toolchain permits.
- Release note monitoring for security advisories in markdown/rendering toolchain.

## Overall Risk Assessment

**Overall Rating: Low (with Medium hardening urgency for preventive controls).**
The current deployment profile significantly constrains remote exploitability by eliminating backend runtime logic and user-submitted dynamic inputs.
The seven assessed findings are largely non-exploitable in present architecture when strict repository content trust is maintained.
The dominant risk theme is not active vulnerability presence, but **future resilience** against regressions and supply-chain/content-boundary failures.
If trust assumptions weaken (e.g., external content ingestion, permissive contributor workflow, compromised CI), risk associated with HTML rendering path can escalate rapidly.
Implementing CSP + baseline security headers would substantially improve defense-in-depth at low operational cost for a static site.
Accordingly, risk should be revisited after any of the following events:

- Introduction of runtime APIs, forms, query-driven rendering, or user-generated content.
- Changes to markdown ingestion sources beyond repository-controlled files.
- Major upgrades in markdown/HTML processing dependencies.
- Deployment platform policy changes affecting default headers/caching/security behavior.

## Appendix: CVSS Score Summary Table

| Finding | Classification | Severity | CVSS | Vector |
|---------|---------------|----------|------|--------|
| Finding 1 | CONDITIONAL RISK | Medium | 4.8 | AV:N/AC:L/PR:H/UI:R/S:C/C:L/I:L/A:N |
| Finding 2 | SAFE PATTERN | Info | 0.0 | N/A |
| Finding 3 | SAFE PATTERN | Info | 0.0 | N/A |
| Finding 4 | SAFE PATTERN | Info | 0.0 | N/A |
| Finding 5 | SAFE PATTERN | Info | 0.0 | N/A |
| Finding 6 | SAFE PATTERN | Info | 0.0 | N/A |
| Finding 7 | SAFE PATTERN | Info | 0.0 | N/A |
| Additional A1 | MISSING CONTROL | Medium | 4.7 | AV:N/AC:H/PR:N/UI:R/S:C/C:L/I:L/A:N |
| Additional A2 | MISSING CONTROL | Low | 3.1 | AV:N/AC:H/PR:N/UI:R/S:U/C:L/I:N/A:N |
| Additional A3 | HARDENING GAP | Info | 0.0 | N/A |
| Additional A4 | PROGRAM GAP | Low | N/A | N/A |

## Appendix: Detailed Control Implementation Guidance

The following implementation checklist is intentionally detailed to support publication-quality remediation tracking.

### CSP Implementation Blueprint

1. Inventory all script origins used by built output.
2. Inventory all style/font/image origins used by built output.
3. Move inline scripts to external files where practical.
4. For unavoidable inline bootstrap script, compute deterministic SHA-256 hash.
5. Set initial report-only CSP and collect violation telemetry.
6. Tune directives to remove false positives while preserving least privilege.
7. Promote from report-only to enforced mode after validation window.
8. Add CI check that fails build if CSP policy template is accidentally weakened.
9. Document CSP ownership and policy change process.

### Markdown Rendering Hardening

1. Decide business requirement for raw HTML in markdown.
2. If not required, disable `allowDangerousHtml` and remove `rehypeRaw`.
3. If required, introduce `rehype-sanitize` with strict allowlist schema.
4. Explicitly deny script tags, event handler attributes, inline JS URLs, and unknown protocols.
5. Build malicious payload fixture corpus covering HTML, SVG, MathML, URL protocol edge cases.
6. Assert fixture output is sanitized in test pipeline.
7. Gate merges on sanitizer test pass and code-owner review.
8. Version-lock parser/sanitizer dependencies and monitor advisories.

### Deployment Header Baseline

1. Set `X-Content-Type-Options: nosniff` globally.
2. Set `Referrer-Policy` to project-approved strictness level.
3. Set clickjacking protection (`frame-ancestors` and optional `X-Frame-Options`).
4. Set `Permissions-Policy` with deny-by-default stance for unused APIs.
5. Validate HSTS at domain/edge level and document max-age/preload policy.
6. Automate header regression checks using integration tests against deployed preview.
7. Include header checks in release readiness criteria.

### Secure SDLC and Governance

1. Define threat model owners and review cadence.
2. Add CODEOWNERS for markdown/docs and security-sensitive rendering components.
3. Require signed commits or protected branch policies for release branches.
4. Enable dependency alerting and enforce remediation SLAs.
5. Produce SBOM each release and archive artifacts.
6. Run periodic security review when architecture changes.
7. Track security debt items in roadmap with owners and target dates.

## Appendix: Threat Model Notes for Static Export Architecture

- Primary remote attack vectors are DOM-based issues, malicious third-party resources, and browser policy gaps.
- Server-side exploit classes are largely removed by architecture (no runtime API/server rendering path in scope).
- Build pipeline and repository integrity become disproportionately important relative to traditional dynamic applications.
- Content authenticity and review rigor directly influence client-side security when content is transformed into HTML.
- Header policy and browser-enforced controls are critical compensating controls in static deployments.

## Appendix: Residual Risk Register

| ID | Risk Statement | Likelihood | Impact | Residual Rating | Owner |
|----|----------------|------------|--------|-----------------|-------|
| R-01 | Malicious markdown committed to trusted repository introduces client-side scriptable HTML. | Low | Medium | Low-Medium | Engineering + Security |
| R-02 | Absence of CSP allows broader script execution if future injection bug is introduced. | Medium | Medium | Medium | Platform/Frontend |
| R-03 | Missing header baseline exposes avoidable privacy and browser-hardening gaps. | Medium | Low | Low-Medium | Platform |
| R-04 | Dependency vulnerability introduced through transitive updates without timely triage. | Medium | Low-Medium | Low-Medium | Engineering |
| R-05 | Future locale/navigation refactor accidentally broadens redirect destination control. | Low | Low | Low | Frontend |

## Appendix: Verification Checklist (Audit Reproducibility)

1. Verified static export configuration (`output: "export"`) and absence of runtime server execution path in scope statement.
2. Confirmed no reported usage of `eval`, `Function`, `document.write`, `__proto__` in provided scan results.
3. Confirmed no reported network request primitives (`fetch`, `axios`, `XMLHttpRequest`, `WebSocket`) in target source subset.
4. Confirmed no query-string consumption path via `useSearchParams` or equivalent in provided scan results.
5. Confirmed localStorage usage is restricted to theme preference key-value pair.
6. Validated locale and version route constraints are generated from static parameter functions/constants.
7. Validated dangerous HTML rendering path and identified trust assumptions explicitly.
8. Validated existence of inline script and assessed interpolation-free construction.
9. Validated filesystem/script findings are build-time scoped and non-runtime.
10. Validated external link relationship attribute posture and hardening delta (`noreferrer`).
11. Validated absence of explicit security headers and CSP in provided configuration excerpts.

## Appendix: Action Plan with Ownership and SLAs

| Priority | Action | Owner | SLA | Success Criteria |
|----------|--------|-------|-----|------------------|
| P1 | Implement CSP (report-only then enforce) with hash for inline theme script. | Frontend + Platform | 14 days | Policy enforced in production without breaking UX; violation rate near zero. |
| P1 | Add baseline security headers in deployment config. | Platform | 7 days | Headers present on all routes and validated in automated checks. |
| P2 | Harden markdown rendering (`rehype-sanitize` or disable raw HTML). | Frontend | 21 days | Malicious markdown fixture corpus neutralized in CI tests. |
| P2 | Standardize external links to `noopener noreferrer`. | Frontend | 7 days | No external target without complete rel attributes. |
| P3 | Establish dependency governance and SBOM publication. | Engineering Enablement | 30 days | Automated scans, alert triage workflow, release SBOM artifact present. |
| P3 | Replace `as any` translation lookup with typed key-safe accessors. | Frontend | 45 days | Type-safe i18n utility merged with no runtime behavior regressions. |

## Appendix: Control Validation Matrix

| Control Domain | Control Item | Current State | Target State | Validation Method |
|----------------|--------------|---------------|--------------|-------------------|
| Application Security | HTML sanitization in markdown pipeline | Not evidenced / raw HTML allowed | Sanitized allowlist or raw HTML disabled | Unit tests with malicious fixtures + code review |
| Browser Security | Content Security Policy | Missing | Least-privilege enforced | HTTP response header checks + browser console violations |
| Browser Security | Clickjacking protection | Not evidenced | frame-ancestors none | Header validation + frame embedding test |
| Privacy | Referrer minimization | Not evidenced | strict-origin-when-cross-origin or stricter | Automated integration tests |
| Transport Security | HSTS | Not evidenced in app config | Enabled at edge/domain | TLS header scan on production domain |
| Supply Chain | Dependency vulnerability scanning | Not evidenced | Automated in CI | Pipeline logs + policy gates |
| Supply Chain | SBOM generation | Not evidenced | Release artifact required | Release checklist audit |
| SDLC | Security code ownership | Not evidenced | CODEOWNERS enforced | Branch protection policy checks |
| SDLC | Threat model refresh cadence | Ad hoc | Scheduled quarterly | Governance meeting records |

## Appendix: Recommended Test Cases for Security Regression

### TC-01: Markdown XSS Payload Neutralization

- **Related Finding**: Finding 1 (dangerouslySetInnerHTML)
- **Objective**: Verify that malicious HTML/JS payloads in markdown source do not execute in rendered output
- **Procedure**:
  1. Create a test markdown file containing: `<script>alert('xss')</script>`, `<img onerror="alert(1)" src=x>`, `<a href="javascript:alert(1)">click</a>`
  2. Run the build pipeline (`npm run extract && npm run build`)
  3. Inspect the generated `docs.json` and rendered HTML output
  4. Open the rendered page in a browser and verify no script execution occurs
- **Expected Result**: Script tags are stripped or escaped; event handlers are removed; javascript: URLs are neutralized
- **Pass Criteria**: Zero script execution alerts in browser console; no `<script>` tags in final DOM

### TC-02: Locale Switching Redirect Validation

- **Related Finding**: Finding 5 (window.location.href)
- **Objective**: Verify locale switching only produces same-origin relative paths
- **Procedure**:
  1. Navigate to each locale variant (`/en/`, `/zh/`, `/ja/`)
  2. Click each locale switch button and capture the resulting `window.location.href` value
  3. Verify the new path starts with `/(en|zh|ja)/` and contains no protocol delimiter (`://`)
  4. Verify no navigation to external domains occurs
- **Expected Result**: All locale switches produce same-origin relative paths within the known locale set
- **Pass Criteria**: Regex `^/(en|zh|ja)/` matches all resulting paths; no external navigation

### TC-03: CSP Header Enforcement (Post-Implementation)

- **Related Finding**: Additional A1 (Missing CSP)
- **Objective**: Verify CSP headers are present and correctly configured after implementation
- **Procedure**:
  1. Deploy to preview environment
  2. Fetch any HTML page and inspect `Content-Security-Policy` response header
  3. Verify `script-src` does not include `'unsafe-inline'` or `'unsafe-eval'`
  4. Verify inline theme script is allowed via `'sha256-...'` hash
  5. Open browser console and verify zero CSP violations on page load
- **Expected Result**: CSP header present with restrictive policy; no violations during normal operation
- **Pass Criteria**: Header present; no `unsafe-inline`/`unsafe-eval`; zero console violations

### TC-04: Static Route Parameter Boundary

- **Related Finding**: Findings 5, 7 (Route parameter usage)
- **Objective**: Verify that only statically-generated locale and version routes are accessible
- **Procedure**:
  1. Attempt to access invalid locale routes (`/xx/`, `/../../etc/passwd/`, `/<script>/`)
  2. Attempt to access invalid version routes (`/en/v999/`, `/en/../`)
  3. Verify all invalid routes return 404 or redirect to valid fallback
- **Expected Result**: No content served for invalid route parameters; static export boundary enforced
- **Pass Criteria**: HTTP 404 for all invalid route attempts; no content leakage

### TC-05: Security Header Baseline Verification

- **Related Finding**: Additional A2 (Missing Security Headers)
- **Objective**: Verify all baseline security headers are present after implementation
- **Procedure**:
  1. Fetch production URL and inspect response headers
  2. Check for: `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `X-Frame-Options` or CSP `frame-ancestors`, `Permissions-Policy`
  3. Verify `Strict-Transport-Security` header on HTTPS responses
- **Expected Result**: All baseline headers present with appropriate values
- **Pass Criteria**: Each header present and correctly valued per security policy
