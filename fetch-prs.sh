#!/usr/bin/env bash
# Fetches open GitHub PRs authored by the current user and writes to data.jsonl
# Requires: gh CLI authenticated (gh auth login)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_FILE="$SCRIPT_DIR/data.jsonl"
TEMP_FILE="$DATA_FILE.tmp"

# Fetch PRs via gh CLI (include owner for comment fetching)
RAW_JSON=$(gh pr list \
  --author @me \
  --state open \
  --json number,title,headRefName,url,statusCheckRollup,createdAt,reviewDecision,headRepository,headRepositoryOwner \
  2>/dev/null || echo '[]')

# Transform each PR into a card item, fetch comments, and write to temp file
echo "$RAW_JSON" | node -e "
const fs = require('fs');
const { execSync } = require('child_process');
const input = JSON.parse(fs.readFileSync('/dev/stdin', 'utf8'));

const lines = input.map(pr => {
  // Determine CI status from check rollup
  const checks = pr.statusCheckRollup || [];
  let ciStatus = 'none';
  if (checks.length > 0) {
    const hasFailure = checks.some(c => c.state === 'FAILURE' || c.state === 'ERROR');
    const hasPending = checks.some(c => c.state === 'PENDING' || c.state === 'EXPECTED');
    if (hasFailure) ciStatus = 'failing';
    else if (hasPending) ciStatus = 'pending';
    else ciStatus = 'passing';
  }

  const repo = pr.headRepository?.name || 'unknown';
  const owner = pr.headRepositoryOwner?.login || '';

  // Fetch comments via gh api (issue comments = PR conversation)
  let comments = [];
  if (owner && repo !== 'unknown') {
    try {
      const raw = execSync(
        'gh api repos/' + owner + '/' + repo + '/issues/' + pr.number + '/comments --jq \"[.[] | {id: .id, author: .user.login, avatarUrl: .user.avatar_url, body: .body, createdAt: .created_at}]\"',
        { timeout: 10000, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }
      );
      comments = JSON.parse(raw.trim() || '[]');
    } catch (e) {
      // Silently skip — comments are not critical
    }
  }

  return JSON.stringify({
    id: repo + '-' + pr.number,
    status: 'open',
    createdAt: pr.createdAt,
    repo: repo,
    prNumber: pr.number,
    title: pr.title,
    branch: pr.headRefName,
    url: pr.url,
    ciStatus: ciStatus,
    reviewDecision: pr.reviewDecision || '',
    checksRaw: JSON.stringify(checks),
    commentCount: comments.length,
    comments: JSON.stringify(comments),
  });
});
process.stdout.write(lines.join('\n') + (lines.length ? '\n' : ''));
" > "$TEMP_FILE"

# Atomic replace
mv "$TEMP_FILE" "$DATA_FILE"

echo "Wrote $(wc -l < "$DATA_FILE" | tr -d ' ') PRs to $DATA_FILE"
