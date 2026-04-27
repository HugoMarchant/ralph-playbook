# Ralph + Symphony Developer Workflow Installation Guide

This guide provides exhaustive, step-by-step instructions for implementing Ralph loops into a new or existing repository, then optionally adding Symphony as a board-driven outer loop for parallel unattended work. It is designed to be followed by an LLM assistant (e.g. Codex CLI or Claude Code) working with a human developer.

The target workflow is:

```text
Local / deliberate work:
specs/* + AGENTS.md + IMPLEMENTATION_PLAN.md
        ↓
./loop.sh plan
        ↓
./loop.sh
        ↓
one task per fresh Codex or Claude CLI execution

Parallel / unattended work:
Linear issue board
        ↓
Symphony daemon
        ↓
one isolated workspace per issue
        ↓
Codex app-server session per issue
        ↓
branch / PR / Linear comment / Human Review handoff
```

Keep Ralph as the repo-level harness. Add Symphony when the repository has enough specs, tests, and workflow discipline for issue-sized work to run unattended.

> **For the implementing LLM:** At several steps you will need information from the human you are working with. These are marked with **ASK THE HUMAN**. Do not guess or assume — ask them directly using your question/prompt tools before proceeding.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Understand Your Project](#2-understand-your-project)
3. [Create the Directory Structure](#3-create-the-directory-structure)
4. [Create AGENTS.md](#4-create-agentsmd)
5. [Create PROMPT_plan.md](#5-create-prompt_planmd)
6. [Create PROMPT_build.md](#6-create-prompt_buildmd)
7. [Create IMPLEMENTATION_PLAN.md](#7-create-implementation_planmd)
8. [Create loop.sh](#8-create-loopsh)
9. [Create WORKFLOW.md for Symphony](#9-create-workflowmd-for-symphony)
10. [Create Specification Files](#10-create-specification-files)
11. [Update .gitignore](#11-update-gitignore)
12. [Security: Sandbox Setup](#12-security-sandbox-setup)
13. [First Run: Planning Mode](#13-first-run-planning-mode)
14. [Building Mode](#14-building-mode)
15. [Symphony Outer Loop](#15-symphony-outer-loop)
16. [Ongoing Operation & Tuning](#16-ongoing-operation--tuning)
17. [Optional Enhancements](#17-optional-enhancements)
18. [Troubleshooting](#18-troubleshooting)
19. [Quick Reference](#19-quick-reference)

---

## 1. Prerequisites

Before starting, ensure the following are installed and available:

### Required Software

| Tool | Purpose | Install Check |
|------|---------|---------------|
| **Codex CLI** (default) or **Claude Code CLI** | The AI agent that powers each loop iteration | `codex --version` or `claude --version` |
| **Git** | Version control; Ralph commits after each task | `git --version` |
| **Bash** | Shell to run the loop script | `bash --version` |
| **An OpenAI API key** (for Codex) or **Anthropic API key** (for Claude) | Required for the chosen CLI | `echo $OPENAI_API_KEY` or `echo $ANTHROPIC_API_KEY` |
| **GitHub CLI** | PR creation and review handoff, especially for Symphony workspaces | `gh --version` |

The loop script defaults to **Codex CLI** (`codex`). To use **Claude Code CLI** instead, set the environment variable `RALPH_CLI=claude` (see [Section 8](#8-create-loopsh) for details).

#### Installing Codex CLI (Default)

```bash
npm install -g @openai/codex
codex login
```

#### Installing Claude Code CLI (Alternative)

```bash
npm install -g @anthropic-ai/claude-code
# Then authenticate by running `claude` interactively once
```

### Required Setup

- The repository must be a **git repository** (run `git init` if it is not).
- The repository must have a **remote configured** if you want auto-push after each loop iteration (run `git remote -v` to check).
- Your chosen CLI must be **authenticated** (run `codex` or `claude` interactively once to verify it works).
- GitHub CLI should be authenticated if agents will open or update PRs (run `gh auth status`).

### Optional for Symphony

Use these when the repo should support the board-driven outer loop:

| Tool / Account | Purpose | Install Check |
|----------------|---------|---------------|
| **Linear project** | Issue board / control plane for agent work | Project URL and slug available |
| **Linear API key** | Lets Symphony read active issues and lets Codex update issue state through Symphony tooling | `echo $LINEAR_API_KEY` |
| **mise** | Recommended runtime manager for the Symphony Elixir reference implementation | `mise --version` |
| **Symphony reference implementation** | Experimental orchestration daemon for evaluation | `test -x ./bin/symphony` from `symphony/elixir` |

Symphony currently assumes Linear for the published workflow contract (`tracker.kind: linear`). If the human wants GitHub Issues instead, do not pretend it is already supported by the reference setup. Treat the first Symphony task as: "Implement a Symphony tracker adapter for GitHub Issues based on `SPEC.md`."

### Recommended

- A **sandbox environment** for running Ralph or Symphony autonomously (Docker, E2B, Fly Sprites, etc.) — see [Section 12](#12-security-sandbox-setup) for details. Ralph runs with permission-bypassing flags (`--dangerously-bypass-approvals-and-sandbox` for Codex, `--dangerously-skip-permissions` for Claude) which bypass all safety prompts. Symphony runs long-lived Codex app-server sessions and should be treated as at least as sensitive.
- **Tests, linting, and/or type-checking** already configured in the project. These provide "backpressure" — the mechanism that forces Ralph to fix issues before committing. Without backpressure, Ralph has no quality gate.

---

## 2. Understand Your Project

**ASK THE HUMAN the following questions before proceeding. You need all of these answers to configure Ralph correctly.**

### Questions to Ask

1. **What is the project-specific goal?**
   - This is the high-level objective that will go into `PROMPT_plan.md`. Examples:
     - "A SaaS platform for managing restaurant reservations"
     - "A CLI tool for converting video formats"
     - "A mobile app for tracking fitness goals"

2. **Where is the application source code located?**
   - Default assumption is `src/`. If the project uses a different structure (e.g. `app/`, `lib/`, `packages/`), you need to know this to update the prompt files.

3. **Where are shared utilities/components located?**
   - Default assumption is `src/lib/`. This is referenced in the planning prompt for Ralph to discover reusable patterns.

4. **What are the project's build/run commands?**
   - Examples: `npm run build`, `cargo build`, `go build ./...`, `python -m build`
   - These go into `AGENTS.md` under "Build & Run".

5. **What are the project's test commands?**
   - Examples: `npm test`, `pytest`, `cargo test`, `go test ./...`
   - If there are both unit and integration tests, get both commands.
   - These go into `AGENTS.md` under "Validation".

6. **What are the project's type-check/lint commands (if any)?**
   - Examples: `npx tsc --noEmit`, `npm run lint`, `mypy .`, `clippy`
   - These go into `AGENTS.md` under "Validation".

7. **Are there any existing Jobs to Be Done (JTBDs) or feature requirements?**
   - If yes, these will become the initial spec files in `specs/`.
   - If no, you will need to help the human define these (see [Section 10](#10-create-specification-files)).

8. **Does the project already have a `CLAUDE.md` or `.claude/` configuration?**
   - If yes, Ralph's `AGENTS.md` will complement but not replace it. `CLAUDE.md` is loaded automatically by Claude Code; `AGENTS.md` is loaded explicitly by the prompt.
   - Note: During setup, `AGENTS.md` is automatically copied to `CLAUDE.md` for maximum CLI compatibility (see [Section 4](#4-create-agentsmd)).

9. **Which CLI tool should Ralph use?**
   - Default: **Codex CLI** (`codex`) — OpenAI's coding agent CLI.
   - Alternative: **Claude Code CLI** (`claude`) — Anthropic's coding agent CLI.
   - The loop script supports both. Set `RALPH_CLI=claude` to switch to Claude Code.

10. **What git branch strategy should Ralph use?**
   - Options: work directly on `main`, work on a dedicated branch (e.g. `ralph/work`), or use feature branches.
   - Default: work on current branch, push after each iteration.

11. **Which model should be used for the primary agent?**
    - For Codex CLI: Uses OpenAI's default model. No `--model` flag needed unless you want to override.
    - For Claude Code CLI:
      - Default: `opus` (best reasoning, slower, more expensive).
      - Alternative: `sonnet` (faster, cheaper, good for well-defined tasks).
      - Recommendation: Use `opus` for planning mode, optionally `sonnet` for building mode if the plan is clear and tasks are well-defined.

12. **Should this repository also support Symphony?**
    - Default: **yes, but start disabled**. Add `WORKFLOW.md` and the documented Linear states, but keep using local Ralph until the repo has specs, tests, and a reviewed plan.
    - If yes, ask the follow-up questions below.

### Additional Questions for Symphony

Ask these only if the human wants the board-driven outer loop.

1. **What Linear project should agents use as the control plane?**
   - Capture the project slug from the Linear project URL.
   - Recommended states: `Todo`, `In Progress`, `Rework`, `Human Review`, `Merging`, `Done`, `Cancelled`, `Duplicate`.

2. **What repository clone URL should new issue workspaces use?**
   - Prefer a deploy-key-friendly SSH URL, e.g. `git@github.com:ORG/REPO.git`.

3. **What workspace root should Symphony use?**
   - Default: `~/code/symphony-workspaces`.
   - Use a dedicated devbox/container path when possible.

4. **What concurrency should Symphony start with?**
   - Default: `agent.max_concurrent_agents: 1`.
   - Increase to `2` or `3` only after a successful smoke test and one real issue.

5. **Is the agent allowed to move issues to `Done`?**
   - Default: no. Agents move completed PRs to `Human Review`; humans decide merge/done.

---

## 3. Create the Directory Structure

Create the following files and directories in the project root. Do **not** overwrite any existing files — only create what doesn't already exist.

### Target Structure

```
project-root/
├── loop.sh                         # Ralph loop script (created in step 8)
├── PROMPT_build.md                 # Build mode instructions (created in step 6)
├── PROMPT_plan.md                  # Plan mode instructions (created in step 5)
├── AGENTS.md                       # Operational guide loaded each iteration (created in step 4)
├── CLAUDE.md                       # Copy of AGENTS.md for Claude Code CLI compatibility (created in step 4)
├── IMPLEMENTATION_PLAN.md          # Prioritized task list - generated by Ralph (created in step 7)
├── WORKFLOW.md                     # Symphony repo contract (created in step 9, optional but recommended)
├── .codex/skills/                  # Optional repo-local skills used by Symphony/Codex
│   ├── commit/
│   ├── push/
│   ├── pull/
│   ├── land/
│   └── linear/
├── specs/                          # Requirement specs - one per JTBD topic (created in step 10)
│   ├── [jtbd-topic-a].md
│   └── [jtbd-topic-b].md
├── src/                            # Application source code (should already exist)
└── src/lib/                        # Shared utilities & components (should already exist)
```

### Commands to Run

```bash
# Create the specs directory if it doesn't exist
mkdir -p specs

# Create src/lib if it doesn't exist (adjust path based on human's answers)
mkdir -p src/lib

# If enabling Symphony, create the optional repo-local skills directory.
# The skill contents can be copied from openai/symphony/.codex when you adopt the reference setup.
mkdir -p .codex/skills
```

**Note:** If the human told you their source code is in a different location (e.g. `app/` instead of `src/`), adjust all paths accordingly in every file you create below.

---

## 4. Create AGENTS.md

`AGENTS.md` is the operational "how to build/run" guide. It is loaded into context at the start of **every** loop iteration. It must be kept **brief** (~60 lines max) and **operational only** — no progress notes, no changelogs.

**ASK THE HUMAN** for their build, test, typecheck, and lint commands if you haven't already (see Section 2, questions 4-6).

### Template

Create `AGENTS.md` in the project root with the following content, replacing the placeholder commands with the actual project commands:

```markdown
## Build & Run

[Insert concise build/run instructions here. Example:]
- Install dependencies: `npm install`
- Run dev server: `npm run dev`
- Build for production: `npm run build`

## Validation

Run these after implementing to get immediate feedback:

- Tests: `[actual test command, e.g. npm test]`
- Typecheck: `[actual typecheck command, e.g. npx tsc --noEmit]`
- Lint: `[actual lint command, e.g. npm run lint]`

## Operational Notes

[Leave empty initially. Ralph will populate this with learnings as it works.]

### Codebase Patterns

[Leave empty initially. Ralph will populate this with patterns it discovers.]
```

### Copy AGENTS.md to CLAUDE.md

After creating `AGENTS.md`, **copy it to `CLAUDE.md`** in the same directory:

```bash
cp AGENTS.md CLAUDE.md
```

**Why both files?**
- `AGENTS.md` is the canonical file referenced explicitly by the Ralph prompts (`@AGENTS.md`). It works with any CLI tool (Codex, Claude, etc.).
- `CLAUDE.md` is automatically loaded by Claude Code CLI when it starts. Having a copy ensures Claude Code gets the operational context even outside of the Ralph loop (e.g. during interactive sessions).

**Important:** When Ralph updates `AGENTS.md` during the loop, it will NOT automatically update `CLAUDE.md`. The loop script handles this — after each iteration, it copies `AGENTS.md` to `CLAUDE.md` to keep them in sync (see [Section 8](#8-create-loopsh)).

### Key Rules for AGENTS.md

- **DO** include build commands, test commands, and validation commands.
- **DO** include any known quirks about running the project (e.g. "must run `npm install` before tests").
- **DO NOT** include progress notes or status updates (those go in `IMPLEMENTATION_PLAN.md`).
- **DO NOT** make it longer than ~60 lines. A bloated `AGENTS.md` pollutes every future loop's context.
- **START with a minimal file.** Ralph will update it with learnings as it works. Resist the urge to front-load it with rules and best practices — let Ralph discover what it needs.

---

## 5. Create PROMPT_plan.md

`PROMPT_plan.md` contains the instructions for **planning mode** — Ralph performs gap analysis (specs vs. code) and generates/updates the implementation plan. It does **not** implement anything.

**ASK THE HUMAN** for their project-specific goal if you haven't already (see Section 2, question 1).

### Template

Create `PROMPT_plan.md` in the project root. Replace the placeholders with actual values:

- Replace `[SOURCE_DIR]` with the source code directory (default: `src`)
- Replace `[LIB_DIR]` with the shared utilities directory (default: `src/lib`)
- Replace `[PROJECT_SPECIFIC_GOAL]` with the human's project-specific goal

```markdown
0a. Study `specs/*` with up to 250 parallel Sonnet subagents to learn the application specifications.
0b. Study @IMPLEMENTATION_PLAN.md (if present) to understand the plan so far.
0c. Study `[LIB_DIR]/*` with up to 250 parallel Sonnet subagents to understand shared utilities & components.
0d. For reference, the application source code is in `[SOURCE_DIR]/*`.

1. Study @IMPLEMENTATION_PLAN.md (if present; it may be incorrect) and use up to 500 Sonnet subagents to study existing source code in `[SOURCE_DIR]/*` and compare it against `specs/*`. Use an Opus subagent to analyze findings, prioritize tasks, and create/update @IMPLEMENTATION_PLAN.md as a bullet point list sorted in priority of items yet to be implemented. Ultrathink. Consider searching for TODO, minimal implementations, placeholders, skipped/flaky tests, and inconsistent patterns. Study @IMPLEMENTATION_PLAN.md to determine starting point for research and keep it up to date with items considered complete/incomplete using subagents.

IMPORTANT: Plan only. Do NOT implement anything. Do NOT assume functionality is missing; confirm with code search first. Treat `[LIB_DIR]` as the project's standard library for shared utilities and components. Prefer consolidated, idiomatic implementations there over ad-hoc copies.

ULTIMATE GOAL: We want to achieve [PROJECT_SPECIFIC_GOAL]. Consider missing elements and plan accordingly. If an element is missing, search first to confirm it doesn't exist, then if needed author the specification at specs/FILENAME.md. If you create a new element then document the plan to implement it in @IMPLEMENTATION_PLAN.md using a subagent.
```

### Key Language Patterns

The specific phrasing in the prompt matters. These patterns have been tested extensively:

- **"study"** — not "read" or "look at". Implies deep analysis.
- **"don't assume not implemented"** — critical. Prevents Ralph from re-implementing existing code.
- **"using parallel subagents"** / **"up to N subagents"** — controls parallelism.
- **"Ultrathink"** — triggers extended thinking mode in Claude. Works with both Codex and Claude CLIs as a general instruction for deeper reasoning.

---

## 6. Create PROMPT_build.md

`PROMPT_build.md` contains the instructions for **building mode** — Ralph picks a task from the implementation plan, implements it, runs tests, and commits.

### Template

Create `PROMPT_build.md` in the project root. Replace `[SOURCE_DIR]` with the source code directory (default: `src`):

```markdown
0a. Study `specs/*` with up to 500 parallel Sonnet subagents to learn the application specifications.
0b. Study @IMPLEMENTATION_PLAN.md.
0c. For reference, the application source code is in `[SOURCE_DIR]/*`.

1. Your task is to implement functionality per the specifications using parallel subagents. Follow @IMPLEMENTATION_PLAN.md and choose the most important item to address. Before making changes, search the codebase (don't assume not implemented) using Sonnet subagents. You may use up to 500 parallel Sonnet subagents for searches/reads and only 1 Sonnet subagent for build/tests. Use Opus subagents when complex reasoning is needed (debugging, architectural decisions).
2. After implementing functionality or resolving problems, run the tests for that unit of code that was improved. If functionality is missing then it's your job to add it as per the application specifications. Ultrathink.
3. When you discover issues, immediately update @IMPLEMENTATION_PLAN.md with your findings using a subagent. When resolved, update and remove the item.
4. When the tests pass, update @IMPLEMENTATION_PLAN.md, then `git add -A` then `git commit` with a message describing the changes. After the commit, `git push`.

99999. Important: When authoring documentation, capture the why — tests and implementation importance.
999999. Important: Single sources of truth, no migrations/adapters. If tests unrelated to your work fail, resolve them as part of the increment.
9999999. As soon as there are no build or test errors create a git tag. If there are no git tags start at 0.0.0 and increment patch by 1 for example 0.0.1  if 0.0.0 does not exist.
99999999. You may add extra logging if required to debug issues.
999999999. Keep @IMPLEMENTATION_PLAN.md current with learnings using a subagent — future work depends on this to avoid duplicating efforts. Update especially after finishing your turn.
9999999999. When you learn something new about how to run the application, update @AGENTS.md using a subagent but keep it brief. For example if you run commands multiple times before learning the correct command then that file should be updated.
99999999999. For any bugs you notice, resolve them or document them in @IMPLEMENTATION_PLAN.md using a subagent even if it is unrelated to the current piece of work.
999999999999. Implement functionality completely. Placeholders and stubs waste efforts and time redoing the same work.
9999999999999. When @IMPLEMENTATION_PLAN.md becomes large periodically clean out the items that are completed from the file using a subagent.
99999999999999. If you find inconsistencies in the specs/* then use an Opus 4.6 subagent with 'ultrathink' requested to update the specs.
999999999999999. IMPORTANT: Keep @AGENTS.md operational only — status updates and progress notes belong in `IMPLEMENTATION_PLAN.md`. A bloated AGENTS.md pollutes every future loop's context.
```

### Understanding the Prompt Structure

| Section | Purpose |
|---------|---------|
| **Phase 0** (0a, 0b, 0c) | Orient: study specs, source location, current plan |
| **Phase 1-4** | Main instructions: pick task, implement, test, commit |
| **99999... numbering** | Guardrails/invariants. Higher number = more critical. These use escalating numbers as a convention to signal importance to the model. |

### Understanding Key Mechanics

- **"only 1 Sonnet subagent for build/tests"** — This is backpressure control. Running builds/tests must be serialized to avoid conflicts and race conditions.
- **"git add -A then git commit"** — Each loop iteration produces exactly one commit for one task.
- **"git push"** — Pushes after each commit so work is preserved even if the loop crashes.
- **The guardrail numbers (99999, 999999, etc.)** — These are not arbitrary. They signal escalating importance. The model treats higher numbers as higher priority invariants.

---

## 7. Create IMPLEMENTATION_PLAN.md

This file is **generated and managed by Ralph**, not by you. Create it as a near-empty placeholder:

```markdown
<!-- Generated by LLM with content and structure it deems most appropriate -->
```

Ralph will populate this file during the first planning mode run. Do not pre-fill it with tasks — let Ralph perform the gap analysis and create the plan.

---

## 8. Create loop.sh

`loop.sh` is the outer loop that repeatedly invokes the AI agent CLI with the prompt file. Each iteration = one fresh context window = one task.

The reference implementation is **Codex-first**: it defaults to **Codex CLI** (`codex`) and exposes a `--fast` toggle that maps to Codex `fast_mode` plus `--effort low|medium|high|xhigh` for Codex reasoning effort. Set `RALPH_CLI=claude` to use Claude Code CLI instead.

### Template

Create `loop.sh` in the project root:

```bash
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
```

### Make It Executable

```bash
chmod +x loop.sh
```

### CLI Selection

The script defaults to **Codex CLI**. To switch to Claude Code CLI:

```bash
# One-time run with Claude
RALPH_CLI=claude ./loop.sh

# Or export for the session
export RALPH_CLI=claude
./loop.sh plan
./loop.sh 20
```

You can also hardcode the default by changing the line near the top of the script:
```bash
RALPH_CLI="${RALPH_CLI:-codex}"    # Change "codex" to "claude" to make Claude the default
```

### Fast Mode (Codex Only)

The reference loop exposes a `--fast` toggle that maps directly to Codex `fast_mode`:

```bash
./loop.sh --fast
./loop.sh plan --fast 2
```

Without `--fast`, the script explicitly passes `--disable fast_mode` so the run mode is always obvious in logs and shell history. `--fast` is rejected when `RALPH_CLI=claude`.

### Thinking Effort (Codex Only)

Set Codex reasoning effort per run with `--effort`:

```bash
./loop.sh --effort high
./loop.sh plan --effort xhigh 2
```

Valid values are `low`, `medium`, `high`, and `xhigh`. The script passes this through as `-c model_reasoning_effort="..."`. `--effort` is rejected when `RALPH_CLI=claude`.

### Model Selection

You can override the model for either CLI with `RALPH_MODEL`:

```bash
# Override Codex's default model
RALPH_MODEL=gpt-5.1-codex-max ./loop.sh --fast

# Use Opus (default) for Claude
RALPH_CLI=claude ./loop.sh plan

# Use Sonnet for Claude when tasks are clear and well-defined
RALPH_CLI=claude RALPH_MODEL=sonnet ./loop.sh 20
```

### Understanding the CLI Flags

#### Codex CLI Flags

| Flag | Purpose |
|------|---------|
| `exec` | **Execution mode.** Non-interactive, reads prompt from stdin. Required for automation. |
| `--enable fast_mode` | **Enable Codex fast mode.** The reference loop adds this when you pass `--fast`. |
| `--disable fast_mode` | **Make the run mode explicit.** The reference loop passes this when `--fast` is not set. |
| `-c model_reasoning_effort="..."` | **Set Codex reasoning effort.** The reference loop adds this when you pass `--effort low`, `medium`, `high`, or `xhigh`. |
| `--dangerously-bypass-approvals-and-sandbox` | **Bypasses all approval prompts and sandbox restrictions.** Required for fully automated runs. This is why a sandbox environment is critical — see [Section 12](#12-security-sandbox-setup). |
| `-` | **Read from stdin.** Tells Codex to read the prompt from the pipe. |

#### Claude Code CLI Flags

| Flag | Purpose |
|------|---------|
| `-p` | **Headless mode.** Non-interactive operation, reads prompt from stdin. Required for automation. |
| `--dangerously-skip-permissions` | **Bypasses all permission prompts.** Required for fully automated runs. This is why a sandbox is critical — see [Section 12](#12-security-sandbox-setup). |
| `--output-format=stream-json` | **Structured output.** Enables logging and monitoring of the loop's progress. |
| `--model opus` | **Primary model.** Opus for complex reasoning (task selection, prioritization, coordination). |
| `--verbose` | **Detailed logging.** Provides visibility into what the agent is doing. |

---

## 9. Create WORKFLOW.md for Symphony

`WORKFLOW.md` is the repo-owned Symphony contract. It combines YAML front matter for runtime settings with a Markdown prompt body for the per-issue Codex session.

Reference docs:

- OpenAI Symphony announcement: https://openai.com/index/open-source-codex-orchestration-symphony/
- Symphony spec: https://github.com/openai/symphony/blob/main/SPEC.md
- Elixir reference implementation: https://github.com/openai/symphony/blob/main/elixir/README.md

Ralph and Symphony should share the same repository signs:

- `AGENTS.md` remains the short operational guide.
- `specs/*` remain the product and technical requirements.
- `IMPLEMENTATION_PLAN.md` remains supporting state.
- `WORKFLOW.md` makes the Linear issue the immediate scope for unattended work.

### When to Create It

Create `WORKFLOW.md` by default for new repos, even if Symphony will not run on day one. It is cheap to keep versioned and makes the repo ready for a later daemon rollout.

Do **not** run Symphony until:

- `AGENTS.md` has accurate install, build, test, lint, and typecheck commands.
- At least one meaningful spec exists in `specs/`.
- `./loop.sh plan` has produced a reviewed `IMPLEMENTATION_PLAN.md`.
- The repo can be cloned and validated in a disposable workspace.
- GitHub CLI and Linear authentication are available in the sandbox/devbox where Symphony will run.

### Linear Workflow States

Create or customize a Linear project for agent work with these states:

| Linear state | Meaning |
|--------------|---------|
| `Todo` | Symphony may pick it up |
| `In Progress` | Agent is actively working |
| `Rework` | Agent should address feedback |
| `Human Review` | PR is ready for human review |
| `Merging` | Agent may shepherd CI/rebase/merge if allowed |
| `Done` | Terminal; workspace can be cleaned |
| `Cancelled` / `Duplicate` | Terminal; stop work |

The reference Symphony setup uses non-standard states such as `Rework`, `Human Review`, and `Merging`. Add them in Linear Team Settings -> Workflow before relying on this template.

### Template

Create `WORKFLOW.md` in the project root. If you are setting up from this playbook repo, copy `files/WORKFLOW.md` first and then replace:

- `your-linear-project-slug` with the Linear project slug.
- `YOUR_ORG/YOUR_REPO` with the GitHub repo path.
- `~/code/symphony-workspaces` with the chosen isolated workspace root if different.

```markdown
---
tracker:
  kind: linear
  api_key: $LINEAR_API_KEY
  project_slug: "your-linear-project-slug"
  active_states:
    - Todo
    - In Progress
    - Rework
  terminal_states:
    - Done
    - Closed
    - Cancelled
    - Canceled
    - Duplicate
  claim_state: In Progress
  handoff_state: Human Review
  rework_state: Rework
  merging_state: Merging

polling:
  interval_ms: 30000

workspace:
  root: ~/code/symphony-workspaces

hooks:
  after_create: |
    git clone git@github.com:YOUR_ORG/YOUR_REPO.git .
  before_run: |
    git fetch origin
    git status
    test -f AGENTS.md
    test -f IMPLEMENTATION_PLAN.md || touch IMPLEMENTATION_PLAN.md
  after_run: |
    git status

agent:
  max_concurrent_agents: 1
  max_turns: 10
  max_retry_backoff_ms: 300000

codex:
  command: symphony-codex app-server
  approval_policy: never
  thread_sandbox: workspace-write
  turn_sandbox_policy:
    type: workspaceWrite
  turn_timeout_ms: 3600000
  stall_timeout_ms: 300000
---

You are working on Linear issue {{ issue.identifier }}.

Title:
{{ issue.title }}

Description:
{{ issue.description }}

The Linear issue is the source of immediate scope.
IMPLEMENTATION_PLAN.md is supporting context.
Do not wander outside the issue unless needed to satisfy acceptance criteria.

Operate like a Ralph build iteration, but scoped to this Linear issue.

Read:
- AGENTS.md for operational instructions
- specs/* for product and technical requirements
- IMPLEMENTATION_PLAN.md if present
- the existing source code before assuming anything is missing

Rules:
1. Create or checkout a branch named from the issue identifier.
2. Understand the issue and confirm whether it maps to an existing spec or plan item.
3. Do not assume functionality is missing; search first.
4. Implement the smallest complete increment that satisfies this issue.
5. Add or update tests derived from the acceptance criteria.
6. Run the relevant tests, type checks, linters, and builds from AGENTS.md.
7. Keep IMPLEMENTATION_PLAN.md current with discoveries and remaining work.
8. Keep AGENTS.md operational only; add only durable build/test/run learnings.
9. Commit the work with a message including {{ issue.identifier }}.
10. Push the branch.
11. Open or update a PR using gh.
12. Comment on the Linear issue with:
    - PR link
    - validation run
    - remaining risks
    - what needs human review
13. Move the issue to Human Review when the PR is ready.

Do not mark the issue Done yourself unless the repository workflow explicitly allows it.
If the issue is too large, create child Linear issues and stop at Human Review with a planning summary.
```

### Optional Repo-Local Codex Skills

If using the OpenAI Symphony Elixir reference implementation, optionally copy these skills from the Symphony repo into the target repo:

```text
.codex/skills/commit/
.codex/skills/push/
.codex/skills/pull/
.codex/skills/land/
.codex/skills/linear/
```

The `linear` skill expects Symphony's `linear_graphql` app-server tool. Use it for raw Linear operations such as comments, status changes, and upload flows without exposing the Linear token directly to normal shell commands.

### Setup the Symphony Reference Implementation

The OpenAI repo presents two paths:

1. Build a hardened implementation from `SPEC.md` in your preferred stack.
2. Evaluate the experimental Elixir implementation.

For a trial:

```bash
git clone https://github.com/openai/symphony
cd symphony/elixir

mise trust
mise install
mise exec -- mix setup
mise exec -- mix build
```

Set the Linear token in the environment where Symphony runs:

```bash
export LINEAR_API_KEY="lin_api_..."
```

For repeated local use, keep the token in a private env file outside the repo
instead of exporting it by hand or committing it:

```bash
mkdir -p ~/.config/ralph-symphony
chmod 700 ~/.config/ralph-symphony
umask 077
printf 'export LINEAR_API_KEY=%q\n' 'lin_api_...' > ~/.config/ralph-symphony/env
chmod 600 ~/.config/ralph-symphony/env
```

Do not put a real `lin_api_...` token in `WORKFLOW.md`, `AGENTS.md`, this
playbook repo, or any project repo. `WORKFLOW.md` should keep using
`api_key: $LINEAR_API_KEY`.

Install the global Codex wrapper so all Symphony projects on the VM can share
one model, reasoning effort, and fast-mode setting:

```bash
install -m 755 /path/to/ralph-playbook/files/symphony-codex ~/.local/bin/symphony-codex
```

Add or edit these VM-wide settings in `~/.config/ralph-symphony/env`:

```bash
export SYMPHONY_CODEX_MODEL="gpt-5.5"
export SYMPHONY_CODEX_EFFORT="low"       # low, medium, high, or xhigh
export SYMPHONY_CODEX_FAST_MODE="false"  # true or false
```

`WORKFLOW.md` should call the wrapper:

```yaml
codex:
  command: symphony-codex app-server
```

Changing those three env vars changes the Codex model settings for every repo
whose workflow uses `symphony-codex app-server`.

Run Symphony against this repo's workflow file:

```bash
mise exec -- ./bin/symphony /path/to/your/repo/WORKFLOW.md
```

To enable the optional observability service:

```bash
mise exec -- ./bin/symphony /path/to/your/repo/WORKFLOW.md --port 4000
```

The current Elixir preview may require an explicit guardrails acknowledgement
flag before it will run:

```bash
mise exec -- ./bin/symphony /path/to/your/repo/WORKFLOW.md --port 4000 --i-understand-that-this-will-be-running-without-the-usual-guardrails
```

### One-Word Symphony Helper

For day-to-day use, add the helper from `files/symphony-bashrc.sh` to your
shell startup file:

```bash
cat /path/to/ralph-playbook/files/symphony-bashrc.sh >> ~/.bashrc
source ~/.bashrc
```

Then run Symphony from any repo that has a `WORKFLOW.md`:

```bash
cd /path/to/your/repo
symphony --i-understand-that-this-will-be-running-without-the-usual-guardrails
```

The helper:

- sources `~/.config/ralph-symphony/env` so `LINEAR_API_KEY` is loaded
- uses the current directory's `WORKFLOW.md` by default
- runs Symphony from `$SYMPHONY_DIR` or `~/dev/symphony/elixir`
- auto-selects the first free dashboard port starting at `4000`
- passes through Symphony CLI flags such as
  `--i-understand-that-this-will-be-running-without-the-usual-guardrails`
- still allows overrides:

```bash
SYMPHONY_DIR=/path/to/symphony/elixir symphony
SYMPHONY_PORT=4010 symphony
symphony /path/to/other/WORKFLOW.md --i-understand-that-this-will-be-running-without-the-usual-guardrails
```

### Smoke Test Issue

Before assigning real work, create one low-risk Linear issue:

```text
Verify Symphony can clone the repo, read AGENTS.md, run validation, and open a no-op PR updating docs/symphony-smoke-test.md.
```

Keep `agent.max_concurrent_agents: 1` until this smoke test and one real issue complete cleanly.

## 10. Create Specification Files

Specs are the source of truth for what should be built. Each spec covers one **topic of concern** — a distinct aspect of a Job to Be Done (JTBD).

### Understanding the Hierarchy

```
1 JTBD (high-level user need)
  └── multiple Topics of Concern (distinct aspects)
        └── 1 Spec file per topic (specs/topic-name.md)
              └── multiple Tasks (derived during planning, put in IMPLEMENTATION_PLAN.md)
```

### Topic Scope Test

A topic of concern should be describable in **one sentence without "and"**:

- **Good:** "The color extraction system analyzes images to identify dominant colors"
- **Bad:** "The user system handles authentication, profiles, and billing" → this is 3 topics

### Creating Specs

**ASK THE HUMAN** the following:

1. **What are the main Jobs to Be Done (user needs/outcomes) for this project?**
2. **For each JTBD, what are the distinct topics of concern?**
3. **For each topic, what are the requirements, constraints, and acceptance criteria?**

If the human has vague or minimal requirements, you can use Claude's `AskUserQuestion` tool to interview them systematically:

> "Interview me to understand [the JTBD/topic/acceptance criteria]. Ask targeted questions to clarify requirements before I write the spec."

### Spec File Template

There is **no prescribed template** — let the content dictate the format. However, a typical spec might include:

```markdown
# [Topic Name]

## Overview
[What this topic covers and why it matters]

## Requirements
- [Requirement 1]
- [Requirement 2]
- ...

## Acceptance Criteria
- [Observable, verifiable outcome 1]
- [Observable, verifiable outcome 2]
- ...

## Constraints
- [Any technical constraints, performance requirements, etc.]

## Edge Cases
- [Known edge cases to handle]
```

### File Naming

- Use kebab-case: `specs/color-extraction.md`, `specs/user-authentication.md`
- One file per topic of concern
- Place all spec files in the `specs/` directory

### Example

For a JTBD of "Help designers create mood boards":

```
specs/
├── image-collection.md      # Topic: collecting and uploading images
├── color-extraction.md      # Topic: extracting colors from images
├── layout-arrangement.md    # Topic: arranging elements on a board
└── sharing-export.md        # Topic: sharing and exporting mood boards
```

---

## 11. Update .gitignore

Ensure none of the workflow files are accidentally ignored by git. Ralph files (`AGENTS.md`, `CLAUDE.md`, `PROMPT_plan.md`, `PROMPT_build.md`, `IMPLEMENTATION_PLAN.md`, `loop.sh`, and `specs/`) and the Symphony file (`WORKFLOW.md`) should be **tracked by git** — they are part of the project's workflow.

Check the existing `.gitignore` and make sure it does not exclude any of these files.

No Ralph-specific entries need to be **added** to `.gitignore` unless you have a specific reason (e.g. log files from `--output-format=stream-json` if you redirect output to a file).

For Symphony, do not commit local workspace or daemon output directories. Add entries only if those paths live inside the repository:

```gitignore
symphony-workspaces/
log/
```

---

## 12. Security: Sandbox Setup

**This section is critical.** Ralph runs with dangerous permission-bypassing flags (`--dangerously-bypass-approvals-and-sandbox` for Codex, `--dangerously-skip-permissions` for Claude), which means it can execute any command, read any file, and make any network request without asking for approval. This bypasses the CLI's entire permission system.

Symphony is also high trust. It runs as a long-lived daemon, creates workspaces, launches Codex app-server sessions, and lets agents push branches, open PRs, and update Linear. Do not run it on a personal laptop with all personal credentials exposed.

### The Philosophy

> "It's not if it gets popped, it's when. And what is the blast radius?"

Running Ralph or Symphony without isolation exposes:
- Your API keys and credentials
- Browser cookies and session tokens
- SSH keys
- Access tokens for any service your machine can reach

### Minimum Viable Security

At a minimum, autonomous loops should run in an environment with:

- **Only the API keys needed for the task** (OpenAI/Anthropic API key, Linear token, GitHub deploy key)
- **No personal SSH key**
- **No browser cookies**
- **No production secrets** unless the task truly needs them
- **No access to private data** beyond what the task requires
- **Restricted network connectivity** where possible

Recommended Symphony setup:

```text
Dedicated devbox or container
Dedicated GitHub deploy key
Dedicated Linear token for the agent workspace
GitHub CLI authenticated only for the target org/repo
WORKFLOW.md starts with max_concurrent_agents: 1
```

### Sandbox Options

**ASK THE HUMAN** which sandbox approach they want to use for Ralph and, separately, where Symphony should run:

| Option | Best For | Setup Effort |
|--------|----------|--------------|
| **Docker (local)** | Local dev, prototyping | Low |
| **E2B (cloud)** | Production, CI/CD | Low |
| **Fly Sprites (cloud)** | Long-running persistent agents | Low |
| **exe.dev (cloud)** | SSH-native persistent environments | Very Low |
| **Modal (cloud)** | Python ML/AI workloads | Low |
| **No sandbox (YOLO)** | Quick testing only — NOT recommended | None |

#### Docker (Simplest Local Option)

```bash
docker sandbox run claude                  # Basic
docker sandbox run -w ~/my-project claude  # With your project mounted
docker sandbox run claude "your task"      # With initial prompt
```

- Base image includes: Node.js, Python 3, Go, Git, Docker CLI, GitHub CLI, ripgrep, jq
- `--dangerously-skip-permissions` enabled by default inside the sandbox
- Container persists in background; re-running reuses same container

#### E2B (Simplest Cloud Option)

- Pre-built `anthropic-claude-code` template — zero setup
- 24-hour session limits on Pro plan
- Full filesystem + git support
- ~$0.05/hour

#### Running Without a Sandbox

If the human chooses to run without a sandbox (not recommended), they should at minimum:

1. Work on a dedicated branch, not `main`
2. Have `git reset --hard` ready as an escape hatch
3. Monitor the loop's progress (especially early iterations)
4. Use `Ctrl+C` to stop the loop at any time
5. Not store sensitive credentials in the project directory

### Escape Hatches

Regardless of sandbox choice, these escape hatches are always available:

| Action | Command |
|--------|---------|
| **Stop the loop** | `Ctrl+C` in the terminal running `loop.sh` |
| **Revert uncommitted changes** | `git checkout .` or `git reset --hard` |
| **Revert last commit** | `git reset --soft HEAD~1` |
| **Regenerate the plan** | Delete `IMPLEMENTATION_PLAN.md` and re-run `./loop.sh plan` |

---

## 13. First Run: Planning Mode

Planning mode performs gap analysis — it compares your specs against your existing code and generates a prioritized implementation plan. **Always run planning mode first before building.**

### Pre-flight Checklist

Before running, verify all files are in place:

- [ ] `AGENTS.md` exists with correct build/test/lint commands
- [ ] `CLAUDE.md` exists (copy of `AGENTS.md`)
- [ ] `PROMPT_plan.md` exists with correct paths and project goal
- [ ] `PROMPT_build.md` exists with correct paths
- [ ] `IMPLEMENTATION_PLAN.md` exists (even if just a placeholder comment)
- [ ] `WORKFLOW.md` exists if this repo will use Symphony
- [ ] `specs/` directory exists with at least one spec file
- [ ] `loop.sh` exists and is executable (`chmod +x loop.sh`)
- [ ] Your chosen CLI is installed and authenticated (`codex --version` or `claude --version`)
- [ ] Git remote is configured (`git remote -v`)
- [ ] GitHub CLI is authenticated if PR creation is part of the workflow (`gh auth status`)
- [ ] You are on the correct branch

### Run Planning Mode

```bash
./loop.sh plan
```

Or with a max iteration limit (planning often completes in 1-2 iterations):

```bash
./loop.sh plan 3
```

### What Happens During Planning

1. Ralph reads all spec files in `specs/*`
2. Ralph reads the existing source code
3. Ralph compares specs against code (gap analysis)
4. Ralph creates/updates `IMPLEMENTATION_PLAN.md` with a prioritized list of tasks
5. Ralph does **NOT** implement anything
6. Ralph commits and pushes the updated plan

### After Planning

1. **Review the generated `IMPLEMENTATION_PLAN.md`** — does it make sense? Are priorities correct?
2. If the plan is wrong or incomplete, you can:
   - Edit `IMPLEMENTATION_PLAN.md` manually
   - Update specs and re-run planning
   - Delete `IMPLEMENTATION_PLAN.md` and re-run planning from scratch
3. The plan is **disposable** — regenerating it costs one planning loop, which is cheap.

---

## 14. Building Mode

Building mode picks tasks from `IMPLEMENTATION_PLAN.md`, implements them, runs tests, and commits. Each loop iteration handles exactly one task with a fresh context window.

### Run Building Mode

```bash
# Unlimited iterations (runs until all tasks done or you Ctrl+C)
./loop.sh

# Max 20 iterations (20 tasks)
./loop.sh 20
```

### What Happens During Each Build Iteration

1. **Orient** — Ralph studies specs (requirements)
2. **Read plan** — Ralph studies `IMPLEMENTATION_PLAN.md`
3. **Select** — Ralph picks the most important task
4. **Investigate** — Ralph studies relevant source code ("don't assume not implemented")
5. **Implement** — Ralph implements the task using subagents
6. **Validate** — Ralph runs tests/build (backpressure). If tests fail, Ralph fixes and retries within the same iteration.
7. **Update `IMPLEMENTATION_PLAN.md`** — marks task done, notes discoveries/bugs
8. **Update `AGENTS.md`** — if Ralph learned something operational (e.g. the correct command to run tests)
9. **Commit & Push** — one commit per task
10. **Loop ends** — context is cleared, next iteration starts fresh

### Monitoring the Loop

- Watch the terminal output for progress
- Check git log for commits: `git log --oneline -20`
- Review `IMPLEMENTATION_PLAN.md` for task progress
- Review `AGENTS.md` for operational learnings

### When to Stop and Intervene

- **Ralph is going in circles** — implementing the same thing repeatedly. Stop, review the plan, regenerate if needed.
- **Ralph is implementing wrong things** — the plan may be stale or wrong. Regenerate it.
- **Tests keep failing** — the backpressure may be misconfigured. Check `AGENTS.md` for correct test commands.
- **Ralph is generating wrong code patterns** — add correct patterns/utilities to your codebase for Ralph to discover and follow.

---

## 15. Symphony Outer Loop

Use Symphony for issue-sized unattended work after the local Ralph scaffold works. Symphony should not replace Ralph at first; treat it as a daemonized version of "build one scoped thing, test it, commit it, push it, open a PR."

### What Symphony Adds

```text
tracker polling
per-issue workspaces
bounded concurrency
Codex app-server sessions
stall/retry/reconciliation
human-review handoff
```

The practical division of labor:

| Tool | Use it for |
|------|------------|
| `codex` / `./loop.sh` | Local work, deliberate planning, small supervised batches |
| `./loop.sh plan` | Generating or refreshing `IMPLEMENTATION_PLAN.md` from specs and code |
| Symphony | Turning reviewed Linear issues into isolated branches, PRs, validation summaries, and `Human Review` handoff |

### Run Symphony

From the Symphony reference checkout:

```bash
cd /path/to/symphony/elixir
export LINEAR_API_KEY="lin_api_..."

# Start the daemon with the repo-owned workflow file.
mise exec -- ./bin/symphony /path/to/your/repo/WORKFLOW.md

# Optional dashboard/API.
mise exec -- ./bin/symphony /path/to/your/repo/WORKFLOW.md --port 4000
```

If you installed the one-word shell helper from Section 9, use this instead:

```bash
cd /path/to/your/repo
symphony --i-understand-that-this-will-be-running-without-the-usual-guardrails
```

Run the same `symphony` helper in multiple repos if needed. The helper
auto-selects the first free dashboard port starting at `4000`, so parallel
Symphony daemons do not collide on the observability port. The port does not
define work scope; the `WORKFLOW.md` in the current repo does.

### Issue Scope Rule

For Symphony, the Linear issue is the outer scope. `IMPLEMENTATION_PLAN.md` is supporting context only.

Agents should not grab unrelated "most important" plan items just because they appear in `IMPLEMENTATION_PLAN.md`. If an issue is too large, the agent should create child Linear issues, comment with a planning summary, and move the parent to `Human Review` instead of attempting a sprawling implementation.

### Recommended Rollout

1. **Day 1: Evaluation**
   - Set up Linear states and `WORKFLOW.md`.
   - Run the smoke-test issue with `agent.max_concurrent_agents: 1`.

2. **Day 2: One real issue**
   - Use one small bug or docs task.
   - Require a PR, validation summary, and `Human Review` state.

3. **Day 3: Planning issue**
   - Create one planning issue: "Analyze repo and specs; produce implementation plan and child issues."
   - Let the agent update `specs/*`, `IMPLEMENTATION_PLAN.md`, and child Linear issues.
   - Review before moving child issues to `Todo`.

4. **Week 1: Parallelization**
   - Raise concurrency to `2`.
   - Add CI/rebase/merge rules only after branch, PR, comments, and validation are reliable.
   - Tune `AGENTS.md` and `WORKFLOW.md` from observed failures.

### Large Feature Flow

```text
Human idea
  ↓
Create one Linear planning issue
  ↓
Symphony/Codex creates or updates:
  - specs/*
  - IMPLEMENTATION_PLAN.md
  - child Linear issues with dependencies
  ↓
Human reviews the plan
  ↓
Move child issues to Todo
  ↓
Symphony fans out across isolated workspaces
```

### Stop Conditions

Stop the Symphony daemon or reduce concurrency if:

- Agents open PRs without meaningful validation.
- Multiple issues touch the same files and produce avoidable conflicts.
- Agents repeatedly move outside issue scope.
- `AGENTS.md` or `WORKFLOW.md` starts collecting status notes instead of durable operating instructions.
- Linear comments are missing PR links, validation commands, risks, or review instructions.

---

## 16. Ongoing Operation & Tuning

### The Tuning Philosophy

Ralph's effectiveness comes from iterative tuning, not prescriptive upfront configuration.

> "Tune it like a guitar" — observe and adjust reactively. When Ralph fails a specific way, add a sign to help it next time.

### What to Tune and Where

| Problem | Solution | Where |
|---------|----------|-------|
| Ralph uses wrong patterns | Add correct utility/pattern to codebase | `src/lib/` |
| Ralph runs wrong commands | Update build/test commands | `AGENTS.md` |
| Ralph implements wrong things | Regenerate plan | `IMPLEMENTATION_PLAN.md` |
| Ralph ignores requirements | Clarify or update specs | `specs/*.md` |
| Ralph makes a recurring mistake | Add a guardrail instruction | `PROMPT_build.md` |
| Ralph's plan is stale | Delete and regenerate | `./loop.sh plan` |
| Symphony agents drift outside issue scope | Tighten issue-scope rule and handoff instructions | `WORKFLOW.md` |
| Symphony agents collide on files | Lower concurrency or split issues with clearer dependencies | Linear + `WORKFLOW.md` |
| Linear comments are incomplete | Add exact handoff checklist | `WORKFLOW.md` |

### Signs Ralph Can Discover

Ralph steers itself by discovering signals in its environment. These aren't just prompt text:

- **Prompt guardrails** — explicit instructions in `PROMPT_build.md`
- **Workflow guardrails** — issue scope, branch, PR, Linear handoff instructions in `WORKFLOW.md`
- **AGENTS.md** — operational learnings about how to build/test
- **Utilities in codebase** — when you add a pattern to `src/lib/`, Ralph discovers it and follows it
- **Existing code patterns** — Ralph imitates what it finds
- **Tests** — backpressure that rejects invalid work

### When to Regenerate the Plan

Regenerate `IMPLEMENTATION_PLAN.md` when:

- Ralph is going off track (implementing wrong things, duplicating work)
- Plan feels stale or doesn't match current state
- Too much clutter from completed items
- You've made significant spec changes
- You're confused about what's actually done

To regenerate:
```bash
# Option 1: Delete and re-plan
rm IMPLEMENTATION_PLAN.md
./loop.sh plan

# Option 2: Just re-plan (Ralph will update the existing plan)
./loop.sh plan
```

---

## 17. Optional Enhancements

These are additional enhancements that can be added on top of the core Ralph setup. Each is independent and optional.

### A. Acceptance-Driven Backpressure

Derives test requirements during planning from acceptance criteria. Prevents Ralph from claiming tasks are done without appropriate tests passing.

#### To Enable

1. **Add to `PROMPT_plan.md`** — after the first sentence of instruction 1, add:

```markdown
For each task in the plan, derive required tests from acceptance criteria in specs - what specific outcomes need verification (behavior, performance, edge cases). Tests verify WHAT works, not HOW it's implemented. Include as part of task definition.
```

2. **Add to `PROMPT_build.md`** — after "choose the most important item to address" in instruction 1, add:

```markdown
Tasks include required tests - implement tests as part of task scope.
```

3. **Replace instruction 2 in `PROMPT_build.md`** — change "run the tests for that unit of code" to:

```markdown
run all required tests specified in the task definition. All required tests must exist and pass before the task is considered complete.
```

4. **Add guardrail to `PROMPT_build.md`** — add before the existing 99999 line:

```markdown
999. Required tests derived from acceptance criteria must exist and pass before committing. Tests are part of implementation scope, not optional. Test-driven development approach: tests can be written first or alongside implementation.
```

5. **Ensure your specs include acceptance criteria** — each spec file should have a section describing observable, verifiable outcomes (see Section 10).

### B. Work Branches (Scoped Planning)

Enables creating scoped implementation plans per branch, instead of one monolithic plan.

#### To Enable

1. **Create `PROMPT_plan_work.md`** in the project root. This is identical to `PROMPT_plan.md` but with scoping instructions. Replace `[SOURCE_DIR]` and `[LIB_DIR]` with actual values:

```markdown
0a. Study `specs/*` with up to 250 parallel Sonnet subagents to learn the application specifications.
0b. Study @IMPLEMENTATION_PLAN.md (if present) to understand the plan so far.
0c. Study `[LIB_DIR]/*` with up to 250 parallel Sonnet subagents to understand shared utilities & components.
0d. For reference, the application source code is in `[SOURCE_DIR]/*`.

1. You are creating a SCOPED implementation plan for work: "${WORK_SCOPE}". Study @IMPLEMENTATION_PLAN.md (if present; it may be incorrect) and use up to 500 Sonnet subagents to study existing source code in `[SOURCE_DIR]/*` and compare it against `specs/*`. Use an Opus subagent to analyze findings, prioritize tasks, and create/update @IMPLEMENTATION_PLAN.md as a bullet point list sorted in priority of items yet to be implemented. Ultrathink. Consider searching for TODO, minimal implementations, placeholders, skipped/flaky tests, and inconsistent patterns. Study @IMPLEMENTATION_PLAN.md to determine starting point for research and keep it up to date with items considered complete/incomplete using subagents.

IMPORTANT: This is SCOPED PLANNING for "${WORK_SCOPE}" only. Create a plan containing ONLY tasks directly related to this work scope. Be conservative - if uncertain whether a task belongs to this work, exclude it. The plan can be regenerated if too narrow. Plan only. Do NOT implement anything. Do NOT assume functionality is missing; confirm with code search first. Treat `[LIB_DIR]` as the project's standard library for shared utilities and components. Prefer consolidated, idiomatic implementations there over ad-hoc copies.

ULTIMATE GOAL: We want to achieve the scoped work "${WORK_SCOPE}". Consider missing elements related to this work and plan accordingly. If an element is missing, search first to confirm it doesn't exist, then if needed author the specification at specs/FILENAME.md. If you create a new element then document the plan to implement it in @IMPLEMENTATION_PLAN.md using a subagent.
```

2. **Replace `loop.sh`** with the extended version that supports `plan-work` mode. The extended script adds:
   - `plan-work` mode: `./loop.sh plan-work "description of the work"`
   - Branch validation (plan-work won't run on main/master)
   - `envsubst` to substitute `${WORK_SCOPE}` into the prompt
   - Requires `envsubst` to be installed (part of `gettext` package)

Install `envsubst` if needed:
```bash
# Debian/Ubuntu
sudo apt-get install gettext-base

# macOS
brew install gettext

# Alpine
apk add gettext
```

3. **Workflow:**

```bash
# 1. Full planning on main
./loop.sh plan

# 2. Create work branch
git checkout -b ralph/user-auth-oauth

# 3. Create scoped plan
./loop.sh plan-work "user authentication system with OAuth and session management"

# 4. Build from scoped plan
./loop.sh 20

# 5. Create PR when done
gh pr create --base main --head ralph/user-auth-oauth --fill
```

---

## 18. Troubleshooting

### Common Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| `Error: PROMPT_plan.md not found` | Wrong working directory or file not created | `cd` to project root; verify file exists |
| `codex: command not found` | Codex CLI not installed or not in PATH | `npm install -g @openai/codex`; check `which codex` |
| `claude: command not found` | Claude Code CLI not installed or not in PATH | `npm install -g @anthropic-ai/claude-code`; check `which claude` |
| `git push` fails | No remote configured or auth issues | Run `git remote -v`; configure remote and credentials |
| Ralph doesn't find specs | Specs directory empty or wrong path in prompt | Create spec files in `specs/`; verify path in `PROMPT_plan.md` |
| Ralph implements nothing (planning mode) | This is correct behavior | Planning mode only creates the plan; switch to build mode |
| Ralph goes in circles | Stale plan or unclear specs | Regenerate `IMPLEMENTATION_PLAN.md`; clarify specs |
| Tests always fail | Wrong test commands in `AGENTS.md` | Verify and fix test commands; run them manually first |
| Ralph ignores `AGENTS.md` | `AGENTS.md` not referenced in prompt | The prompt references `@AGENTS.md` — ensure file exists at project root |
| Context window errors | Too many/large spec files | Reduce spec verbosity; split large specs; keep each spec focused |
| Ralph duplicates existing code | Missing "don't assume not implemented" | Ensure this phrase is in both prompts |
| Symphony does not pick up issues | Missing Linear token, wrong project slug, or state not active | Check `LINEAR_API_KEY`, `tracker.project_slug`, and `tracker.active_states` in `WORKFLOW.md` |
| Symphony fails at startup | Missing or invalid `WORKFLOW.md` YAML | Run with the explicit workflow path and fix front matter indentation |
| Workspace clone fails | Bad repo URL or missing deploy key | Verify `hooks.after_create` manually in a clean directory |
| Agent cannot open PRs | `gh` not authenticated in the Symphony environment | Run `gh auth status` and authenticate only the target org/repo |
| Agents work on unrelated tasks | `WORKFLOW.md` lets plan priority override issue scope | Re-emphasize that Linear issue scope wins and plan is supporting context |

### Emergency Recovery

```bash
# Stop the loop immediately
Ctrl+C

# Revert all uncommitted changes
git checkout .

# Revert the last N commits (keeps changes staged)
git reset --soft HEAD~N

# Hard reset to a known good state
git reset --hard <commit-hash>

# Regenerate the plan from scratch
rm IMPLEMENTATION_PLAN.md
echo '<!-- Generated by LLM -->' > IMPLEMENTATION_PLAN.md
./loop.sh plan
```

---

## 19. Quick Reference

### File Summary

| File | Created By | Updated By | Purpose |
|------|-----------|------------|---------|
| `loop.sh` | You (once) | You (if needed) | Outer loop script |
| `PROMPT_plan.md` | You (once) | You (tuning) | Planning mode instructions |
| `PROMPT_build.md` | You (once) | You (tuning) | Building mode instructions |
| `AGENTS.md` | You (initial) | Ralph + You | Operational guide (build/test commands) |
| `CLAUDE.md` | You (initial) | loop.sh (auto-synced from `AGENTS.md`) | Copy of AGENTS.md for Claude Code CLI compatibility |
| `IMPLEMENTATION_PLAN.md` | Ralph | Ralph | Prioritized task list |
| `WORKFLOW.md` | You (initial) | You + agents (tuning only) | Symphony runtime config and per-issue prompt |
| `specs/*.md` | You + LLM | Rarely (Ralph can fix inconsistencies) | Requirements per topic of concern |
| `.codex/skills/*` | You (optional) | You | Repo-local Codex skills for commit/push/pull/land/Linear workflows |

### Command Reference

```bash
# Planning mode (generates/updates IMPLEMENTATION_PLAN.md)
./loop.sh plan          # Unlimited iterations (uses Codex by default)
./loop.sh plan 3        # Max 3 iterations
./loop.sh plan --fast 2 # Max 2 iterations with Codex fast mode enabled
./loop.sh plan --effort xhigh 2 # Max 2 iterations with xhigh Codex reasoning effort

# Building mode (implements tasks from plan)
./loop.sh               # Unlimited iterations
./loop.sh 20            # Max 20 iterations (20 tasks)
./loop.sh --fast        # Unlimited iterations with Codex fast mode enabled
./loop.sh --effort high # Unlimited iterations with high Codex reasoning effort

# Use Claude Code CLI instead of Codex
RALPH_CLI=claude ./loop.sh plan
RALPH_CLI=claude RALPH_MODEL=sonnet ./loop.sh 20

# Stop the loop
Ctrl+C

# Regenerate the plan
rm IMPLEMENTATION_PLAN.md && ./loop.sh plan

# Run Symphony from the reference implementation checkout
cd /path/to/symphony/elixir
export LINEAR_API_KEY="lin_api_..."
mise exec -- ./bin/symphony /path/to/your/repo/WORKFLOW.md --port 4000

# Check progress
git log --oneline -20
cat IMPLEMENTATION_PLAN.md
cat AGENTS.md
cat WORKFLOW.md
```

### Lifecycle Summary

```
1. DEFINE REQUIREMENTS
   Human + LLM conversation → specs/*.md
   (One spec per JTBD topic of concern)

2. PLAN (./loop.sh plan)
   Ralph reads specs + code → gap analysis → IMPLEMENTATION_PLAN.md
   (No implementation, no commits to source code)

3. BUILD (./loop.sh)
   Ralph picks task → implements → tests → commits → next task
   (One task per iteration, fresh context each time)

4. ORCHESTRATE (Symphony, optional)
   Linear issue → isolated workspace → Codex app-server → branch/PR/comment/Human Review
   (One issue per workspace, bounded concurrency)

5. TUNE (ongoing)
   Observe Ralph → adjust AGENTS.md, prompts, specs, utilities
   Observe Symphony → adjust WORKFLOW.md, Linear issue shape, concurrency
   Regenerate plan when stale
```

### The Core Insight

Ralph is a **dumb bash loop** that keeps restarting an AI agent with a fresh context window. The agent figures out what to do next by reading the plan file each time. No sophisticated orchestration needed — just:

```bash
# With Codex (default)
while :; do cat PROMPT.md | codex exec --dangerously-bypass-approvals-and-sandbox - ; done

# With Claude
while :; do cat PROMPT.md | claude -p --dangerously-skip-permissions ; done
```

Everything else — CLI selection, mode selection, iteration limits, AGENTS.md/CLAUDE.md sync, auto-push — is convenience layered on top.

Symphony is the next layer up: a daemon that keeps a Codex app-server session running for each eligible issue in its own workspace. The repo still needs the same harness, but the control plane becomes Linear instead of the terminal.
