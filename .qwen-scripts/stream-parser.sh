#!/bin/bash
# Stream Parser for Qwen output
# Detects tool calls, signals, and logs activity

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
QWEN_STATE="$PROJECT_ROOT/.qwen"

# Signals to detect
SIGNAL_COMPLETE="COMPLETE"
SIGNAL_GUTTER="GUTTER"
SIGNAL_ROTATE="ROTATE"

# Parse stdin line by line
while IFS= read -r line; do
    # Output the line
    echo "$line"
    
    # Log to activity
    echo "[$(date -Iseconds)] $line" >> "$QWEN_STATE/activity.log"
    
    # Check for signals
    if echo "$line" | grep -qi "$SIGNAL_COMPLETE"; then
        echo ""
        echo "🎉 SIGNAL DETECTED: $SIGNAL_COMPLETE"
        echo "$SIGNAL_COMPLETE" > "$QWEN_STATE/.signal"
    fi
    
    if echo "$line" | grep -qi "$SIGNAL_GUTTER"; then
        echo ""
        echo "🚨 SIGNAL DETECTED: $SIGNAL_GUTTER"
        echo "$SIGNAL_GUTTER" > "$QWEN_STATE/.signal"
    fi
    
    if echo "$line" | grep -qi "$SIGNAL_ROTATE"; then
        echo ""
        echo "🔄 SIGNAL DETECTED: $SIGNAL_ROTATE"
        echo "$SIGNAL_ROTATE" > "$QWEN_STATE/.signal"
    fi
    
    # Detect errors
    if echo "$line" | grep -qiE "(error|failed|exception|traceback)"; then
        echo "[$(date -Iseconds)] $line" >> "$QWEN_STATE/errors.log"
    fi
    
done
