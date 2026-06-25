---
name: review
description: Review the current git diff for security issues, N+1 queries, Rails convention violations, style problems, and missing test coverage. Uses the code-reviewer agent and runs Rubocop + Brakeman.
---

Use the code-reviewer agent to review the current git diff.

Run: `git diff HEAD` to see what changed, then review all modified Ruby files for:
- Security issues (Brakeman categories)
- N+1 queries and performance problems
- Rails conventions violations
- rubocop-rails-omakase style issues
- Missing test coverage

After reviewing, run:
```bash
docker compose run --rm rails bundle exec rubocop
docker compose run --rm rails bundle exec brakeman --no-pager
```

Output a structured review with 🔴 Critical / 🟡 Important / 🟢 Minor sections.
