#!/bin/bash
#
# Run all Playwriter examples
#
# Usage:
#   ./examples/run_all.sh           # Auto-detect mode
#   ./examples/run_all.sh --local   # Force local mode
#   ./examples/run_all.sh --remote  # Force remote mode
#   ./examples/run_all.sh --windows # Force windows mode

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Pass through any arguments to the examples
ARGS="$*"

echo "========================================"
echo "Playwriter Examples Runner"
echo "========================================"
echo ""
echo "Arguments: ${ARGS:-<auto-detect mode>}"
echo ""

# Examples to run (in order of complexity)
EXAMPLES=(
    "fetch_html.exs"
    "screenshot.exs"
    "interaction.exs"
)

# Windows-specific examples (only run with --windows or --remote)
WINDOWS_EXAMPLES=(
    "windows_browser.exs"
    "windows_mode.exs"
)

run_example() {
    local example="$1"
    echo "----------------------------------------"
    echo "Running: $example"
    echo "----------------------------------------"
    if mix run "examples/$example" $ARGS; then
        echo ""
        echo "SUCCESS: $example"
    else
        echo ""
        echo "FAILED: $example (exit code: $?)"
        return 1
    fi
    echo ""
}

# Run basic examples
for example in "${EXAMPLES[@]}"; do
    run_example "$example" || true
done

# Run Windows examples only if requested
if [[ "$ARGS" == *"--windows"* ]] || [[ "$ARGS" == *"--remote"* ]]; then
    echo "========================================"
    echo "Running Windows-specific examples"
    echo "========================================"
    echo ""
    for example in "${WINDOWS_EXAMPLES[@]}"; do
        run_example "$example" || true
    done
fi

echo "========================================"
echo "All examples completed"
echo "========================================"
