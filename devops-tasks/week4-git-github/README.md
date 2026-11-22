# Week 4 — Version control and collaboration (Task 4)

## Practical A — Git from the command line

```bash
git config --global user.name  "Shoxjahon Tuymurodov"
git config --global user.email "<email of my GitHub account>"
git config --global init.defaultBranch main
git config --global core.editor nano
git config --global pull.rebase false

cd ~/scripts && git init
printf '*.log\nbackups/\n*.env\n' > .gitignore
git add . && git commit -m "Add Week 3 scripts"

# A4 branch + fast-forward
git switch -c docs/readme && nano README.md && git add README.md && git commit -m "Add README"
git switch main && git merge docs/readme && git branch -d docs/readme

# A5 conflict: KEEP=7 on a branch, KEEP=3 on main, merge -> CONFLICT,
#    keep KEEP=5, remove the <<<<<<< ======= >>>>>>> lines, bash -n, git commit

# A6 rebase a local branch onto main -> new commit hashes
# A7 undo: git restore <file> (uncommitted)  ·  git revert --no-edit HEAD (committed, shared)
git log --oneline --graph --all
```

## This repository as Practical B evidence

| Requirement (B1–B8) | Where in this repo |
|---|---|
| Public repository with `.gitignore` and `README` | root `README.md`, `.gitignore` (blocks `.env`, keys, logs) |
| Issues with labels | create from `.github/ISSUE_TEMPLATE/` — see `docs/meetings.md` for the planned issues |
| Protected `main` (PR + 1 approval) | Settings → Branches → rule for `main`; see `docs/access.md` |
| PR template | `.github/pull_request_template.md` |
| Team agreement (GitHub Flow, branch per issue, review in 24 h) | root `README.md` → *Team agreement* |
| Team Dockerfile (Week 5 B8) | root `Dockerfile` |

## Exit questions

1. **`git add` vs `git commit`?** `add` puts the current version of a file into the staging area (what the next commit will contain); `commit` saves the staged snapshot permanently in history with a message, author and parent.
2. **Why was the direct push to `main` rejected?** Branch protection requires every change to come through a pull request with an approval. Instead: create a branch, push it, open a PR, get a review, merge.
3. **What happened to issue #1 when the PR was merged?** The PR description contained `Closes #1`; GitHub closes the linked issue automatically on merge, so history links problem → change → review.
4. **Fork vs branch?** Branch when I have write access to the repository (my team's repo). Fork when I do not (the class repository): I work in my own copy and open a PR to ask the owner to pull my change.
