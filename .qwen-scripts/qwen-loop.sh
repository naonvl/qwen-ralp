#!/bin/bash
# Qwen Ralph Loop - Main orchestrator
# Infinite loop with context rotation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
QWEN_STATE="$PROJECT_ROOT/.qwen"
TASK_FILE="$PROJECT_ROOT/QWEN_TASK.md"

# Configuration
MAX_ITERATIONS="${QWEN_MAX_ITERATIONS:-20}"
TOKEN_THRESHOLD_WARN="${QWEN_TOKEN_WARN:-70000}"
TOKEN_THRESHOLD_ROTATE="${QWEN_TOKEN_ROTATE:-80000}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Load iteration counter
load_iteration() {
    if [[ -f "$QWEN_STATE/.iteration" ]]; then
        cat "$QWEN_STATE/.iteration"
    else
        echo "0"
    fi
}

# Save iteration counter
save_iteration() {
    echo "$1" > "$QWEN_STATE/.iteration"
}

# Count tokens (approximate: 1 token ≈ 4 chars)
count_tokens() {
    local text="$1"
    echo $(( ${#text} / 4 ))
}

# Count context tokens
count_context_tokens() {
    local total=0
    
    # Count QWEN_TASK.md
    if [[ -f "$TASK_FILE" ]]; then
        local task_tokens=$(count_tokens "$(cat "$TASK_FILE")")
        total=$((total + task_tokens))
    fi
    
    # Count progress.md
    if [[ -f "$QWEN_STATE/progress.md" ]]; then
        local progress_tokens=$(count_tokens "$(cat "$QWEN_STATE/progress.md")")
        total=$((total + progress_tokens))
    fi
    
    # Count guardrails.md
    if [[ -f "$QWEN_STATE/guardrails.md" ]]; then
        local guardrails_tokens=$(count_tokens "$(cat "$QWEN_STATE/guardrails.md")")
        total=$((total + guardrails_tokens))
    fi
    
    # Count recent activity log (last 100 lines)
    if [[ -f "$QWEN_STATE/activity.log" ]]; then
        local activity_tokens=$(count_tokens "$(tail -100 "$QWEN_STATE/activity.log")")
        total=$((total + activity_tokens))
    fi
    
    echo "$total"
}

# Check if task is complete (all checkboxes marked [x])
task_is_complete() {
    if [[ ! -f "$TASK_FILE" ]]; then
        return 1
    fi
    
    # Count unchecked boxes
    local unchecked=$(grep -c '^\s*[0-9]*\. \[ \]' "$TASK_FILE" 2>/dev/null || echo "0")
    
    if [[ "$unchecked" -eq 0 ]]; then
        return 0  # Complete
    else
        return 1  # Not complete
    fi
}

# Get next incomplete criterion
get_next_criterion() {
    if [[ ! -f "$TASK_FILE" ]]; then
        echo ""
        return
    fi
    
    grep -m1 '^\s*[0-9]*\. \[ \]' "$TASK_FILE" 2>/dev/null || echo ""
}

# Build context for Qwen
build_context() {
    local context=""
    
    # Add task file
    if [[ -f "$TASK_FILE" ]]; then
        context+="=== TASK DEFINITION ===\n"
        context+="$(cat "$TASK_FILE")\n\n"
    fi
    
    # Add guardrails
    if [[ -f "$QWEN_STATE/guardrails.md" ]]; then
        context+="=== GUARDRAILS (READ FIRST) ===\n"
        context+="$(cat "$QWEN_STATE/guardrails.md")\n\n"
    fi
    
    # Add progress
    if [[ -f "$QWEN_STATE/progress.md" ]]; then
        context+="=== PROGRESS SO FAR ===\n"
        context+="$(cat "$QWEN_STATE/progress.md")\n\n"
    fi
    
    # Add recent errors
    if [[ -f "$QWEN_STATE/errors.log" ]] && [[ -s "$QWEN_STATE/errors.log" ]]; then
        context+="=== RECENT ERRORS (LEARN FROM THESE) ===\n"
        context+="$(tail -20 "$QWEN_STATE/errors.log")\n\n"
    fi
    
    echo -e "$context"
}

# Update progress file
update_progress() {
    local iteration="$1"
    local status="$2"
    
    cat > "$QWEN_STATE/progress.md" << PROGRESS_EOF
# Progress Log
> Updated by Qwen Ralph after each iteration.

## Summary
- Iterations completed: $iteration
- Current status: $status
- Last updated: $(date -Iseconds)

## How This Works
Progress is tracked in THIS FILE, not in LLM context.
When context is rotated (fresh agent), the new agent reads this file.
This is how Qwen Ralph maintains continuity across iterations.

## Session History
- Iteration $iteration: $status ($(date))
PROGRESS_EOF
}

# Detect gutter (stuck) condition
detect_gutter() {
    local recent_errors=""
    
    if [[ -f "$QWEN_STATE/errors.log" ]]; then
        recent_errors=$(tail -10 "$QWEN_STATE/errors.log")
    fi
    
    # Check for same error 3+ times
    local error_count=$(echo "$recent_errors" | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')
    
    if [[ "${error_count:-0}" -ge 3 ]]; then
        return 0  # Gutter detected
    else
        return 1  # Not stuck
    fi
}

# Main loop
main() {
    log_info "🚀 Starting Qwen Ralph Loop"
    log_info "   Max iterations: $MAX_ITERATIONS"
    log_info "   Token threshold (warn): $TOKEN_THRESHOLD_WARN"
    log_info "   Token threshold (rotate): $TOKEN_THRESHOLD_ROTATE"
    echo ""
    
    # Check task file exists
    if [[ ! -f "$TASK_FILE" ]]; then
        log_error "QWEN_TASK.md not found!"
        log_error "Please create QWEN_TASK.md with your task definition."
        exit 1
    fi
    
    # Check if already complete
    if task_is_complete; then
        log_success "✅ Task is already complete! All criteria checked."
        exit 0
    fi
    
    local iteration=$(load_iteration)
    
    while true; do
        echo ""
        echo "═══════════════════════════════════════════════════════════════════"
        log_info "📍 Iteration $iteration / $MAX_ITERATIONS"
        echo "═══════════════════════════════════════════════════════════════════"
        
        # Check iteration limit
        if [[ $iteration -ge $MAX_ITERATIONS ]]; then
            log_error "❌ Max iterations ($MAX_ITERATIONS) reached. Stopping."
            exit 1
        fi
        
        # Check if task complete
        if task_is_complete; then
            log_success "✅ All criteria complete! Task finished."
            update_progress "$iteration" "COMPLETED"
            exit 0
        fi
        
        # Count tokens
        local context_tokens=$(count_context_tokens)
        log_info "📊 Context tokens: ~$context_tokens"
        
        if [[ $context_tokens -ge $TOKEN_THRESHOLD_ROTATE ]]; then
            log_warn "🔄 Context too large ($context_tokens >= $TOKEN_THRESHOLD_ROTATE). Forcing rotation..."
            log_info "   (Fresh agent will pick up from .qwen/ state files)"
        elif [[ $context_tokens -ge $TOKEN_THRESHOLD_WARN ]]; then
            log_warn "⚠️  Context approaching limit ($context_tokens >= $TOKEN_THRESHOLD_WARN)"
        fi
        
        # Build context
        log_info "📦 Building context..."
        local context=$(build_context)
        
        # Get next criterion
        local next_criterion=$(get_next_criterion)
        if [[ -n "$next_criterion" ]]; then
            log_info "🎯 Next criterion: $next_criterion"
        fi
        
        # Run Qwen
        log_info "🤖 Calling Qwen..."
        echo ""
        
        # Create prompt file
        local prompt_file=$(mktemp)
        echo "$context" > "$prompt_file"
        echo "" >> "$prompt_file"
        echo "=== INSTRUCTION ===" >> "$prompt_file"
        echo "Work on the next incomplete criterion in QWEN_TASK.md." >> "$prompt_file"
        echo "After completing work, update the checkbox from [ ] to [x]." >> "$prompt_file"
        echo "Run tests if test_command is specified." >> "$prompt_file"
        echo "Commit your changes to git." >> "$prompt_file"
        echo "If all criteria are complete, output: COMPLETE" >> "$prompt_file"
        echo "If you're stuck on the same issue 3+ times, output: GUTTER" >> "$prompt_file"
        
        # Run Qwen with interactive prompt mode and YOLO for auto-approval
        if command -v qwen &> /dev/null; then
            cat "$prompt_file" | qwen -i "" -y 2>&1 | tee -a "$QWEN_STATE/activity.log" || true
        else
            log_warn "qwen CLI not available. Simulating..."
            echo "[SIMULATED QWEN OUTPUT]" | tee -a "$QWEN_STATE/activity.log"
        fi
        
        rm -f "$prompt_file"
        
        # Update progress
        iteration=$((iteration + 1))
        save_iteration "$iteration"
        update_progress "$iteration" "IN_PROGRESS"
        
        # Check for gutter
        if detect_gutter; then
            log_error "🚨 GUTTER DETECTED - Agent appears stuck!"
            log_error "   Review .qwen/errors.log and update guardrails.md"
            log_error "   Then restart the loop."
            exit 1
        fi
        
        # Small delay between iterations
        sleep 2
    done
}

main "$@"
