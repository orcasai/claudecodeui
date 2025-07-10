# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Claude Code UI is a web-based graphical interface for Claude Code CLI. It provides desktop and mobile-friendly UI to interact with Claude Code sessions, manage projects, and perform coding tasks through a visual interface.

## Key Architecture

### Tech Stack
- **Frontend**: React 18 + Vite + Tailwind CSS + CodeMirror + XTerm
- **Backend**: Node.js + Express + WebSocket
- **Real-time**: WebSocket for CLI process communication

### Core Components

1. **Server Integration** (`server/claude-cli.js`):
   - Manages Claude CLI process spawning and lifecycle
   - Handles WebSocket communication between UI and CLI
   - Session persistence and management

2. **Project Management** (`server/projects.js`):
   - Reads from `~/.claude/projects/` directory
   - Handles project watching and notifications
   - Project directory extraction and caching

3. **Frontend State** (`src/App.jsx`):
   - Main application state including active sessions
   - Session protection to prevent interruptions
   - Theme context for dark/light mode support

4. **Key UI Components**:
   - `ChatInterface`: Main conversation UI with Claude
   - `CodeEditor`: CodeMirror-based editor with syntax highlighting
   - `Terminal`: XTerm.js terminal emulator
   - `FileTree`: Interactive file explorer
   - `GitPanel`: Git operations interface

## Development Commands

```bash
# Install dependencies
npm install

# Development (frontend on :3001, backend on :3008)
npm run dev

# Run only backend server
npm run server

# Run only frontend dev server
npm run client

# Production build
npm run build

# Start production server
npm run start
```

## Important Development Notes

1. **No Linting/Testing Commands**: This project currently has no lint, format, or test commands configured. When adding new code, maintain consistency with existing code style.

2. **Environment Variables**:
   - `PORT`: Backend server port (default: 3008)
   - `VITE_PORT`: Frontend dev server port (default: 3001)

3. **Security Model**:
   - All Claude Code tools are disabled by default
   - Tools must be manually enabled through UI
   - Configuration stored in `src/components/ToolsModal.jsx`

4. **WebSocket Communication**:
   - Real-time messages between UI and Claude CLI
   - Handles tool execution, streaming responses, and status updates
   - See `server/index.js` for WebSocket server implementation

5. **File System Operations**:
   - File reading/writing handled through Express API routes
   - Project files accessible via `/api/projects/:id/files/*` endpoints
   - Git operations via `/api/git/*` routes

## Key Files to Understand

- `server/index.js`: Main Express server with WebSocket setup
- `server/claude-cli.js`: Claude CLI process management
- `src/App.jsx`: Main React application and state management
- `src/components/ChatInterface.jsx`: Core chat UI component
- `src/components/ToolsModal.jsx`: Tool permissions configuration

## Common Tasks

### Adding New API Endpoints
Add routes in `server/index.js` or create new route files in `server/routes/`

### Modifying UI Components
- Reusable components are in `src/components/ui/`
- Follow existing patterns for Tailwind CSS classes
- Use `cn()` utility for conditional classes

### Working with Claude CLI Integration
- CLI process management in `server/claude-cli.js`
- WebSocket message handling in `server/index.js`
- Session data stored in memory, not persisted

### Styling
- Uses Tailwind CSS with custom configuration
- Dark mode support via CSS variables in `src/index.css`
- Component variants using `class-variance-authority`