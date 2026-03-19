# CVSS v3.1 Intermediate Value Audit

**Date:** 2026-03-19T12:11:23  
**Target:** `docs/logs/cvss-analysis-opus.md` lines 80–560  
**Method:** Python `Decimal` exact arithmetic, cross-verified by claude-opus-4.6 (Precision Arithmetic Specialist) and gpt-5.3-codex (Cross-Check Specialist)  
**Scope:** Intermediate calculation values only; all 10 final scores previously confirmed correct.

---

## Verified Discrepancies

### D1 — Line 102: `0.3916 × 0.9731`

| Item | Value |
|------|-------|
| Doc | 0.38104 |
| Exact | 0.38106596 |
| Error | −0.00002596 |

- User's characterization "exact is 0.38107" is **approximately correct** — 0.38107 is the 5dp rounding of 0.38106596 (off by 0.00000404). Strictly, the exact value is 0.38106596.

### D2 — Lines 104–109: Power chain base propagation

| Item | Value |
|------|-------|
| Doc base | 0.36104 (from 0.38104 − 0.02) |
| Exact base | 0.36106596 (from 0.38106596 − 0.02) |
| Error at ^13 | ~1.66 × 10⁻⁹ |

- Doc's power values **are internally consistent** with their own base of 0.36104.
- Effect on final score: **zero** (difference ~10⁻⁹, scores rounded to 0.1).
- User's claim confirmed.

### D3 — Line 212: Exploitability chain `8.22 × 0.85 × 0.44 × 0.68 × 0.68`

| Item | Value |
|------|-------|
| Doc final step | 2.0903 × 0.68 = 1.4214 |
| Step-by-step exact | 2.0903 × 0.68 = 1.421404 |
| Full exact chain | 1.4215470720 |
| Doc error vs chain | −0.0001470720 |

- **Root cause** (identified by opus reviewer): the intermediate 2.0903 is itself wrong. Exact: 8.22 × 0.85 × 0.44 × 0.68 = 2.09051040, which rounds to 2.0905, not 2.0903. The error originates from `3.074 × 0.68 = 2.09032` being truncated to 2.0903.
- User's characterization confirmed: doc 1.4214 differs from exact chain by ~0.0001.

### D4 — Line 223: `6.42 × 0.3916`

| Item | Value |
|------|-------|
| Doc | 2.5141 |
| Exact | 2.514072 |
| Error | +0.000028 |

- Doc value is **legitimate standard rounding** to 4dp (digit after 4th decimal is 7 ≥ 5, rounds up). Not a calculation error per se, but inconsistent with truncation used in D3.
- User's characterization confirmed.

### D5 — Lines 448–449: `2.613 × 0.68`

| Item | Value |
|------|-------|
| Doc shows | 3.074 × 0.85 = 2.613, then × 0.68 = 1.7769 |
| 3.074 × 0.85 exact | 2.61290 (doc rounds up to 2.613) |
| 2.613 × 0.68 exact | 1.77684 (would round to 1.7768) |
| Full exact chain | 1.7769338400 |
| Doc value | 1.7769 |

- Doc's 1.7769 **cannot** be derived from the shown `2.613 × 0.68 = 1.77684`.
- It matches the full-precision chain `2.613138 × 0.68 = 1.77693384 ≈ 1.7769`.
- This is **mixed-precision reporting**: hidden precision was used, then a rounded intermediate was displayed.
- User's characterization confirmed.

---

## Additional Line Ranges Checked

| Lines | Chain | Full Exact | Doc Value | Diff | Status |
|-------|-------|-----------|-----------|------|--------|
| 117–120 | 8.22×0.85×0.77×0.50×0.68 | 1.8291966000 | 1.8292 | 3.4×10⁻⁶ | ✅ OK |
| 193–196 | 8.22×0.85×0.77×0.68×0.68 | 2.4877073760 | 2.4877 | 7.4×10⁻⁶ | ✅ OK |
| 225–228 | 8.22×0.85×0.77×0.27×0.68 | 0.9877661640 | 0.9878 | 3.4×10⁻⁵ | ✅ OK |
| 313–316 | 8.22×0.85×0.77×0.85×0.68 | 3.1096342200 | 3.1096 | 3.4×10⁻⁵ | ✅ OK |
| 361–364 | Same as 225–228 | — | — | — | ✅ OK |
| 409–413 | Same as 313–316 | — | — | — | ✅ OK |
| 446–449 | Same as D5 | — | — | — | ⚠️ D5 |
| 541–542 | Same as D5 (compressed) | — | — | — | ⚠️ D5 |

**Note (from GPT reviewer):** Lines 541–542 have intermediate truncations (3.074 vs exact 3.074280, 2.613 vs exact 2.613138) exceeding 0.0001, so saying "only sub-0.00005 differences" in those ranges is not strictly accurate for the shown intermediates.

---

## Summary

| # | Location | Nature | Magnitude | Affects Final? |
|---|----------|--------|-----------|----------------|
| D1 | L102 | Wrong product | 2.6×10⁻⁵ | No |
| D2 | L104–109 | Propagated base error | 1.7×10⁻⁹ at ^13 | No |
| D3 | L212 | Truncated intermediate + wrong prior step | 1.5×10⁻⁴ | No |
| D4 | L223 | Rounded up (valid but inconsistent style) | 2.8×10⁻⁵ | No |
| D5 | L449 | Mixed-precision reporting | 6.0×10⁻⁵ | No |

**None of the 5 discrepancies affect any final CVSS score.** They reflect minor arithmetic display inconsistencies typical of manual/mixed-tool calculation workflows.

---

## Sub-agent Log

- **claude-opus-4.6** (Precision Arithmetic Specialist): Independently verified all 5 discrepancies via Python Decimal. Identified D3 root cause (intermediate 2.0903 should be 2.0905) and D4 rounding inconsistency. All findings confirmed.
- **gpt-5.3-codex** (Cross-Check Specialist): Independently verified all 5 discrepancies via Python Decimal. Clarified D1 exact vs rounded distinction, confirmed D4 as legitimate standard rounding, explained D5 hidden-precision mechanism. Flagged 541–542 intermediate magnitude note. All findings confirmed.
