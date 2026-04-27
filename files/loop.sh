#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  ./loop.sh [plan] [max_iterations] [--fast] [--effort low|medium|high|xhigh]

Examples:
  ./loop.sh
  ./loop.sh 20
  ./loop.sh plan
  ./loop.sh plan 5
  ./loop.sh --fast
  ./loop.sh plan --fast 2
  ./loop.sh --effort high
  ./loop.sh plan --effort xhigh 2

Environment:
  RALPH_CLI=codex|claude          CLI to use (default: codex)
  RALPH_MODEL=<model>             Optional model override
  RALPH_SEARCH=1                  Enable Codex live web search
  RALPH_PUSH=0                    Disable git push after each committed iteration
  RALPH_ALLOW_DIRTY=1             Allow starting from a dirty worktree
EOF
}

RALPH_CLI="${RALPH_CLI:-codex}"
MODE="build"
PROMPT_FILE="PROMPT_build.md"
MAX_ITERATIONS=0
FAST_MODE_ENABLED=0
THINKING_EFFORT=""
SEEN_PLAN=0
SEEN_MAX_ITERATIONS=0

while [[ $# -gt 0 ]]; do
  case "${1}" in
    plan)
      [[ ${SEEN_PLAN} -eq 0 ]] || {
        usage
        exit 1
      }
      MODE="plan"
      PROMPT_FILE="PROMPT_plan.md"
      SEEN_PLAN=1
      shift
      ;;
    --fast)
      FAST_MODE_ENABLED=1
      shift
      ;;
    --effort)
      [[ $# -ge 2 ]] || {
        usage
        exit 1
      }
      THINKING_EFFORT="${2}"
      case "${THINKING_EFFORT}" in
        low|medium|high|xhigh) ;;
        *)
          usage
          exit 1
          ;;
      esac
      shift 2
      ;;
    --effort=*)
      THINKING_EFFORT="${1#--effort=}"
      case "${THINKING_EFFORT}" in
        low|medium|high|xhigh) ;;
        *)
          usage
          exit 1
          ;;
      esac
      shift
      ;;
    [0-9]*)
      [[ "${1}" =~ ^[0-9]+$ ]] && [[ ${SEEN_MAX_ITERATIONS} -eq 0 ]] || {
        usage
        exit 1
      }
      MAX_ITERATIONS="${1}"
      SEEN_MAX_ITERATIONS=1
      shift
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required." >&2
  exit 1
fi

case "${RALPH_CLI}" in
  codex)
    if ! command -v codex >/dev/null 2>&1; then
      echo "Error: Codex CLI not found." >&2
      echo "Install with: npm install -g @openai/codex" >&2
      echo "Then authenticate with: codex login" >&2
      exit 1
    fi
    ;;
  claude)
    if ! command -v claude >/dev/null 2>&1; then
      echo "Error: Claude Code CLI not found." >&2
      echo "Install with: npm install -g @anthropic-ai/claude-code" >&2
      exit 1
    fi
    if [[ "${FAST_MODE_ENABLED}" == "1" ]]; then
      echo "Error: --fast is only supported when RALPH_CLI=codex." >&2
      exit 1
    fi
    if [[ -n "${THINKING_EFFORT}" ]]; then
      echo "Error: --effort is only supported when RALPH_CLI=codex." >&2
      exit 1
    fi
    ;;
  *)
    echo "Error: unsupported RALPH_CLI='${RALPH_CLI}'. Use 'codex' or 'claude'." >&2
    exit 1
    ;;
esac

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: run loop.sh from inside a git repository." >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

if [[ ! -f "${PROMPT_FILE}" ]]; then
  echo "Error: ${PROMPT_FILE} not found in ${REPO_ROOT}." >&2
  exit 1
fi

CURRENT_BRANCH="$(git branch --show-current)"
if [[ -z "${CURRENT_BRANCH}" ]]; then
  echo "Error: detached HEAD is not supported for Ralph runs." >&2
  exit 1
fi

if [[ "${RALPH_ALLOW_DIRTY:-0}" != "1" ]] && [[ -n "$(git status --porcelain)" ]]; then
  echo "Error: git worktree is not clean." >&2
  echo "Ralph commits once per iteration and can accidentally include unrelated changes." >&2
  echo "Commit or stash current work first, or override with RALPH_ALLOW_DIRTY=1." >&2
  exit 1
fi

PUSH_ENABLED="${RALPH_PUSH:-1}"
if [[ "${PUSH_ENABLED}" == "1" ]] && ! git remote get-url origin >/dev/null 2>&1; then
  echo "Warning: no origin remote found; disabling push for this run." >&2
  PUSH_ENABLED="0"
fi

MODEL_DISPLAY=""
if [[ "${RALPH_CLI}" == "codex" ]]; then
  AGENT_CMD=(codex exec -C "${REPO_ROOT}")
  if [[ -n "${RALPH_MODEL:-}" ]]; then
    AGENT_CMD+=(-m "${RALPH_MODEL}")
    MODEL_DISPLAY="${RALPH_MODEL}"
  fi
  if [[ -n "${THINKING_EFFORT}" ]]; then
    AGENT_CMD+=(-c "model_reasoning_effort=\"${THINKING_EFFORT}\"")
  fi
  if [[ "${FAST_MODE_ENABLED}" == "1" ]]; then
    AGENT_CMD+=(--enable fast_mode)
    FAST_MODE_DESCRIPTION='on (--enable fast_mode)'
  else
    AGENT_CMD+=(--disable fast_mode)
    FAST_MODE_DESCRIPTION='off (--disable fast_mode)'
  fi
  if [[ "${RALPH_SEARCH:-0}" == "1" ]]; then
    AGENT_CMD+=(--search)
  fi
  AGENT_CMD+=(--dangerously-bypass-approvals-and-sandbox -)
  CLI_DISPLAY="Codex CLI ($(codex --version))"
  EXECUTION_DESCRIPTION="dangerous bypass"
else
  MODEL_DISPLAY="${RALPH_MODEL:-opus}"
  AGENT_CMD=(
    claude -p
    --dangerously-skip-permissions
    --output-format=stream-json
    --model "${MODEL_DISPLAY}"
    --verbose
  )
  FAST_MODE_DESCRIPTION='n/a (Codex-only)'
  CLI_DISPLAY="Claude Code CLI ($(claude --version))"
  EXECUTION_DESCRIPTION="dangerous skip permissions"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CLI: ${CLI_DISPLAY}"
echo "Mode: ${MODE}"
echo "Prompt: ${PROMPT_FILE}"
echo "Branch: ${CURRENT_BRANCH}"
echo "Execution: ${EXECUTION_DESCRIPTION}"
echo "Fast mode: ${FAST_MODE_DESCRIPTION}"
if [[ -n "${MODEL_DISPLAY}" ]]; then
  echo "Model: ${MODEL_DISPLAY}"
fi
if [[ -n "${THINKING_EFFORT}" ]]; then
  echo "Thinking effort: ${THINKING_EFFORT}"
fi
if [[ ${MAX_ITERATIONS} -gt 0 ]]; then
  echo "Max iterations: ${MAX_ITERATIONS}"
fi
if [[ "${PUSH_ENABLED}" == "1" ]]; then
  echo "Push: enabled"
else
  echo "Push: disabled"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ITERATION=0

while true; do
  if [[ ${MAX_ITERATIONS} -gt 0 && ${ITERATION} -ge ${MAX_ITERATIONS} ]]; then
    echo "Reached max iterations: ${MAX_ITERATIONS}"
    break
  fi

  START_HEAD="$(git rev-parse HEAD)"
  echo
  echo "=== Ralph iteration $((ITERATION + 1)) (${MODE}) ==="

  if ! "${AGENT_CMD[@]}" < "${PROMPT_FILE}"; then
    echo "Ralph iteration failed; stopping loop." >&2
    exit 1
  fi

  if [[ -f "AGENTS.md" ]]; then
    cp AGENTS.md CLAUDE.md
  fi

  END_HEAD="$(git rev-parse HEAD)"
  WORKTREE_STATUS="$(git status --porcelain)"

  if [[ "${END_HEAD}" == "${START_HEAD}" ]]; then
    if [[ -n "${WORKTREE_STATUS}" ]]; then
      echo "Iteration ended without a commit and left a dirty worktree; stopping." >&2
      exit 1
    fi
    echo "No new commit produced; stopping loop."
    break
  fi

  if [[ "${PUSH_ENABLED}" == "1" ]]; then
    git push origin "${CURRENT_BRANCH}" || git push -u origin "${CURRENT_BRANCH}"
  fi

  ITERATION=$((ITERATION + 1))
done
