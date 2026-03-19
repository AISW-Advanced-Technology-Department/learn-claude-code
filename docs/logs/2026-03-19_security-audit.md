# Security Audit Log — 2026-03-19

## Task
Comprehensive security audit of Next.js static export configuration files deployed on Vercel.

## Files Audited
- `web/next.config.ts`
- `web/vercel.json`
- `web/tsconfig.json`
- `web/postcss.config.mjs`
- `requirements.txt`

## Sub-Agent Work

### Phase 1: Initial Audit
| Agent | Model | Role | Status | Duration |
|-------|-------|------|--------|----------|
| security-audit-web | claude-opus-4.6 | Full security audit (web configs) | Timed out (>15min) | N/A |
| security-audit-deps | gpt-5.3-codex | Supply chain & dependency audit | Completed | ~98s |

### Phase 2: Review
| Agent | Model | Role | Status | Duration |
|-------|-------|------|--------|----------|
| review-audit-gemini | gemini-3-pro-preview | Adversarial Red Team Reviewer | Completed | ~94s |
| review-audit-sonnet | claude-sonnet-4.5 | Defense-in-Depth Architect | Timed out (>14min) | N/A |

### Key Findings Summary
- **High**: Missing security headers in vercel.json (CSP, HSTS, X-Frame-Options, X-Content-Type-Options)
- **High** (new from review): Redirect bypass via Vercel deployment aliases — `has` condition only matches one hostname
- **Medium**: Unbounded Python dependency versions (`>=` with no upper bound)
- **Medium**: 308 permanent redirect caching risks
- **Low**: Missing Referrer-Policy, Permissions-Policy
- **Low**: `allowJs: true` in tsconfig weakens type safety boundary
- **Info**: Various items confirmed as non-issues (postcss plugin, unoptimized images, trailingSlash, etc.)

### Reviewer Disagreements
- Gemini reviewer noted headers findings should be re-scoped: on the primary redirect domain they're irrelevant (body-less 308), but on alias/preview domains they're critical
- Gemini added bypass via Vercel aliases as a high-severity missed finding
- Overall audit quality rated 6/10 by Gemini reviewer

## Final Report
See compiled report delivered to user in conversation.
