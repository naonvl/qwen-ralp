#!/usr/bin/env ts-node

import * as fs from 'fs';
import * as path from 'path';

// Types
interface Todo {
  id: number;
  text: string;
  completed: boolean;
}

interface TodoStore {
  todos: Todo[];
  nextId: number;
}

// Constants
const TODOS_FILE = path.join(__dirname, 'todos.json');

// Load todos from JSON file
function loadTodos(): TodoStore {
  try {
    if (fs.existsSync(TODOS_FILE)) {
      const data = fs.readFileSync(TODOS_FILE, 'utf-8');
      return JSON.parse(data) as TodoStore;
    }
  } catch (error) {
    // If file is corrupted, start fresh
  }
  return { todos: [], nextId: 1 };
}

// Save todos to JSON file
function saveTodos(store: TodoStore): void {
  fs.writeFileSync(TODOS_FILE, JSON.stringify(store, null, 2), 'utf-8');
}

// Add a new todo
function addTodo(text: string): void {
  const store = loadTodos();
  const todo: Todo = {
    id: store.nextId,
    text,
    completed: false,
  };
  store.todos.push(todo);
  store.nextId++;
  saveTodos(store);
  console.log(`✓ Added: "${text}" (id: ${todo.id})`);
}

// List all todos
function listTodos(): void {
  const store = loadTodos();
  if (store.todos.length === 0) {
    console.log('No todos yet. Add one with: npx ts-node todo.ts add "Your task"');
    return;
  }
  for (const todo of store.todos) {
    const status = todo.completed ? '[x]' : '[ ]';
    console.log(`${todo.id}. ${status} ${todo.text}`);
  }
}

// Mark a todo as done
function doneTodo(id: number): void {
  const store = loadTodos();
  const todo = store.todos.find((t) => t.id === id);
  if (!todo) {
    console.error(`Error: Todo with id ${id} not found.`);
    process.exit(1);
  }
  todo.completed = true;
  saveTodos(store);
  console.log(`✓ Completed: "${todo.text}"`);
}

// Show usage message
function showUsage(): void {
  console.log(`
Usage: npx ts-node todo.ts <command> [arguments]

Commands:
  add <text>    Add a new todo item
  list          List all todos
  done <id>     Mark a todo as completed

Examples:
  npx ts-node todo.ts add "Buy milk"
  npx ts-node todo.ts list
  npx ts-node todo.ts done 1
`);
}

// Main entry point
function main(): void {
  const args = process.argv.slice(2);
  const command = args[0];

  switch (command) {
    case 'add':
      if (args.length < 2) {
        console.error('Error: Missing todo text.');
        console.error('Usage: npx ts-node todo.ts add "Your task"');
        process.exit(1);
      }
      addTodo(args.slice(1).join(' '));
      break;

    case 'list':
      listTodos();
      break;

    case 'done':
      if (args.length < 2) {
        console.error('Error: Missing todo id.');
        console.error('Usage: npx ts-node todo.ts done <id>');
        process.exit(1);
      }
      const idArg = args[1];
      const id = parseInt(idArg, 10);
      if (isNaN(id) || id < 1) {
        console.error('Error: Todo id must be a positive integer.');
        process.exit(1);
      }
      doneTodo(id);
      break;

    default:
      showUsage();
      process.exit(1);
  }
}

main();
