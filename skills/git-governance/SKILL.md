---
name: git-governance
description: >
  Mandatory governance policy for all git operations. Agents can read and commit
  freely, but MUST request board approval before any git push. This skill
  enforces the "read freely, write with approval" pattern across all companies.
---

# Git Governance Policy

This skill is MANDATORY for all agents that interact with git repositories.
Violations are grounds for immediate termination.

## Rules

### READ: Always Allowed
- `git clone`, `git fetch`, `git pull` — allowed without approval
- `git log`, `git diff`, `git status`, `git blame` — allowed without approval
- Reading any file in any cloned repo — allowed without approval
- `gh` CLI read commands (issues list, pr list, repo view) — allowed without approval

### COMMIT: Allowed Locally
- `git add`, `git commit` — allowed without approval
- Always use descriptive commit messages with context
- Always commit to a **feature branch**, never directly to main/master
- Branch naming: `paperclip/<agent-name>/<short-description>`

### PUSH: REQUIRES BOARD APPROVAL

**NEVER run `git push` without prior board approval.**

Before pushing, you MUST:

1. Prepare a summary of your changes:
   ```bash
   REPO=$(basename $(git rev-parse --show-toplevel))
   BRANCH=$(git rev-parse --abbrev-ref HEAD)
   COMMITS=$(git log --oneline origin/main..HEAD 2>/dev/null || git log --oneline -5)
   FILES=$(git diff --name-only origin/main..HEAD 2>/dev/null || git diff --name-only HEAD~1)
   ```

2. Create an Approval request via the Paperclip API:
   ```bash
   curl -s -X POST "$PAPERCLIP_API_URL/companies/$PAPERCLIP_COMPANY_ID/approvals" \
     -H "Authorization: Bearer $PAPERCLIP_API_KEY" \
     -H "Content-Type: application/json" \
     -H "X-Paperclip-Run-Id: $PAPERCLIP_RUN_ID" \
     -d '{
       "type": "git_push",
       "payload": {
         "repo": "'$REPO'",
         "branch": "'$BRANCH'",
         "commits": "'$COMMITS'",
         "files_changed": "'$FILES'",
         "summary": "<one-line description of what changed and why>"
       }
     }'
   ```

3. **STOP and exit.** Do NOT wait in a loop. The board will approve/reject asynchronously.

4. On your **next heartbeat**, if `PAPERCLIP_APPROVAL_ID` is set and status is "approved":
   ```bash
   git push origin $BRANCH
   ```
   Then comment on the approval confirming the push succeeded.

5. If approval status is "rejected", abandon the push. Comment on the linked issue explaining the rejection.

### DESTRUCTIVE: NEVER ALLOWED (no exceptions)
- `git push --force` or `git push -f`
- `git reset --hard` on any branch that has been pushed
- `git branch -D` on remote branches
- Rewriting published history (`rebase` on pushed commits)
- `rm -rf .git` or any git directory destruction

### PR Creation: Allowed with Approval
- Creating a Pull Request via `gh pr create` follows the same approval flow as push
- The PR itself serves as a review mechanism, but the push that creates it needs approval

## GitHub Authentication

- Use `$GITHUB_TOKEN` from your environment for authentication
- **Never** expose, log, or echo the token value
- Clone via HTTPS: `git clone https://x-access-token:$GITHUB_TOKEN@github.com/OWNER/REPO.git`
- Configure git to use token: `git config credential.helper '!f() { echo "password=$GITHUB_TOKEN"; }; f'`

## Audit

All git operations should be mentioned in your heartbeat run comments so the board
has full visibility of what you did with repo access.
