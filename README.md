# ambient-alerts

A Claude Code plugin that uses your smart lights for ambient notifications. Get visual feedback when Claude needs your attention - customized to your vibe.

## Features

- **Multiple alert styles** - flash, pulse, solid, or subtle
- **Vibe-based setup** - tell Claude what you want and it configures for you
- **Works with any smart light** - Philips Hue (via OpenHue) or custom commands
- **Session-isolated** - multiple Claude sessions don't interfere
- **Fully customizable** - colors, brightness, timing, everything

## Alert Styles

| Style | Vibe | Best For |
|-------|------|----------|
| ⚡ **Flash** | Urgent, can't miss it | Important permission requests |
| 🌊 **Pulse** | Calm awareness | Subtle but noticeable |
| 💡 **Solid** | Minimal | Just a color change |
| 🌙 **Subtle** | Zen mode | Deep focus, peripheral only |

## Installation

```bash
/plugin marketplace add aparente/ambient-alerts
/plugin install ambient-alerts@aparente
```

## Setup

### Interactive Setup (Recommended)

Just ask Claude:
```
Set up ambient alerts for my lights
```

Claude will interview you about:
1. What smart light system you use
2. Which light to use for notifications
3. What vibe you're going for
4. Color and brightness preferences
5. Test and fine-tune until it feels right

### Manual Setup

Create `~/.claude/ambient-alerts.json`:

**Flash style (attention-grabbing):**
```json
{
  "backend": "openhue",
  "light_name": "TV",
  "alert_style": "flash",
  "styles": {
    "flash": {
      "flash_color": "cyan",
      "flash_brightness": 100,
      "flash_count": 3,
      "flash_duration_ms": 120
    }
  },
  "waiting_state": {
    "enabled": true,
    "color": "powder_blue",
    "brightness": 50
  },
  "restore_on_complete": true
}
```

**Pulse style (calm):**
```json
{
  "backend": "openhue",
  "light_name": "Desk Lamp",
  "alert_style": "pulse",
  "styles": {
    "pulse": {
      "pulse_color": "warm_white",
      "pulse_min_brightness": 20,
      "pulse_max_brightness": 80,
      "pulse_duration_ms": 1000
    }
  },
  "waiting_state": {
    "enabled": true,
    "color": "soft_pink",
    "brightness": 40
  },
  "restore_on_complete": true
}
```

**Subtle style (minimal):**
```json
{
  "backend": "openhue",
  "light_name": "Office Light",
  "alert_style": "subtle",
  "styles": {
    "subtle": {
      "dim_percent": 20
    }
  },
  "waiting_state": {
    "enabled": false
  },
  "restore_on_complete": true
}
```

## Custom Commands Backend

For non-Hue systems (LIFX, Govee, Home Assistant, etc.):

```json
{
  "backend": "custom",
  "save_state_command": "hass-cli light get office --json",
  "alert_command": "hass-cli light flash office --color red",
  "waiting_command": "hass-cli light set office --color blue",
  "restore_command": "hass-cli light restore office",
  "waiting_state": {
    "enabled": true
  },
  "restore_on_complete": true
}
```

## How It Works

1. **PermissionRequest** → Saves light state, runs alert animation, optionally stays on waiting color
2. **PostToolUse** → Restores light to original state

## Configuration Reference

| Option | Type | Description |
|--------|------|-------------|
| `backend` | string | `"openhue"` or `"custom"` |
| `light_name` | string | Name of your light (OpenHue) |
| `alert_style` | string | `"flash"`, `"pulse"`, `"solid"`, `"subtle"` |
| `waiting_state.enabled` | boolean | Stay on waiting color until complete |
| `waiting_state.color` | string | Color while waiting |
| `waiting_state.brightness` | number | Brightness while waiting (0-100) |
| `restore_on_complete` | boolean | Restore to original after tool completes |

### Flash Style Options
| Option | Default | Description |
|--------|---------|-------------|
| `flash_color` | `"cyan"` | Color of the flash |
| `flash_brightness` | `100` | Flash brightness (0-100) |
| `flash_count` | `3` | Number of flashes |
| `flash_duration_ms` | `120` | Duration of each flash |

### Pulse Style Options
| Option | Default | Description |
|--------|---------|-------------|
| `pulse_color` | `"warm_white"` | Pulse color |
| `pulse_min_brightness` | `20` | Minimum brightness |
| `pulse_max_brightness` | `80` | Maximum brightness |
| `pulse_duration_ms` | `1000` | Duration of each pulse |

### Solid Style Options
| Option | Default | Description |
|--------|---------|-------------|
| `solid_color` | `"powder_blue"` | Color to change to |
| `solid_brightness` | `60` | Brightness |

### Subtle Style Options
| Option | Default | Description |
|--------|---------|-------------|
| `dim_percent` | `20` | How much to dim (%) |

## Requirements

- Claude Code CLI
- **OpenHue backend**: [OpenHue CLI](https://www.openhue.io/cli/openhue-cli) installed and configured
- **Custom backend**: Your preferred smart home CLI
- `jq` and `bc` command-line tools

## License

MIT
