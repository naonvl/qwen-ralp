#!/bin/bash
# Task Parser - Parse QWEN_TASK.md checkboxes

set -euo pipefail

TASK_FILE="${1:-QWEN_TASK.md}"

if [[ ! -f "$TASK_FILE" ]]; then
    echo "ERROR: $TASK_FILE not found"
    exit 1
fi

# Count total criteria
total=$(grep -c '^\s*[0-9]*\. \[' "$TASK_FILE" 2>/dev/null || echo "0")

# Count completed
completed=$(grep -c '^\s*[0-9]*\. \[x\]' "$TASK_FILE" 2>/dev/null || echo "0")

# Count incomplete
incomplete=$(grep -c '^\s*[0-9]*\. \[ \]' "$TASK_FILE" 2>/dev/null || echo "0")

# Get next incomplete
next=$(grep -m1 '^\s*[0-9]*\. \[ \]' "$TASK_FILE" 2>/dev/null || echo "")

echo "=== Task Status ==="
echo "Total criteria: $total"
echo "Completed: $completed"
echo "Incomplete: $incomplete"
echo ""

if [[ -n "$next" ]]; then
    echo "Next: $next"
else
    echo "✅ All criteria complete!"
fi

# Return codes
if [[ "$incomplete" -eq 0 ]]; then
    exit 0  # Complete
else
    exit 1  # Incomplete
fi
