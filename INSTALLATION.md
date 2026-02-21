# Ralph Loop Installation Guide

This guide provides exhaustive, step-by-step instructions for implementing Ralph loops into a new or existing repository. It is designed to be followed by an LLM assistant (e.g. Claude Code) working with a human developer.

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
9. [Create Specification Files](#9-create-specification-files)
10. [Update .gitignore](#10-update-gitignore)
11. [Security: Sandbox Setup](#11-security-sandbox-setup)
12. [First Run: Planning Mode](#12-first-run-planning-mode)
13. [Building Mode](#13-building-mode)
14. [Ongoing Operation & Tuning](#14-ongoing-operation--tuning)
15. [Optional Enhancements](#15-optional-enhancements)
16. [Troubleshooting](#16-troubleshooting)
17. [Quick Reference](#17-quick-reference)

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

### Recommended

- A **sandbox environment** for running Ralph autonomously (Docker, E2B, Fly Sprites, etc.) — see [Section 11](#11-security-sandbox-setup) for details. Ralph runs with permission-bypassing flags (`--dangerously-bypass-approvals-and-sandbox` for Codex, `--dangerously-skip-permissions` for Claude) which bypass all safety prompts.
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
   - If no, you will need to help the human define these (see [Section 9](#9-create-specification-files)).

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
├── specs/                          # Requirement specs - one per JTBD topic (created in step 9)
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

The script defaults to **Codex CLI** (`codex`). Set `RALPH_CLI=claude` to use Claude Code CLI instead.

### Template

Create `loop.sh` in the project root:

```bash
#!/bin/bash
# Ralph Loop Script
#
# Supports both Codex CLI (default) and Claude Code CLI.
# Set RALPH_CLI=claude to use Claude Code instead of Codex.
#
# Usage: ./loop.sh [plan] [max_iterations]
# Examples:
#   ./loop.sh              # Build mode, unlimited iterations (Codex)
#   ./loop.sh 20           # Build mode, max 20 iterations
#   ./loop.sh plan         # Plan mode, unlimited iterations
#   ./loop.sh plan 5       # Plan mode, max 5 iterations
#
# With Claude Code CLI:
#   RALPH_CLI=claude ./loop.sh
#   RALPH_CLI=claude RALPH_MODEL=sonnet ./loop.sh 20

# ─── CLI Configuration ──────────────────────────────────────────────
# RALPH_CLI: "codex" (default) or "claude"
RALPH_CLI="${RALPH_CLI:-codex}"

# RALPH_MODEL: Model override (Claude only). Default: "opus"
#   Examples: opus, sonnet
RALPH_MODEL="${RALPH_MODEL:-opus}"

# ─── Parse arguments ────────────────────────────────────────────────
if [ "$1" = "plan" ]; then
    MODE="plan"
    PROMPT_FILE="PROMPT_plan.md"
    MAX_ITERATIONS=${2:-0}
elif [[ "$1" =~ ^[0-9]+$ ]]; then
    MODE="build"
    PROMPT_FILE="PROMPT_build.md"
    MAX_ITERATIONS=$1
else
    MODE="build"
    PROMPT_FILE="PROMPT_build.md"
    MAX_ITERATIONS=0
fi

ITERATION=0
CURRENT_BRANCH=$(git branch --show-current)

# ─── Validate CLI is installed ──────────────────────────────────────
if [ "$RALPH_CLI" = "claude" ]; then
    if ! command -v claude &> /dev/null; then
        echo "Error: Claude Code CLI not found"
        echo "Install: npm install -g @anthropic-ai/claude-code"
        exit 1
    fi
    CLI_DISPLAY="Claude Code CLI (claude)"
else
    if ! command -v codex &> /dev/null; then
        echo "Error: Codex CLI not found"
        echo "Install: npm install -g @openai/codex"
        echo "Then:    codex login"
        exit 1
    fi
    CLI_DISPLAY="Codex CLI (codex)"
fi

# ─── Display configuration ──────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "CLI:    $CLI_DISPLAY"
echo "Mode:   $MODE"
echo "Prompt: $PROMPT_FILE"
echo "Branch: $CURRENT_BRANCH"
[ "$RALPH_CLI" = "claude" ] && echo "Model:  $RALPH_MODEL"
[ $MAX_ITERATIONS -gt 0 ] && echo "Max:    $MAX_ITERATIONS iterations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─── Verify prompt file exists ──────────────────────────────────────
if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: $PROMPT_FILE not found"
    exit 1
fi

# ─── Main loop ──────────────────────────────────────────────────────
while true; do
    if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
        echo "Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    # Run Ralph iteration with the configured CLI
    if [ "$RALPH_CLI" = "claude" ]; then
        # Claude Code CLI
        # -p: Headless mode (non-interactive, reads from stdin)
        # --dangerously-skip-permissions: Auto-approve all tool calls
        # --output-format=stream-json: Structured output for logging/monitoring
        # --model: Primary model for reasoning (opus or sonnet)
        # --verbose: Detailed execution logging
        cat "$PROMPT_FILE" | claude -p \
            --dangerously-skip-permissions \
            --output-format=stream-json \
            --model "$RALPH_MODEL" \
            --verbose
    else
        # Codex CLI (default)
        # exec: Non-interactive execution mode, reads prompt from stdin via "-"
        # --dangerously-bypass-approvals-and-sandbox: Auto-approve all tool calls
        cat "$PROMPT_FILE" | codex exec \
            --dangerously-bypass-approvals-and-sandbox \
            -
    fi

    # Sync AGENTS.md → CLAUDE.md after each iteration (Ralph may have updated AGENTS.md)
    if [ -f "AGENTS.md" ]; then
        cp AGENTS.md CLAUDE.md
    fi

    # Push changes after each iteration
    git push origin "$CURRENT_BRANCH" || {
        echo "Failed to push. Creating remote branch..."
        git push -u origin "$CURRENT_BRANCH"
    }

    ITERATION=$((ITERATION + 1))
    echo -e "\n\n======================== LOOP $ITERATION ========================\n"
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

### Model Selection (Claude Only)

When using Claude Code CLI, you can configure the model:

```bash
# Use Opus (default) — best for planning and complex reasoning
RALPH_CLI=claude ./loop.sh plan

# Use Sonnet — faster and cheaper, good for well-defined build tasks
RALPH_CLI=claude RALPH_MODEL=sonnet ./loop.sh 20
```

### Understanding the CLI Flags

#### Codex CLI Flags

| Flag | Purpose |
|------|---------|
| `exec` | **Execution mode.** Non-interactive, reads prompt from stdin. Required for automation. |
| `--dangerously-bypass-approvals-and-sandbox` | **Bypasses all approval prompts and sandbox restrictions.** Required for fully automated runs. This is why a sandbox environment is critical — see [Section 11](#11-security-sandbox-setup). |
| `-` | **Read from stdin.** Tells Codex to read the prompt from the pipe. |

#### Claude Code CLI Flags

| Flag | Purpose |
|------|---------|
| `-p` | **Headless mode.** Non-interactive operation, reads prompt from stdin. Required for automation. |
| `--dangerously-skip-permissions` | **Bypasses all permission prompts.** Required for fully automated runs. This is why a sandbox is critical — see [Section 11](#11-security-sandbox-setup). |
| `--output-format=stream-json` | **Structured output.** Enables logging and monitoring of the loop's progress. |
| `--model opus` | **Primary model.** Opus for complex reasoning (task selection, prioritization, coordination). |
| `--verbose` | **Detailed logging.** Provides visibility into what the agent is doing. |

---

## 9. Create Specification Files

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

## 10. Update .gitignore

Ensure none of the Ralph files are accidentally ignored by git. All Ralph files (`AGENTS.md`, `CLAUDE.md`, `PROMPT_plan.md`, `PROMPT_build.md`, `IMPLEMENTATION_PLAN.md`, `loop.sh`, and `specs/`) should be **tracked by git** — they are part of the project's workflow.

Check the existing `.gitignore` and make sure it does not exclude any of these files.

No Ralph-specific entries need to be **added** to `.gitignore` unless you have a specific reason (e.g. log files from `--output-format=stream-json` if you redirect output to a file).

---

## 11. Security: Sandbox Setup

**This section is critical.** Ralph runs with dangerous permission-bypassing flags (`--dangerously-bypass-approvals-and-sandbox` for Codex, `--dangerously-skip-permissions` for Claude), which means it can execute any command, read any file, and make any network request without asking for approval. This bypasses the CLI's entire permission system.

### The Philosophy

> "It's not if it gets popped, it's when. And what is the blast radius?"

Running Ralph without a sandbox exposes:
- Your API keys and credentials
- Browser cookies and session tokens
- SSH keys
- Access tokens for any service your machine can reach

### Minimum Viable Security

At a minimum, Ralph should run in an environment with:
- **Only the API keys needed for the task** (Anthropic API key, and any deploy keys)
- **No access to private data** beyond what the task requires
- **Restricted network connectivity** where possible

### Sandbox Options

**ASK THE HUMAN** which sandbox approach they want to use:

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

## 12. First Run: Planning Mode

Planning mode performs gap analysis — it compares your specs against your existing code and generates a prioritized implementation plan. **Always run planning mode first before building.**

### Pre-flight Checklist

Before running, verify all files are in place:

- [ ] `AGENTS.md` exists with correct build/test/lint commands
- [ ] `CLAUDE.md` exists (copy of `AGENTS.md`)
- [ ] `PROMPT_plan.md` exists with correct paths and project goal
- [ ] `PROMPT_build.md` exists with correct paths
- [ ] `IMPLEMENTATION_PLAN.md` exists (even if just a placeholder comment)
- [ ] `specs/` directory exists with at least one spec file
- [ ] `loop.sh` exists and is executable (`chmod +x loop.sh`)
- [ ] Your chosen CLI is installed and authenticated (`codex --version` or `claude --version`)
- [ ] Git remote is configured (`git remote -v`)
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

## 13. Building Mode

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

## 14. Ongoing Operation & Tuning

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

### Signs Ralph Can Discover

Ralph steers itself by discovering signals in its environment. These aren't just prompt text:

- **Prompt guardrails** — explicit instructions in `PROMPT_build.md`
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

## 15. Optional Enhancements

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

5. **Ensure your specs include acceptance criteria** — each spec file should have a section describing observable, verifiable outcomes (see Section 9).

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

## 16. Troubleshooting

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

## 17. Quick Reference

### File Summary

| File | Created By | Updated By | Purpose |
|------|-----------|------------|---------|
| `loop.sh` | You (once) | You (if needed) | Outer loop script |
| `PROMPT_plan.md` | You (once) | You (tuning) | Planning mode instructions |
| `PROMPT_build.md` | You (once) | You (tuning) | Building mode instructions |
| `AGENTS.md` | You (initial) | Ralph + You | Operational guide (build/test commands) |
| `CLAUDE.md` | You (initial) | loop.sh (auto-synced from `AGENTS.md`) | Copy of AGENTS.md for Claude Code CLI compatibility |
| `IMPLEMENTATION_PLAN.md` | Ralph | Ralph | Prioritized task list |
| `specs/*.md` | You + LLM | Rarely (Ralph can fix inconsistencies) | Requirements per topic of concern |

### Command Reference

```bash
# Planning mode (generates/updates IMPLEMENTATION_PLAN.md)
./loop.sh plan          # Unlimited iterations (uses Codex by default)
./loop.sh plan 3        # Max 3 iterations

# Building mode (implements tasks from plan)
./loop.sh               # Unlimited iterations
./loop.sh 20            # Max 20 iterations (20 tasks)

# Use Claude Code CLI instead of Codex
RALPH_CLI=claude ./loop.sh plan
RALPH_CLI=claude RALPH_MODEL=sonnet ./loop.sh 20

# Stop the loop
Ctrl+C

# Regenerate the plan
rm IMPLEMENTATION_PLAN.md && ./loop.sh plan

# Check progress
git log --oneline -20
cat IMPLEMENTATION_PLAN.md
cat AGENTS.md
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

4. TUNE (ongoing)
   Observe Ralph → adjust AGENTS.md, prompts, specs, utilities
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
