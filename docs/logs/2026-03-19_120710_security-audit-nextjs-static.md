# Security Audit Log — Next.js Static Export (Vercel)

**Date**: 2026-03-19 12:07  
**Scope**: web/next.config.ts, web/vercel.json, web/tsconfig.json, web/postcss.config.mjs, requirements.txt, web/package.json, web/src/components/docs/doc-renderer.tsx, web/src/app/[locale]/layout.tsx

## Sub-Agents Used

| Agent ID | Model | Role | Status |
|---|---|---|---|
| primary-auditor | claude-opus-4.6 | Primary Auditor | Timed out / abandoned |
| secondary-auditor | gpt-5.3-codex | Security Architect | Completed ✅ |
| primary-auditor-2 | claude-opus-4.6 | Backup Auditor | Running (superseded) |
| reviewer-gemini-1 | gemini-3-pro-preview | Independent QA Reviewer | Completed ✅ |

## Reviewer Corrections Applied
- SHA-256 hash in secondary auditor's CSP was incorrect (`TCSGhKaTzimh5T1JOMfBncfBZ9FYsV0g+8Ft/rdo8cE=`); corrected to `dNaZX0l5ak4b1tEujA2oprsBF0sQpk6ORAwA4IxLVEE=` (verified via Node.js crypto against exact template literal content)
- COEP `require-corp` flagged as risky due to framer-motion and potential external resources
- Next.js hydration inline scripts noted as additional CSP concern

## Output
See final audit report delivered to user.
