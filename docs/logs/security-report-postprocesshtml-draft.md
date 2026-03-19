# Security Analysis Report: postProcessHtml Regex Functions

## Metadata

- **Date:** 2026-03-19
- **Scope:** Security analysis of `postProcessHtml` regex transforms (Regex 1-5) in `doc-renderer.tsx`, including interaction with `renderMarkdown` pipeline and `dangerouslySetInnerHTML` rendering.
- **Methodology:** Static code review, regex behavior analysis, architecture-aware threat modeling, and interpretation of provided empirical test outputs.
- **Threat Model:**
  - Content source: developer-authored Markdown in controlled Git repository.
  - Processing: build-time conversion via unified/remark/rehype with `allowDangerousHtml: true` and `rehypeRaw`; no `rehype-sanitize`.
  - Delivery: static Next.js export (`output: "export"`) with no server runtime.
  - Adversary models considered:
    1. External unauthenticated web user (no content write capability).
    2. Malicious or compromised contributor with repository write/PR-merge capability.
    3. Supply-chain compromise in content ingestion path.

## Regex 1: Language-labeled code blocks

```ts
/<pre><code class="hljs language-(\w+)">/g
→ '<pre class="code-block" data-language="$1"><code class="hljs language-$1">'
```

### FINDING
Regex 1 matches exact `<pre><code class="hljs language-...">` openings and wraps the `<pre>` with `class="code-block"` plus `data-language="$1"`, where `$1` is limited to `\w+` (`[A-Za-z0-9_]`). Empirical results show:
- `language-javascript` captured as `javascript`.
- `language-zzz_unknown` captured as `zzz_unknown`.
- Attempted language-name quote injection is HTML-encoded upstream by rehype (`&#x22;`), preventing attribute break-out.

### REASONING
- **Capture/substitution behavior:** The capture is strongly constrained by `\w+`; characters needed for HTML attribute injection (`"`, `'`, `<`, `>`, whitespace, `=`) cannot be captured.
- **New attack surface vs pass-through:** This regex does **not** pass through arbitrary attribute fragments and does **not** concatenate attacker-controlled raw delimiters into new attribute boundaries. It only copies a sanitized token subset into two attribute values (`data-language` and `class`).
- **Architecture impact:** In this static, controlled-content model, only repository authors can influence Markdown. External users cannot provide runtime input. Even if a malicious contributor attempts language-name injection, the upstream parser/serializer encoding and `\w+` capture constraint block this path.
- **Browser model:** Resulting attributes remain inert metadata/class strings. No event handler attributes, URLs, or script execution sinks are created by this regex.
- **Exploit scenario analysis:**
  - Payload: ```` ```javascript" onmouseover="alert(1) ````
  - Upstream output encodes quote; regex capture truncates to word chars; no handler injection.
  - Execution path fails.

### VERDICT
**FALSE POSITIVE** (for claims that Regex 1 creates XSS).

### SEVERITY
**INFORMATIONAL**

- **CWE:** CWE-116 (contextually relevant as output encoding concern, but no exploitable flaw here).
- **CVSS 3.1:** **0.0** (no security impact attributable to this regex).

## Regex 2: Plain code blocks (ASCII diagrams)

```ts
/<pre><code(?! class="hljs)([^>]*)>/g
→ '<pre class="ascii-diagram"><code$1>'
```

### FINDING
Regex 2 matches `<pre><code...>` blocks not starting with ` class="hljs` immediately after `<code`, captures the remaining attribute text as `([^>]*)`, and reinserts it verbatim (`<code$1>`), while adding `class="ascii-diagram"` to `<pre>`. Empirical tests confirm capture includes dangerous attributes:
- `<pre><code onload="alert(1)">` → capture includes ` onload="alert(1)"`.
- `<pre><code class="evil" onmouseover="alert(1)">` → capture includes ` class="evil" onmouseover="alert(1)"`.

### REASONING
- **Capture/substitution behavior:** `([^>]*)` is broad and preserves all attributes up to `>`, including event handlers.
- **New attack surface vs pass-through:** Critical distinction:
  - This regex **does not create a new injection primitive** (it does not add attacker-controlled attributes that were not already present).
  - It **does preserve** dangerous attributes exactly as already emitted by upstream pipeline.
  - Since `renderMarkdown` uses `allowDangerousHtml: true` + `rehypeRaw` without sanitization, dangerous attributes already survive before post-processing.
- **Architecture impact:**
  - In current model, only trusted contributors can add malicious HTML to Markdown.
  - No public runtime input route exists; exploit requires content-control compromise (malicious maintainer/PR merge/supply-chain compromise).
- **Browser model:** If malicious HTML with executable handlers is present in final static HTML and inserted via `dangerouslySetInnerHTML`, browser executes according to normal DOM event rules. This is a real XSS sink **overall**, but primarily due to unsanitized upstream raw HTML acceptance.
- **Exploit scenario analysis:**
  - Payload in Markdown: `<img src=x onerror=alert(1)>` survives rehype and executes when rendered.
  - For Regex 2-specific payload on `<code>`: handler attributes persist; some handlers on `<code>` may not naturally fire, but the preservation is still unsafe pattern-wise.
  - Regex 2 is a **propagation amplifier**, not root cause.

### VERDICT
**INFORMATIONAL** (Regex 2 itself is not the origin of exploitability, but it preserves unsafe upstream attributes and therefore should be treated as risky hygiene).

### SEVERITY
**LOW** (component-level). If incorrectly attributed as standalone XSS source: overstated.

- **CWE:** CWE-79 (overall pipeline), CWE-20/CWE-116 (insufficient validation/encoding in transformation chain).
- **CVSS 3.1 (Regex-2-only attribution):** **2.7 (AV:N/AC:H/PR:H/UI:R/S:U/C:L/I:L/A:N)** — low practical impact because attacker must already control trusted content path.

## Regex 3: Hero callout blockquote replacement

```ts
/<blockquote>/
→ '<blockquote class="hero-callout">'
```

### FINDING
Regex 3 replaces only the first literal `<blockquote>` occurrence with `<blockquote class="hero-callout">`.

### REASONING
- **Capture/substitution behavior:** No dynamic capture group; purely static string replacement.
- **New attack surface vs pass-through:** Does not process attacker-controlled substrings and does not preserve/introduce dynamic attributes.
- **Architecture impact:** Independent of content trust level, this operation is deterministic markup decoration.
- **Browser model:** Adding a static class has no script execution semantics.
- **Exploit scenario analysis:** No viable attribute/markup break-out path because replacement string is constant and context-safe.

### VERDICT
**FALSE POSITIVE**

### SEVERITY
**INFORMATIONAL**

- **CWE:** N/A (no vulnerability condition).
- **CVSS 3.1:** **0.0**

## Regex 4: Remove h1

```ts
/<h1>.*?<\/h1>\n?/
→ ""
```

### FINDING
Regex 4 removes first single-line `<h1>...</h1>` block. Empirical behavior:
- `<h1>Title</h1>` removed.
- Multi-line `<h1>\nTitle\n</h1>` not matched (no dotall).
- `<h1><script>alert(1)</script></h1>` matched and removed.

### REASONING
- **Capture/substitution behavior:** Non-greedy `.*?` without `s` cannot cross newlines; removal scope is limited.
- **New attack surface vs pass-through:**
  - Does not introduce executable content.
  - Partial matching limitation is correctness/coverage issue, not direct exploit vector.
  - In some cases it accidentally removes potentially dangerous inline script inside single-line h1 (risk-reducing, not risk-creating).
- **Architecture impact:** Since content is static and authored, mismatch mainly affects presentation consistency.
- **Browser model:** Failed removal of multi-line h1 does not create script execution by itself.
- **Exploit scenario analysis:** No payload transforms into a new executable sink due to this regex.

### VERDICT
**FALSE POSITIVE** (security), with a non-security robustness caveat.

### SEVERITY
**INFORMATIONAL**

- **CWE:** CWE-625/CWE-697 style pattern-matching correctness concerns (non-security in this context).
- **CVSS 3.1:** **0.0**

## Regex 5: Ordered list counter reset

```ts
/<ol start="(\d+)">/g
→ `<ol style="counter-reset:step-counter ${parseInt(start) - 1}">`
```

### FINDING
Regex 5 rewrites `<ol start="N">` into inline style with numeric decrement. Empirical test:
- `start="3"` → `counter-reset:step-counter 2`.

### REASONING
- **Capture/substitution behavior:** Only decimal digits captured via `\d+`; injected into numeric CSS token context after `parseInt`.
- **New attack surface vs pass-through:**
  - No arbitrary string injection into style attribute from non-digit input.
  - Cannot break CSS declaration context with `;`/`)`/`url()` because those characters cannot be captured.
- **Architecture impact:** Static authored content further lowers abuse probability.
- **Browser model:** Inline CSS here is non-scriptable under modern browser security model (legacy CSS expression vectors not applicable to modern targets).
- **Exploit scenario analysis:** Attempts like `start="1;..."` fail at regex match stage (`\d+` only). No style-based script execution vector formed.

### VERDICT
**FALSE POSITIVE**

### SEVERITY
**INFORMATIONAL**

- **CWE:** CWE-79 not applicable to this transform; no injection primitive introduced.
- **CVSS 3.1:** **0.0**

## OVERALL ASSESSMENT

### Does `postProcessHtml` introduce new attack surface beyond `dangerouslySetInnerHTML`?
**Materially, no.** Regexes 1, 3, 4, and 5 are non-exploitable transformations under observed behavior. Regex 2 is the only risky pattern, but its risk is primarily **pass-through preservation** of unsafe attributes already present due to upstream unsanitized raw HTML handling.

### Is the real risk upstream?
**Yes.** The dominant risk is the markdown pipeline configuration:
- `remarkRehype({ allowDangerousHtml: true })`
- `rehypeRaw`
- no `rehype-sanitize`
combined with final DOM sink `dangerouslySetInnerHTML`.
This chain permits executable HTML/attributes to survive into rendered pages.

### Actual exploitability in this architecture
- **External attacker without repo content control:** practically not exploitable.
- **Attacker with content control (malicious maintainer, compromised contributor account, merged malicious PR, supply-chain compromise):** exploitable persistent XSS in generated static pages.
Thus, risk is **governance/supply-chain/content-trust dependent**, not user-input-driven.

### Key distinction: pass-through vs new vectors
- `postProcessHtml` mostly performs stylistic rewrites.
- It does **not** create a new sink beyond existing raw HTML acceptance.
- Regex 2 can preserve dangerous attributes, but those attributes already survive upstream; therefore it is a **contributor** to unsafe propagation, not primary origin.

### Actionable recommendations (prioritized)
1. **High priority:** Add `rehype-sanitize` with an allowlist schema tailored for docs content (CWE-79 mitigation). Remove/limit raw HTML features unless explicitly required.
2. **High priority:** Enforce repository controls for content trust: mandatory PR review, branch protection, CODEOWNERS for `docs/`, signed commits where feasible.
3. **Medium priority:** Harden Regex 2 by normalizing/allowlisting `<code>` attributes instead of reinserting `([^>]*)` verbatim.
4. **Medium priority:** Add build-time security checks (HTML lint/policy validation) to fail on event handlers (`on*=`), `javascript:` URLs, and forbidden tags.
5. **Low priority:** Improve Regex 4 correctness (multiline handling) for functional consistency; security impact minimal.

## Summary Table

| Regex | Purpose | Security Finding | Introduces New Attack Surface? | Verdict | Severity | CWE | CVSS 3.1 |
|---|---|---|---|---|---|---|---|
| 1 | Annotate language code blocks | `\w+` constrained capture; quote injection blocked by encoding + pattern | No | FALSE POSITIVE | INFORMATIONAL | CWE-116 (contextual) | 0.0 |
| 2 | Decorate plain code blocks | Broad `([^>]*)` reinsert preserves dangerous attrs (e.g., `on*`) | **Mostly no** (pass-through of upstream danger) | INFORMATIONAL | LOW | CWE-79 (pipeline-level), CWE-20/116 | 2.7 |
| 3 | Add blockquote class | Static literal replacement only | No | FALSE POSITIVE | INFORMATIONAL | N/A | 0.0 |
| 4 | Remove first h1 | Multiline mismatch is correctness issue, not injection | No | FALSE POSITIVE | INFORMATIONAL | Pattern-matching robustness only | 0.0 |
| 5 | Rewrite ordered-list start to CSS counter | Digit-only capture + numeric interpolation only | No | FALSE POSITIVE | INFORMATIONAL | N/A | 0.0 |

### Final Conclusion
`postProcessHtml` is **not the primary security boundary failure**. The meaningful XSS exposure originates upstream from allowing unsanitized raw HTML through the rehype pipeline and rendering it with `dangerouslySetInnerHTML`. In the current controlled, build-time architecture, exploitability is low for external attackers but real for content-supply-chain compromise scenarios.
