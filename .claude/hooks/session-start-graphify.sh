#!/bin/bash
set -euo pipefail

# Only in Claude Code on the web (ephemeral containers never keep graphify-out/,
# which is gitignored on purpose — it's a cheap, regenerable local artifact).
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

command -v uv >/dev/null 2>&1 || exit 0

# This repo's tree is large enough (~2000 code files) that a fresh full build
# measured ~3 minutes. Run async so session start isn't blocked on it; the
# graphify MCP server just won't have data until the build finishes.
echo '{"async": true, "asyncTimeout": 300000}'

GRAPH="$CLAUDE_PROJECT_DIR/graphify-out/graph.json"

if [ -f "$GRAPH" ]; then
  # Already built earlier this session (resume/clear/compact) - cheap AST re-extract.
  uv run --with graphifyy graphify update "$CLAUDE_PROJECT_DIR" --no-cluster >/dev/null 2>&1 || true
else
  # Fresh container - full code-only build, no LLM cost.
  uv run --with graphifyy graphify "$CLAUDE_PROJECT_DIR" --code-only --no-label >/dev/null 2>&1 || true
fi
uv run --with graphifyy graphify cluster-only "$CLAUDE_PROJECT_DIR" --no-label --no-viz >/dev/null 2>&1 || true
