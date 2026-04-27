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
  command: codex app-server
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
