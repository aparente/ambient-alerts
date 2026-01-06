# ambient-alerts

A Claude Code plugin for ambient light communication. Express states, respond to events, and build a shared visual language between you and Claude through smart lights.

## Features

- **State-based communication** - Define what each state looks like (idle, thinking, completed, etc.)
- **Automatic events** - Lights respond to permission requests, tool completion, errors
- **Volitional control** - Claude can express states based on context and judgment
- **Interview-based setup** - Collaboratively design your light language through conversation
- **Transitions** - States can auto-transition (e.g., "completed" fades to "idle")
- **Works with any smart light** - Philips Hue (via OpenHue) or custom commands

## Quick Start

```bash
# Add the marketplace (first time only)
/plugins marketplace add aparente

# Install the plugin
/plugins install ambient-alerts@aparente

# Or via CLI:
# claude plugins marketplace add aparente
# claude plugins install ambient-alerts@aparente

# Run interactive setup - just ask Claude:
# "Set up ambient alerts for my lights"
```

## How It Works

### States

Define what each state looks like in your config:

```json
{
  "states": {
    "idle": { "color": "antique_white", "brightness": 40 },
    "thinking": { "color": "light_blue", "brightness": 60 },
    "completed": { "color": "pale_green", "brightness": 60 },
    "need_input": { "color": "gold", "brightness": 75 },
    "waiting": { "color": "lavender", "brightness": 50 },
    "error": { "color": "coral", "brightness": 70 }
  }
}
```

### Automatic Events

Map system events to states:

```json
{
  "events": {
    "PermissionRequest": "need_input",
    "PostToolUse.success": "completed",
    "PostToolUse.error": "error",
    "SessionStart": "idle",
    "SessionEnd": "off"
  }
}
```

### Transitions

Define auto-transitions between states:

```json
{
  "transitions": {
    "completed": {
      "duration_ms": 2000,
      "then": "idle"
    }
  }
}
```

### Volitional Control

Claude can set states directly when appropriate:

```json
{
  "volitional": {
    "enabled": true
  }
}
```

## Installation

```bash
claude plugins install ambient-alerts@aparente
```

## Setup

### Interactive Setup (Recommended)

Just ask Claude:
```
Set up ambient alerts for my lights
```

Claude will guide you through:
1. Selecting your smart light system
2. Choosing which light to use
3. **Interview 1: Automatic Events** - What should happen on permission requests, completions, errors?
4. **Interview 2: Volitional Presence** - How should Claude express thinking, waiting, idle states?
5. Testing and fine-tuning until it feels right

### Manual Setup

Create `~/.claude/ambient-alerts.json`:

```json
{
  "backend": "openhue",
  "light_name": "Pitcher",

  "states": {
    "idle": {
      "color": "antique_white",
      "brightness": 40,
      "description": "I'm here, all is well"
    },
    "thinking": {
      "color": "light_blue",
      "brightness": 60,
      "description": "Working on something"
    },
    "completed": {
      "color": "pale_green",
      "brightness": 60,
      "description": "Done!"
    },
    "need_input": {
      "color": "gold",
      "brightness": 75,
      "description": "When you have a moment..."
    },
    "waiting": {
      "color": "lavender",
      "brightness": 50,
      "description": "Ball's in your court, no rush"
    },
    "error": {
      "color": "coral",
      "brightness": 70,
      "description": "Something needs attention"
    },
    "off": {
      "description": "Light off"
    }
  },

  "events": {
    "PermissionRequest": "need_input",
    "PostToolUse.success": "completed",
    "PostToolUse.error": "error",
    "SessionStart": "idle",
    "SessionEnd": "off"
  },

  "transitions": {
    "completed": {
      "duration_ms": 2000,
      "then": "idle"
    }
  },

  "volitional": {
    "enabled": true
  }
}
```

## Direct State Control

Set states directly via the script:

```bash
# Set to thinking state
~/.claude/plugins/cache/aparente/ambient-alerts/1.0.0/scripts/set-state.sh thinking

# Set to idle
~/.claude/plugins/cache/aparente/ambient-alerts/1.0.0/scripts/set-state.sh idle

# Turn off
~/.claude/plugins/cache/aparente/ambient-alerts/1.0.0/scripts/set-state.sh off
```

## Custom Backend

For non-Hue systems (LIFX, Govee, Home Assistant, etc.):

```json
{
  "backend": "custom",
  "custom_commands": {
    "set": "hass-cli light set office --color {color} --brightness {brightness}",
    "idle": "hass-cli light set office --color white --brightness 40",
    "thinking": "hass-cli light set office --color blue --brightness 60"
  }
}
```

## Configuration Reference

| Option | Type | Description |
|--------|------|-------------|
| `backend` | string | `"openhue"` or `"custom"` |
| `light_name` | string | Name of your light (OpenHue) |
| `states` | object | State definitions with color/brightness |
| `events` | object | Event → state mappings |
| `transitions` | object | Auto-transition rules |
| `volitional.enabled` | boolean | Allow Claude to set states directly |

### State Options

| Option | Type | Description |
|--------|------|-------------|
| `color` | string | OpenHue color name |
| `brightness` | number | Brightness 0-100 |
| `description` | string | Human-readable description |

### Transition Options

| Option | Type | Description |
|--------|------|-------------|
| `duration_ms` | number | How long to stay in state |
| `then` | string | State to transition to |

## Philosophy

This plugin is about **ambient, low-stress communication**. The goal is:

- Peripheral awareness, not interruption
- Meaningful states that convey real information
- A shared visual language you design together
- Gentle transitions, not jarring alerts

The setup interview process is collaborative - you and Claude co-create the communication system that works for your workflow.

## Legacy Support

Old-style configs (with `alert_style`, `waiting_state`, etc.) continue to work. The plugin automatically detects which system to use based on whether `states` is defined.

## Requirements

- Claude Code CLI
- **OpenHue backend**: [OpenHue CLI](https://www.openhue.io/cli/openhue-cli) installed and configured
- **Custom backend**: Your preferred smart home CLI
- `jq` command-line tool

## License

MIT
