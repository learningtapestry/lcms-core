Пункт 2 Use the pre-commit agent to run all quality checks before committing.

Run in order:
1. `docker compose run --rm rails bundle exec rubocop -a` — auto-fix style
2. `docker compose run --rm rails bundle exec rubocop` — check remaining violations
3. `docker compose run --rm rails bundle exec brakeman --no-pager` — security scan
4. Check YAML syntax for any changed config files
5. Run specs for modified files (with --pattern override)

Then show the git status and suggest a commit message following the project format:
- English only
- Short subject line (capital letter)
- Blank line + bullet list of changes
- Remind to use: `git commit -s`
- NEVER suggest Co-Authored-By
