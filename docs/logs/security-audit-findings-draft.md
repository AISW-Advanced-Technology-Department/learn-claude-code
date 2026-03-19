- **File**: web/package.json
- **Line(s)**: 1–38
- **Severity**: Critical
- **Issue**: Node.js version mismatch — System Node.js is v12.22.9, but 30 resolved packages in the lockfile require Node.js >= 18. Node.js 12 reached End-of-Life in April 2022 and no longer receives security patches. The project cannot be built or run securely on the current system; all dependency resolution, compilation, and runtime execution are affected.
- **Recommendation**: Upgrade the system Node.js to a current LTS release (v20 or v22). Until upgraded, the project is effectively unbuildable and exposed to all unfixed vulnerabilities in the Node.js 12 runtime.

---

- **File**: web/package.json
- **Line(s)**: 1–38
- **Severity**: Medium
- **Issue**: Missing `.nvmrc` or `.node-version` file — No Node.js version pinning file exists in the project. CI/CD pipelines and other developers may use incompatible Node.js versions, leading to inconsistent builds, silent failures, or security regressions.
- **Recommendation**: Add a `.nvmrc` or `.node-version` file at the project root specifying the minimum required Node.js version (e.g., `20`). Configure CI/CD to read this file and fail early on version mismatch.

---

- **File**: web/package.json
- **Line(s)**: 26
- **Severity**: Medium
- **Issue**: `tsx` is listed in production `dependencies` but is only used as a build-time tool — It is invoked via the `predev` (line 7) and `prebuild` (line 9) scripts to run `scripts/extract-content.ts`. When deploying with `npm install --production`, `tsx` and all its transitive dependencies (including `esbuild`, which executes install scripts to download platform-specific binaries) would be unnecessarily installed, increasing the attack surface.
- **Recommendation**: Move `tsx` from `dependencies` to `devDependencies`. Verify that `predev` and `prebuild` scripts are not executed in production deployment contexts, or adjust the build pipeline so the extraction step runs before the production install.

---

- **File**: web/package.json
- **Line(s)**: 21
- **Severity**: Medium
- **Issue**: `rehype-raw` allows raw HTML passthrough in the markdown processing pipeline — If any user-supplied or untrusted content flows through the unified/remark/rehype pipeline, raw HTML will be passed through unsanitized, enabling Cross-Site Scripting (XSS) attacks. This is an application-level risk rather than a package vulnerability per se.
- **Recommendation**: Audit the data flow into the markdown pipeline to confirm only trusted content is processed. If untrusted input is possible, add `rehype-sanitize` after `rehype-raw` in the pipeline to strip dangerous HTML elements and attributes.

---

- **File**: web/package.json
- **Line(s)**: 30, 32–36
- **Severity**: Low
- **Issue**: Broad major-version ranges in `devDependencies` — Ranges such as `^4`, `^5`, `^19`, and `^20` allow any minor or patch release within the major version. While the lockfile pins exact versions (e.g., `tailwindcss` → 4.1.18, `typescript` → 5.9.3), a fresh `npm install` without a lockfile (or after deleting `node_modules` and `package-lock.json`) could pull in untested versions with regressions or vulnerabilities.
- **Recommendation**: Tighten version ranges to include at least a minor version (e.g., `^4.1`, `^5.9`, `^20.19`). This preserves patch-level flexibility while reducing the window for unexpected breaking changes.

---

- **File**: web/package.json
- **Line(s)**: 1–38
- **Severity**: Low
- **Issue**: Install scripts present in transitive dependencies — `esbuild@0.27.3` has an install script that downloads platform-specific native binaries at install time. `fsevents@2.3.3` (optional, macOS only) and `sharp@0.34.5` (optional) also have install scripts. Install scripts are the primary vector for npm supply chain attacks, as they execute arbitrary code during `npm install` with the privileges of the installing user.
- **Recommendation**: Monitor these packages for supply chain compromise. Consider using `--ignore-scripts` during CI installs and running scripts explicitly for trusted packages, or adopt `npm config set ignore-scripts true` with an allowlist. Regularly review transitive dependency updates that introduce new install scripts.

---

- **File**: web/package.json
- **Line(s)**: 1–38
- **Severity**: Info
- **Issue**: `npm audit` cannot run on the current system — The installed Node.js v12.22.9 ships with npm v6, which lacks support for modern `npm audit` features and lockfile v3 format. Standard vulnerability scanning workflows (`npm audit`, `npm audit fix`) are blocked, preventing automated detection of known CVEs in the dependency tree.
- **Recommendation**: Upgrade Node.js to v18+ (see Finding 1). As an interim measure, use a containerized or CI-based environment with a modern Node.js version to run `npm audit` and review the output.

---

- **File**: web/package.json
- **Line(s)**: 1–38
- **Severity**: Info
- **Issue**: Positive security observations — The project demonstrates several supply chain security best practices: `"private": true` (line 4) prevents accidental publication to npm; all 236 resolved packages are sourced exclusively from `registry.npmjs.org` with no third-party registries; all packages have SHA-512 integrity hashes ensuring tamper detection; `react`, `react-dom`, and `next` are version-pinned (lines 17–19) reducing drift risk; no deprecated packages were found; and no typosquatting indicators were detected in the dependency tree.
- **Recommendation**: No action required. Continue maintaining these practices. Consider adopting a package provenance policy (npm `--expect-signatures`) as the ecosystem matures.
