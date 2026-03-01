#!/bin/bash
# Qwen Ralph: One-click installer
# Usage: curl -fsSL https://your-repo/install-qwen-ralph.sh | bash

set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/your-org/qwen-ralph-loop/main"

echo "═══════════════════════════════════════════════════════════════════"
echo "🤖 Qwen Ralph Installer"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Check if we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "⚠️  Warning: Not in a git repository."
    echo "  Qwen Ralph works best with git for state persistence."
    echo ""
    echo "  Run: git init"
    echo ""
fi

# Check for qwen CLI
if ! command -v qwen &> /dev/null; then
    echo "⚠️  Warning: qwen CLI not found."
    echo "  Install via: npm install -g @qwen-code/qwen-code@latest"
    echo ""
else
    QWEN_VERSION=$(qwen --version 2>/dev/null || echo "unknown")
    echo "✓ Found qwen CLI: $QWEN_VERSION"
    echo ""
fi

# Check for Node.js
if ! command -v node &> /dev/null; then
    echo "⚠️  Warning: Node.js not found."
    echo "  Qwen Code requires Node.js and npm."
    echo ""
else
    NODE_VERSION=$(node --version)
    echo "✓ Found Node.js: $NODE_VERSION"
    echo ""
fi

WORKSPACE_ROOT="$(pwd)"

# =============================================================================
# CREATE DIRECTORIES
# =============================================================================
echo "📁 Creating directories..."
mkdir -p .qwen-scripts
mkdir -p .qwen

# =============================================================================
# CREATE SCRIPTS
# =============================================================================
echo "📝 Creating Qwen Ralph scripts..."

# -----------------------------------------------------------------------------
# qwen-loop.sh - Main orchestrator
# -----------------------------------------------------------------------------
cat > .qwen-scripts/qwen-loop.sh << 'LOOP_EOF'
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
        
        # Run Qwen (headless mode with file input)
        # Note: Adjust based on actual qwen CLI options
        if command -v qwen &> /dev/null; then
            qwen --headless < "$prompt_file" 2>&1 | tee -a "$QWEN_STATE/activity.log" || true
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
LOOP_EOF
chmod +x .qwen-scripts/qwen-loop.sh

# -----------------------------------------------------------------------------
# qwen-once.sh - Single iteration for testing
# -----------------------------------------------------------------------------
cat > .qwen-scripts/qwen-once.sh << 'ONCE_EOF'
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
ONCE_EOF
chmod +x .qwen-scripts/qwen-once.sh

# -----------------------------------------------------------------------------
# stream-parser.sh - Parse Qwen streaming output
# -----------------------------------------------------------------------------
cat > .qwen-scripts/stream-parser.sh << 'PARSER_EOF'
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
PARSER_EOF
chmod +x .qwen-scripts/stream-parser.sh

# -----------------------------------------------------------------------------
# task-parser.sh - Parse QWEN_TASK.md checkboxes
# -----------------------------------------------------------------------------
cat > .qwen-scripts/task-parser.sh << 'TASK_PARSER_EOF'
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
TASK_PARSER_EOF
chmod +x .qwen-scripts/task-parser.sh

# -----------------------------------------------------------------------------
# init-qwen.sh - Initialize .qwen state directory
# -----------------------------------------------------------------------------
cat > .qwen-scripts/init-qwen.sh << 'INIT_EOF'
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
INIT_EOF
chmod +x .qwen-scripts/init-qwen.sh

echo "✓ Scripts installed to .qwen-scripts/"

# =============================================================================
# INITIALIZE .qwen/ STATE
# =============================================================================
echo "📁 Initializing .qwen/ state directory..."

# Run init script
./.qwen-scripts/init-qwen.sh

# =============================================================================
# CREATE QWEN_TASK.md TEMPLATE
# =============================================================================
if [[ ! -f "QWEN_TASK.md" ]]; then
    echo "📝 Creating QWEN_TASK.md template..."
    cat > QWEN_TASK.md <<'TASK_EOF'
---
task: Build a CLI todo app in TypeScript
test_command: "npx ts-node todo.ts list"
---

# Task: CLI Todo App (TypeScript)

Build a simple command-line todo application in TypeScript.

## Requirements
1. Single file: `todo.ts`
2. Uses `todos.json` for persistence
3. Three commands: add, list, done
4. TypeScript with proper types

## Success Criteria
1. [ ] `npx ts-node todo.ts add "Buy milk"` adds a todo and confirms
2. [ ] `npx ts-node todo.ts list` shows all todos with IDs and status
3. [ ] `npx ts-node todo.ts done 1` marks todo 1 as complete
4. [ ] Todos survive script restart (JSON persistence)
5. [ ] Invalid commands show helpful usage message
6. [ ] Code has proper TypeScript types (no `any`)

## Example Output
```
$ npx ts-node todo.ts add "Buy milk"
✓ Added: "Buy milk" (id: 1)

$ npx ts-node todo.ts list
1. [ ] Buy milk

$ npx ts-node todo.ts done 1
✓ Completed: "Buy milk"
```

---
## Qwen Instructions
1. Work on the next incomplete criterion (marked [ ])
2. Check off completed criteria (change [ ] to [x])
3. Run tests after changes
4. Commit your changes frequently
5. When ALL criteria are [x], output: `COMPLETE`
6. If stuck on the same issue 3+ times, output: `GUTTER`
TASK_EOF
    echo "✓ Created QWEN_TASK.md with example task"
else
    echo "✓ QWEN_TASK.md already exists (not overwritten)"
fi

# =============================================================================
# UPDATE .gitignore
# =============================================================================
if [[ -f ".gitignore" ]]; then
    if ! grep -q "\.qwen/" .gitignore 2>/dev/null; then
        echo "" >> .gitignore
        echo "# Qwen Ralph state (optional - commit for persistence)" >> .gitignore
        echo "# .qwen/" >> .gitignore
    fi
else
    cat > .gitignore <<'GITIGNORE_EOF'
# Qwen Ralph state (optional - commit for persistence)
# .qwen/

# Node modules
node_modules/

# Logs
*.log
GITIGNORE_EOF
fi

echo "✓ Updated .gitignore"

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "✅ Qwen Ralph installed!"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
echo "Files created:"
echo ""
echo " 📁 .qwen-scripts/"
echo " ├── qwen-loop.sh      - Main loop (infinite with rotation)"
echo " ├── qwen-once.sh      - Single iteration (testing)"
echo " ├── stream-parser.sh  - Parse Qwen output"
echo " ├── task-parser.sh    - Parse task checkboxes"
echo " └── init-qwen.sh      - Initialize state"
echo ""
echo " 📁 .qwen/             - State files (tracked in git)"
echo " ├── guardrails.md     - Lessons learned"
echo " ├── progress.md       - Progress log"
echo " ├── activity.log      - Tool call log"
echo " └── errors.log        - Failure log"
echo ""
echo " 📄 QWEN_TASK.md       - Your task definition (edit this!)"
echo ""
echo "Next steps:"
echo " 1. Edit QWEN_TASK.md to define your actual task"
echo " 2. Run: ./.qwen-scripts/qwen-once.sh (test single iteration)"
echo " 3. Run: ./.qwen-scripts/qwen-loop.sh (start full loop)"
echo ""
echo "Monitor progress:"
echo " tail -f .qwen/activity.log"
echo ""
echo "Learn more: https://ghuntley.com/ralph/"
echo "═══════════════════════════════════════════════════════════════════"
