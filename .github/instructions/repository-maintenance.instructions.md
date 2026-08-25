---
applyTo: "AGENTS.md,CONTEXT.md,.github/copilot-instructions.md,.github/skills/**,.github/agents/**,.github/instructions/**,maintainer-skills-lock.json,docs/agents/**,docs/superpowers/**,docs/workshop/**,scripts/maintainer_skills.py,scripts/setup-maintainer-skills.sh,scripts/validate-maintainer-skills.sh,scripts/test-maintainer-skills.sh,scripts/validate-copilot-assets.sh,scripts/test-copilot-assets.sh"
---

# Repository maintenance

- Track issues and specifications in GitHub Issues and use `gh` for issue operations; follow [docs/agents/issue-tracker.md](../../docs/agents/issue-tracker.md).
- Use only the five canonical triage labels without overrides; follow [docs/agents/triage-labels.md](../../docs/agents/triage-labels.md).
- Preserve the single-context domain documentation layout and vocabulary rules in [docs/agents/domain.md](../../docs/agents/domain.md).
- Preserve portability across supported Copilot clients. Avoid client-specific behavior unless the limitation and equivalent path are explicit.
- Preserve human authority over consequential decisions, Risk Gates, residual-risk acceptance, and final completion claims.
- When changing Copilot assets, update `scripts/validate-copilot-assets.sh` and its focused tests for the new contract.
- Add or mutate a fixture so the focused test fails for the intended missing contract before changing the asset itself.
- Keep `to-spec` maintainer-scoped: it serves people building the workshop, never the attendee path, and its published spec remains a proposal that the human accepts or rejects.
- Keep maintainer-only skills in the non-discovery catalog and generate client projections only through `scripts/setup-maintainer-skills.sh`; never expand the attendee `.github/skills` inventory as a side effect.
