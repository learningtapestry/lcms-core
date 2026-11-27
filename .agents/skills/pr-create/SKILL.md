---
name: pr-create
description: Create a Pull Request for the current branch of the LCMS Core project, using the structure described in this skill. Pass any extra context as arguments.
---

Create a Pull Request for the current branch.

Steps:
1. Run `git status` to check for uncommitted changes and the current branch.
2. Find the base branch: `master` for a standalone branch, the parent branch for a branch inside a PR stack.
3. Run `git log <base>..HEAD --oneline` to see all commits in this branch.
4. Run `git diff <base>...HEAD` to analyze all changes.
5. Use the following structure for PR. Fill it in:
   - **Description**: what the PR changes and why, in a short paragraph or two. Mention any API
     contract or behavior change here.
   - **Issue**: `Refs:` followed by `- #<issue id>`. Never use `Closes` / `Fixes`; issues are closed manually.
   - **Changes Made**: a bullet list, summarized from the commit messages and the diff.
   - **Screenshots**: screenshots for visual changes; otherwise `None. No visual changes.`
   - **Testing**: the exact commands that were run (specs, Minitest, migration up/down), one bullet each.
   - **Deployment**: Add the three bullets
     (`**Pre-deploy:**`, `**Post-deploy:**`, `**Rollback:**`), each `none` unless there is a manual step.
     Give exact commands, the environment and the order: duplicate checks before a unique index,
     recovery from an INVALID concurrent index, new Sidekiq queues, Redis/Sidekiq cleanup, anything that
     makes a rollback unsafe. Risky migrations need "RDS snapshot required" under Pre-deploy plus a
     Rollback note (see `DEPLOYMENT.md#risky-migrations`). Drop the HTML comment from the final body.
   - **Related PRs**: `Stacked on #<parent PR>` for a stacked PR, conflicting or related open PRs, and
     known follow-ups as `Not in this PR: ...`.
6. Create the PR: `gh pr create --base <base> --title "TITLE" --body-file <file>`
   - The title is the subject of the first commit, which already has the form `(#issueid) Issue title`.
     Do not add the issue prefix twice.
   - Write the body to a file under the project `tmp/` folder and pass it with `--body-file`.
   - Never add AI or assistant attribution of any kind to the body.

If the user passed arguments with this skill, use them as additional context for the PR description.

Notes:
- NEVER push directly to `master`, `staging`, or `production` — always open a PR from a feature branch.
- Do not create the PR without user confirmation if there are uncommitted changes.
