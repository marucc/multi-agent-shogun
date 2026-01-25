# 🏯 claude-shogun

A multi-agent orchestration system for Claude Code, inspired by the Japanese feudal military structure.

## Overview

claude-shogun enables parallel development with multiple Claude Code agents organized in a hierarchical structure:

```
Chairman (Human)
    │
    ▼
┌─────────┐
│ SHOGUN  │ ← Supreme Commander (Project Oversight)
│ (将軍)   │
└────┬────┘
     │
     ▼
┌─────────┐
│  KARO   │ ← Field Commander (Task Management)
│ (家老)   │
└────┬────┘
     │
     ▼
┌─┬─┬─┬─┬─┬─┬─┬─┐
│1│2│3│4│5│6│7│8│ ← Infantry (Workers)
└─┴─┴─┴─┴─┴─┴─┴─┘
  ASHIGARU (足軽)
```

## Features

- **YAML-based Communication**: Reliable file-based messaging between agents
- **Human Dashboard**: Real-time overview of all projects and tasks
- **Multi-project Support**: Manage multiple projects simultaneously
- **Samurai Theme**: Fun Japanese feudal aesthetics with bilingual messages

## Quick Start

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/claude-shogun.git
cd claude-shogun

# Run setup
./setup.sh

# Attach to Shogun session
tmux attach-session -t shogun

# Start Claude Code
claude --dangerously-skip-permissions

# Give the command
# "You are the Shogun. Read instructions/shogun.md and follow the instructions."
```

## Communication Style

Agents use a samurai-themed bilingual communication style:

- `はっ！(Ha!)` - Acknowledged
- `承知つかまつった(Acknowledged!)` - Understood
- `任務完了でござる(Task completed!)` - Task completed
- `出陣いたす(Deploying!)` - Starting work
- `申し上げます(Reporting!)` - Reporting

## File Structure

```
claude-shogun/
├── instructions/          # Agent instruction files
│   ├── shogun.md
│   ├── karo.md
│   └── ashigaru.md
├── config/
│   └── projects.yaml      # Project configuration
├── status/
│   └── master_status.yaml # Overall status
├── queue/                 # Message queues
│   ├── shogun_to_karo.yaml
│   ├── karo_to_ashigaru.yaml
│   └── reports/
├── dashboard.md           # Human-readable dashboard
└── setup.sh               # Setup script
```

## Credits

Based on [Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication) by Akira-Papa.

## License

MIT License
