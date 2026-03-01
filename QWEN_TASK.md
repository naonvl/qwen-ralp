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
1. [x] `npx ts-node todo.ts add "Buy milk"` adds a todo and confirms
2. [x] `npx ts-node todo.ts list` shows all todos with IDs and status
3. [x] `npx ts-node todo.ts done 1` marks todo 1 as complete
4. [x] Todos survive script restart (JSON persistence)
5. [x] Invalid commands show helpful usage message
6. [x] Code has proper TypeScript types (no `any`)

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
