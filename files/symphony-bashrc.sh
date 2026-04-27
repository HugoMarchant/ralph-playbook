# Load local Symphony/Linear credentials for new bash sessions.
if [ -f "$HOME/.config/ralph-symphony/env" ]; then
    . "$HOME/.config/ralph-symphony/env"
fi

# Start the Symphony server for the repo in the current directory.
# Usage: cd /path/to/project && symphony
symphony() {
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        echo "Usage: symphony [path/to/WORKFLOW.md] [symphony flags...]"
        echo "Default: current directory's WORKFLOW.md"
        echo "Optional env: SYMPHONY_DIR=/path/to/symphony/elixir SYMPHONY_PORT=4000"
        return 0
    fi

    local workflow="$PWD/WORKFLOW.md"
    local symphony_dir="${SYMPHONY_DIR:-$HOME/dev/symphony/elixir}"
    local port="${SYMPHONY_PORT:-}"

    if [ "${1:-}" != "" ] && [ "${1#-}" = "$1" ]; then
        workflow="$1"
        shift
    fi

    if [ ! -f "$workflow" ]; then
        echo "Error: WORKFLOW.md not found at: $workflow" >&2
        return 1
    fi

    if [ ! -d "$symphony_dir" ]; then
        echo "Error: Symphony checkout not found." >&2
        echo "Set SYMPHONY_DIR=/path/to/symphony/elixir or clone Symphony to $HOME/dev/symphony." >&2
        return 1
    fi

    if ! command -v mise >/dev/null 2>&1; then
        echo "Error: mise is not installed or not on PATH." >&2
        return 1
    fi

    if [ -z "$port" ]; then
        port=4000
        while ss -ltn "( sport = :$port )" 2>/dev/null | grep -q ":$port"; do
            port=$((port + 1))
        done
    fi

    echo "Starting Symphony on port $port for $workflow"
    (
        cd "$symphony_dir" &&
        mise exec -- ./bin/symphony "$workflow" --port "$port" "$@"
    )
}
