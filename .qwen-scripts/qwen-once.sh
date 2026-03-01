#!/bin/bash
# Qwen Ralph Once - Single iteration for testing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
QWEN_STATE="$PROJECT_ROOT/.qwen"
TASK_FILE="$PROJECT_ROOT/QWEN_TASK.md"

echo "═══════════════════════════════════════════════════════════════════"
echo "🧪 Qwen Ralph - Single Iteration Test"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Build context
context=""

if [[ -f "$TASK_FILE" ]]; then
    context+="=== TASK ===\n$(cat "$TASK_FILE")\n\n"
fi

if [[ -f "$QWEN_STATE/guardrails.md" ]]; then
    context+="=== GUARDRAILS ===\n$(cat "$QWEN_STATE/guardrails.md")\n\n"
fi

if [[ -f "$QWEN_STATE/progress.md" ]]; then
    context+="=== PROGRESS ===\n$(cat "$QWEN_STATE/progress.md")\n\n"
fi

echo "📦 Context prepared. Running Qwen..."
echo ""

# Create temp prompt
prompt_file=$(mktemp)
echo -e "$context" > "$prompt_file"
echo "" >> "$prompt_file"
echo "=== INSTRUCTION ===" >> "$prompt_file"
echo "Work on the next incomplete criterion. Show me what you would do." >> "$prompt_file"

# Run Qwen
if command -v qwen &> /dev/null; then
    qwen --headless < "$prompt_file" 2>&1 | tee -a "$QWEN_STATE/activity.log"
else
    echo "⚠️  qwen CLI not found. Install with: npm install -g @qwen-code/qwen-code"
fi

rm -f "$prompt_file"

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "✓ Single iteration complete"
echo "═══════════════════════════════════════════════════════════════════"
