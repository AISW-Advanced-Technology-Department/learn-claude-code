# NPM Dependency Security Review

**Date**: 2026-03-19T02:36:07Z
**Target**: `web/package.json`
**Scope**: Supply chain security, dependency hygiene, version pinning
**Reviewers**: claude-opus-4.6 (Supply Chain Security Auditor), gpt-5.3-codex (Dependency Risk Analyst)

---

## Findings

### Finding 1 — Node.js Version Incompatibility

- **File**: web/package.json
- **Line(s)**: 1–38 (entire manifest)
- **Severity**: Critical
- **Issue**: System runs Node.js v12.22.9 (EOL April 2022, no security patches). `next@16.1.6` requires `node >=20.9.0`, and 30 resolved packages require `>=18`. The project cannot be correctly installed, built, or run. Additionally, `npm audit` is blocked because npm v6 (bundled with Node 12) cannot parse lockfile v3.
- **Recommendation**: Upgrade to Node.js 20 LTS or 22 LTS. Add `.nvmrc` with `20` (or `22`) to the project root.

---

### Finding 2 — Missing `engines` Constraint

- **File**: web/package.json
- **Line(s)**: 1–4
- **Severity**: High
- **Issue**: No `engines` field declares the required Node.js version. npm will silently attempt installation on incompatible runtimes (like the current v12), leading to broken builds or subtle runtime failures rather than a clear error.
- **Recommendation**: Add `"engines": { "node": ">=20.9.0" }` to match Next.js 16's requirement. Set `engine-strict=true` in `.npmrc`.

---

### Finding 3 — `tsx` in Production Dependencies

- **File**: web/package.json
- **Line(s)**: 26
- **Severity**: Medium
- **Issue**: `tsx` is a TypeScript execution tool used only in `predev`/`prebuild` scripts (lines 7, 9), but is listed in `dependencies` instead of `devDependencies`. In production deploys with `npm install --omit=dev`, this unnecessarily installs `tsx` and its transitive dependency `esbuild` (which executes install scripts to download platform-specific binaries), expanding the runtime attack surface.
- **Recommendation**: Move `tsx` to `devDependencies`. Ensure the content extraction step runs during the build stage, not in the production container.

---

### Finding 4 — `rehype-raw` Without Sanitization (XSS Vector)

- **File**: web/package.json (line 21) / web/src/components/docs/doc-renderer.tsx (lines 22–23, 87)
- **Line(s)**: 21 (package.json), 22–23 & 87 (doc-renderer.tsx)
- **Severity**: Medium
- **Issue**: The markdown rendering pipeline uses `remarkRehype` with `allowDangerousHtml: true` and `rehypeRaw` to pass raw HTML through, then renders it via `dangerouslySetInnerHTML`. No `rehype-sanitize` step exists. Currently the content source is repo-controlled (`docs.json` generated at build time), but if the content source ever changes to accept user input, this becomes a direct XSS vulnerability.
- **Recommendation**: Add `rehype-sanitize` (with a strict schema) after `rehypeRaw` in the unified pipeline as defense-in-depth. Document that only trusted content should flow through this pipeline.

---

### Finding 5 — `lucide-react` Pre-1.0 Caret Range

- **File**: web/package.json
- **Line(s)**: 16
- **Severity**: Low
- **Issue**: `lucide-react` is declared as `^0.564.0`. Under npm semver rules, `^0.564.0` resolves to `>=0.564.0 <0.565.0` (patch updates only), which is relatively tight. However, the package is pre-1.0 and uses a rapidly incrementing minor version scheme, so even patch releases could introduce unexpected changes. The lockfile mitigates this for normal installs.
- **Recommendation**: Consider pinning to exact version (`"0.564.0"`) for maximum reproducibility. Low urgency since the effective range is narrow.

---

### Finding 6 — Broad Major-Only Version Ranges in devDependencies

- **File**: web/package.json
- **Line(s)**: 30 (`@tailwindcss/postcss: "^4"`), 35 (`tailwindcss: "^4"`), 36 (`typescript: "^5"`)
- **Severity**: Low
- **Issue**: Broad `^N` ranges (without minor version) allow any minor/patch within the major. While the lockfile pins exact versions, fresh installs without a lockfile could resolve to untested releases. In a supply chain compromise scenario, a malicious minor release would be auto-accepted.
- **Recommendation**: Tighten to `^4.1`, `^5.9`, etc. Use Renovate or Dependabot with approval gates for controlled updates.

---

### Finding 7 — Install Scripts in Transitive Dependencies

- **File**: web/package.json (transitive)
- **Line(s)**: 13–37
- **Severity**: Low
- **Issue**: Three transitive packages execute install scripts: `esbuild@0.27.3` (downloads platform-specific native binary), `fsevents@2.3.3` (optional, macOS-only), `sharp@0.34.5` (optional, image processing). All are well-known, high-download packages from trusted publishers. Install scripts are the #1 vector for npm supply chain attacks but these specific packages are legitimate.
- **Recommendation**: In CI, consider `npm ci --ignore-scripts` with explicit post-install execution. Monitor these packages. Use `@tailwindcss/oxide-wasm32-wasi` bundled deps awareness in auditing.

---

### Finding 8 — No Security Tooling in Scripts

- **File**: web/package.json
- **Line(s)**: 5–12
- **Severity**: Info
- **Issue**: No `npm audit`, SBOM generation, license compliance, or provenance verification scripts are present. Vulnerability detection is ad-hoc. Additionally, `npm audit` cannot run on the current Node 12 system.
- **Recommendation**: Add CI-integrated security gates: `npm audit --omit=dev`, or use `osv-scanner` / `snyk` for vulnerability scanning. Enable Dependabot or Renovate for automated dependency update PRs.

---

### Finding 9 — Positive Security Observations

- **File**: web/package.json
- **Line(s)**: 4, 17–19
- **Severity**: Info
- **Issue**: Several good practices are in place: `"private": true` (line 4) prevents accidental npm publication; core framework packages (`next`, `react`, `react-dom`) are version-pinned (lines 17–19); all 236 resolved packages use `registry.npmjs.org` exclusively with SHA-512 integrity hashes; lockfileVersion 3 is committed; no deprecated packages or typosquatting indicators detected.
- **Recommendation**: Continue these practices. Consider enabling npm package provenance verification as ecosystem adoption grows.

---

## Summary

| Severity | Count | Key Issues |
|----------|-------|------------|
| Critical | 1 | Node.js v12 EOL, incompatible with deps |
| High | 1 | Missing `engines` constraint |
| Medium | 2 | tsx placement, rehype-raw XSS |
| Low | 3 | lucide-react 0.x range, broad dev ranges, install scripts |
| Info | 2 | Missing security tooling, positive observations |

**Priority actions**: (1) Upgrade Node.js to ≥20 LTS, (2) Add `engines` field, (3) Move `tsx` to devDependencies, (4) Add `rehype-sanitize` to the rendering pipeline.
