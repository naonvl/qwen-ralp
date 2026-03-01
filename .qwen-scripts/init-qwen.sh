#!/bin/bash
# Initialize Qwen Ralph state directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
QWEN_STATE="$PROJECT_ROOT/.qwen"

echo "📁 Initializing .qwen state directory..."

mkdir -p "$QWEN_STATE"

# Guardrails
cat > "$QWEN_STATE/guardrails.md" << 'GUARDRAILS_EOF'
# Qwen Guardrails (Signs)
> Lessons learned from past failures. READ THESE BEFORE ACTING.

## Core Signs

### Sign: Read Before Writing
- **Trigger**: Before modifying any file
- **Instruction**: Always read the existing file first
- **Added after**: Core principle

### Sign: Test After Changes
- **Trigger**: After any code change
- **Instruction**: Run tests to verify nothing broke
- **Added after**: Core principle

### Sign: Commit Checkpoints
- **Trigger**: Before risky changes
- **Instruction**: Commit current working state first
- **Added after**: Core principle

---
## Learned Signs
(Signs added from observed failures will appear below)
GUARDRAILS_EOF

# Progress
cat > "$QWEN_STATE/progress.md" << 'PROGRESS_EOF'
# Progress Log
> Updated by the agent after significant work.

## Summary
- Iterations completed: 0
- Current status: Initialized

## How This Works
Progress is tracked in THIS FILE, not in LLM context.
When context is rotated (fresh agent), the new agent reads this file.
This is how Qwen Ralph maintains continuity across iterations.

## Session History
PROGRESS_EOF

# Error log
cat > "$QWEN_STATE/errors.log" << 'ERRORS_EOF'
# Error Log
> Failures detected by stream-parser. Use to update guardrails.
ERRORS_EOF

# Activity log
cat > "$QWEN_STATE/activity.log" << 'ACTIVITY_EOF'
# Activity Log
> Real-time tool call logging from stream-parser.
ACTIVITY_EOF

# Iteration counter
echo "0" > "$QWEN_STATE/.iteration"

# Signal file
echo "" > "$QWEN_STATE/.signal"

echo "✓ .qwen/ initialized"
