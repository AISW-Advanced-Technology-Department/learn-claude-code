# CVSS v3.1 Scoring Adjudication (Definitive)

Scope: Next.js static export documentation site; no server runtime/API/forms/database.

## Method Note (CVSS v3.1)
- Privileges Required (PR) is privileges on the **vulnerable component**, not social influence over maintainers.
- Score equation uses FIRST CVSS v3.1 base formula with Roundup to one decimal.
- If multiple threat models exist, choose the one matching the stated vulnerability description; otherwise provide alternate vectors explicitly.

---

## Question 1 — Finding 1 (`dangerouslySetInnerHTML` + build-time markdown): PR:H vs PR:L vs PR:N

### 1) Definitive recommendation
Use **PR:H** for the currently described vulnerability model (malicious content must be merged into trusted repo/build content).

### 2) CVSS v3.1 reasoning
- Vulnerable path is trust-controlled content pipeline (`docs/` -> build -> static artifact).
- External anonymous user cannot directly inject runtime payload into deployed site.
- Submitting a PR is not exploitation; **merge rights** (or equivalent high-trust pipeline compromise) are required for payload to reach production artifact.
- Social engineering a maintainer is not "attacker has lower privileges"; it is an external precondition outside base PR metric semantics.

### 3) Corrected vector
Keep PR at high privilege for this model:
- **AV:N/AC:L/PR:H/UI:R/S:C/C:L/I:L/A:N**

Alternates (only if threat model changes):
- PR:L if any contributor can directly publish docs content.
- PR:N only if attacker can influence content path without authenticated repo/build privileges.

### 4) Correct numeric score
- For **AV:N/AC:L/PR:H/UI:R/S:C/C:L/I:L/A:N**: **4.8** (not 3.8)

(Reference comparisons)
- Same vector with PR:L => 5.4
- Same vector with PR:N => 6.1

---

## Question 2 — Finding 1: Is S:C correct?

### 1) Definitive recommendation
Yes — **S:C is correct** for this finding.

### 2) CVSS v3.1 reasoning
- Vulnerable component/security authority: content/build trust domain.
- Impacted component/security authority: end-user browser session/DOM execution context.
- Successful exploit causes effects beyond the originating authority boundary (repository/build governance -> browser/client authority). This matches CVSS Scope Changed.
- This can be described as stored-XSS-like delivery via supply-chain content poisoning; CVSS scope logic still supports S:C.

### 3) Corrected vector
No scope correction needed:
- **AV:N/AC:L/PR:H/UI:R/S:C/C:L/I:L/A:N**

### 4) Correct numeric score
- **4.8**

---

## Question 3 — Finding 5 (`window.location.href` with hardcoded locales): is PR:N correct?

### 1) Definitive recommendation
Current finding narrative contradicts PR:N. If only source-code editors can alter redirect target behavior, use **PR:H**.

### 2) CVSS v3.1 reasoning
- If exploit requires changing source constants, attacker must have high privilege in codebase/release process.
- PR:N implies unauthenticated remote attacker can exploit as-is, which description explicitly denies.

### 3) Corrected vector
- **AV:N/AC:L/PR:H/UI:R/S:U/C:N/I:L/A:N**

### 4) Correct numeric score
- **2.4** (not 2.6)

(If someday locale is user-controlled at runtime, PR could become N, but that is a different vulnerability state.)

---

## Question 4 — A1 (Missing CSP): medium severity for this static site?

### 1) Definitive recommendation
Do **not** score missing CSP alone as a direct exploitable vulnerability unless paired with a concrete injection primitive. Treat as hardening/control gap (often informational or governance risk).

### 2) CVSS v3.1 reasoning
- CVSS scores exploitability/impact of a vulnerability, not "absence of best practice" in isolation.
- Given vector is mathematically incorrect in report.
- For this environment, CSP mostly reduces impact of other flaws (notably Finding 1).
- If still forced into CVSS base for "contingent exploitability," set **AC:H** to reflect prerequisite chain.

### 3) Corrected vector
Two defensible options:
1. Preferred (pure control-gap semantics): **No CVSS base score / N/A**.
2. If forced to score contingency risk: **AV:N/AC:H/PR:N/UI:R/S:C/C:L/I:L/A:N**.

### 4) Correct numeric score
- Stated vector `AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N` actually computes to **6.1** (not 5.3).
- Contingent AC:H variant computes to **4.7**.

---

## Question 5 — A2/A3/A4 identical vectors but different stated scores

### 1) Definitive recommendation
Correct: identical vectors must produce identical scores. Current report is internally inconsistent.

### 2) CVSS v3.1 reasoning
All three use `AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:N/A:N`; therefore base score must be the same.

### 3) Corrected vector(s)
- The shared vector computes to one value only.
- Suggested differentiation:
  - **A2 (missing baseline headers)**: `AV:N/AC:H/PR:N/UI:R/S:U/C:L/I:N/A:N`
  - **A3 (missing noreferrer)**: `AV:N/AC:H/PR:N/UI:R/S:U/C:L/I:N/A:N`
  - **A4 (dependency program not evidenced)**: treat as governance/process gap => **CVSS N/A** (or `C:N/I:N/A:N` => 0.0 if forced)

### 4) Correct numeric score
- For existing identical vector: **4.3** (not 3.7 / 2.6 / 3.3).
- Suggested differentiated scores:
  - A2 suggested vector => **3.1**
  - A3 suggested vector => **3.1**
  - A4 suggested treatment => **N/A** (or 0.0 if forcibly encoded)

---

## Corrected Summary Table

| Item | Recommendation | Correct Vector | Correct Score |
|---|---|---|---:|
| Finding 1 (Q1/Q2) | Keep PR:H and S:C for current trust model | AV:N/AC:L/PR:H/UI:R/S:C/C:L/I:L/A:N | **4.8** |
| Finding 5 (Q3) | PR should be H if only dev source changes can exploit | AV:N/AC:L/PR:H/UI:R/S:U/C:N/I:L/A:N | **2.4** |
| A1 Missing CSP (Q4) | Prefer CVSS N/A; if forced, contingency scoring with AC:H | AV:N/AC:H/PR:N/UI:R/S:C/C:L/I:L/A:N | **4.7** *(forced)* |
| A2 Missing headers (Q5) | Differentiate as hardening gap with higher preconditions | AV:N/AC:H/PR:N/UI:R/S:U/C:L/I:N/A:N | **3.1** |
| A3 Missing noreferrer (Q5) | Privacy-leak hardening gap, same low-impact profile as A2 | AV:N/AC:H/PR:N/UI:R/S:U/C:L/I:N/A:N | **3.1** |
| A4 Program gap (Q5) | Governance control deficiency, not direct technical vuln | N/A (or AV:N/AC:L/PR:N/UI:R/S:U/C:N/I:N/A:N) | **N/A** *(or 0.0 forced)* |

## Formula Checkpoints (for auditability)
- `AV:N/AC:L/PR:H/UI:R/S:C/C:L/I:L/A:N` => 4.8
- `AV:N/AC:L/PR:H/UI:R/S:U/C:N/I:L/A:N` => 2.4
- `AV:N/AC:L/PR:N/UI:R/S:C/C:L/I:L/A:N` => 6.1
- `AV:N/AC:H/PR:N/UI:R/S:C/C:L/I:L/A:N` => 4.7
- `AV:N/AC:L/PR:N/UI:R/S:U/C:L/I:N/A:N` => 4.3
- `AV:N/AC:H/PR:N/UI:R/S:U/C:L/I:N/A:N` => 3.1
