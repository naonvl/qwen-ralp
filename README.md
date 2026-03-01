# Qwen Ralph Loop

**Autonomous AI coding agent loop using Qwen Code CLI** - Inspired by [Ralph Wiggum](https://ghuntley.com/ralph/)

An implementation of the "infinite loop" agent pattern where progress persists in **files and git history**, not in the LLM's context window. When context fills up, a fresh agent picks up where the last one left off.

---

## 🚀 Quick Start

### Install Qwen Code CLI

```bash
npm install -g @qwen-code/qwen-code@latest
```

### Install Qwen Ralph in Your Project

```bash
cd your-project
curl -fsSL https://raw.githubusercontent.com/naonvl/qwen-ralp/main/install-qwen-ralph.sh | bash
```

Or copy the files from this repo manually.

---

## 📁 Structure

```
project/
├── .qwen-scripts/
│   ├── qwen-loop.sh        # Main infinite loop
│   ├── qwen-once.sh        # Single iteration (testing)
│   ├── stream-parser.sh    # Parse Qwen output
│   ├── task-parser.sh      # Parse checkboxes
│   └── init-qwen.sh        # Initialize state
│
├── .qwen/
│   ├── guardrails.md       # Lessons learned
│   ├── progress.md         # Progress tracking
│   ├── activity.log        # Tool call log
│   └── errors.log          # Failure log
│
└── QWEN_TASK.md            # Task definition (edit this!)
```

---

## 📝 Usage

### 1. Define Your Task

Edit `QWEN_TASK.md` with your task and success criteria:

```markdown
---
task: Build a REST API
test_command: "npm test"
---

# Task: REST API

## Success Criteria
1. [ ] GET /health returns 200
2. [ ] POST /users creates a user
3. [ ] All tests pass
```

**Important:** Use checkbox format `[ ]` - Ralph tracks completion by counting checked boxes.

### 2. Test Single Iteration

```bash
./.qwen-scripts/qwen-once.sh
```

### 3. Run Full Loop

```bash
./.qwen-scripts/qwen-loop.sh
```

### 4. Monitor Progress

```bash
tail -f .qwen/activity.log
```

---

## 🔄 How It Works

```
┌─────────────────────────────────────────────┐
│            qwen-loop.sh                      │
│                 ▼                            │
│  qwen -i "" -y  (YOLO mode)                  │
│                 ▼                            │
│          stream-parser.sh                    │
│         │              │                     │
│         ▼              ▼                     │
│    .qwen/          Signals                   │
│    ├── progress.md   ├── COMPLETE            │
│    ├── guardrails.md ├── GUTTER (stuck)      │
│    └── activity.log  └── ROTATE              │
│                                              │
│  When context > 80k tokens → fresh agent     │
└─────────────────────────────────────────────┘
```

### Workflow

1. Define task in `QWEN_TASK.md` with checkbox-based success criteria
2. Start `qwen-loop.sh`
3. Qwen works until token threshold reached
4. At 80k tokens → forced rotation with fresh context
5. New agent reads git history, guardrails, and progress files
6. Continues work seamlessly
7. Loop terminates when all checkboxes are complete

---

## ⚙️ Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `QWEN_MAX_ITERATIONS` | 20 | Maximum loop iterations |
| `QWEN_TOKEN_WARN` | 70000 | Token count for warning |
| `QWEN_TOKEN_ROTATE` | 80000 | Token count for forced rotation |

Example:
```bash
QWEN_MAX_ITERATIONS=50 ./.qwen-scripts/qwen-loop.sh
```

---

## 🎯 Best Use Cases

| ✅ Ideal For | ❌ Not Suitable For |
|--------------|---------------------|
| Test coverage improvements | Subjective tasks ("make this prettier") |
| Code refactoring with test suites | Deep codebase understanding required |
| Database migrations | Nuanced judgment calls |
| API implementations with integration tests | |

---

## 🛡️ Guardrails System

When failures occur, Qwen adds "Signs" to `.qwen/guardrails.md`:

```markdown
### Sign: Check imports before adding
- **Trigger**: Adding a new import statement
- **Instruction**: First check if import already exists in file
- **Added after**: Iteration 3 - duplicate import caused build failure
```

Future iterations read these guardrails first, preventing repeated mistakes.

---

## ⚠️ YOLO Mode

This implementation uses **YOLO mode** (`-y` flag) which automatically approves all tool calls (file writes, shell commands).

**For safer operation**, you can:
1. Remove `-y` flag from scripts
2. Use `--approval-mode auto-edit` instead (auto-approve edits only)
3. Run in a sandboxed environment (Docker, VM)

---

## 📊 Limitations

- **Default cap:** 20 iterations
- **Cost:** Depends on Qwen API usage (or local GPU if running offline)
- **Not suitable for:** Tasks requiring deep codebase understanding or nuanced judgment

---

## 🧪 Example: Building a Todo App

This repo includes a working example where Qwen Ralph built a CLI todo app in TypeScript:

```bash
# See the result
cat todo.ts
npx ts-node todo.ts list
npx ts-node todo.ts add "Buy milk"
npx ts-node todo.ts done 1
```

All 6 success criteria were completed in a single iteration!

---

## 📚 Learn More

- [Ralph Wiggum Original Concept](https://ghuntley.com/ralph/)
- [Qwen Code Documentation](https://qwenlm.github.io/qwen-code-docs/)
- [Qwen Ralph Loop on GitHub](https://github.com/naonvl/qwen-ralp)

---

## 🤝 Contributing

1. Fork this repo
2. Create a feature branch
3. Test with `qwen-once.sh` first
4. Submit PR

---

## 📄 License

MIT
