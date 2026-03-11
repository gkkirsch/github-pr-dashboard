---
name: github-pr-dashboard
description: >
  Dashboard card showing open GitHub pull requests across all repos.
  Uses the gh CLI to fetch PRs authored by the current user.
  Displays repo name, title, branch, CI status, review status, comments, and links to GitHub.
  Auto-refreshes every 5 minutes with a manual refresh button.
  Triggers: "check PRs", "open pull requests", "my PRs".
  NOT for: creating PRs (use gh CLI directly), code review (use GitHub).
version: 0.2.0
allowed-tools: Bash

metadata:
  superbot:
    emoji: "\U0001F500"
  openclaw:
    emoji: "\U0001F500"
    requires:
      bins: ["gh"]
    install:
      - id: brew
        kind: brew
        formula: gh
        bins: ["gh"]
        label: "Install GitHub CLI (brew)"
---

# GitHub PR Dashboard

Dashboard card plugin that shows your open GitHub pull requests.

## How It Works

1. **fetch-prs.sh** runs `gh pr list --author @me --state open` and writes structured data to `data.jsonl`, including PR comments fetched via `gh api`
2. **superbot.json** declares the card manifest with a `github-prs` renderer and `refreshCommand`
3. The dashboard auto-discovers the card via the skill-platform protocol and renders it with the custom renderer
4. Each PR shows: CI status dot, repository name, PR number, title, branch name, review badge, time ago, and a clickable link to GitHub
5. PRs with comments show an expandable comment section with author avatar, name, timestamp, and comment body

## Requirements

- `gh` CLI must be installed and authenticated (`gh auth login`)
- The dashboard server must be running

## Data Fields

Each PR includes:
- `repo` — repository name
- `prNumber` — PR number
- `title` — PR title
- `branch` — branch name
- `url` — GitHub URL
- `ciStatus` — passing, failing, pending, or none
- `reviewDecision` — APPROVED, CHANGES_REQUESTED, REVIEW_REQUIRED, or empty
- `checksRaw` — raw JSON of CI check results
- `commentCount` — number of comments on the PR
- `comments` — JSON string of comment objects (id, author, avatarUrl, body, createdAt)

## Plugin Structure

```
github-pr-dashboard/
  SKILL.md          ← this file (skill prompt)
  superbot.json     ← card manifest
  fetch-prs.sh      ← data population script
  data.jsonl        ← runtime data (auto-generated)
```
