# ambient-alerts Setup Skill

This skill guides users through setting up ambient-alerts with their preferred smart light system and notification style.

## Invocation

Use this skill when:
- User runs `/ambient-setup` or `/setup-ambient-alerts`
- User asks to "set up ambient alerts" or "configure light notifications"
- User installs the ambient-alerts plugin and needs configuration

## Interview Flow

### Step 1: Smart Light System

Ask the user what smart light system they use:

**Questions to ask:**
- "What smart light system do you use? (Philips Hue, LIFX, Govee, Home Assistant, other)"
- If Hue: "Do you have OpenHue CLI installed? (Run `openhue --version` to check)"
- If other: "What command-line tool or API do you use to control your lights?"

**Based on response, set `backend`:**
- Philips Hue with OpenHue → `"openhue"`
- Anything else → `"custom"` (will need custom commands)

### Step 2: Light Selection

For OpenHue users:
- Run `openhue get light` to list available lights
- Ask: "Which light should I use for notifications?"
- Set `light_name` to their choice

For custom users:
- Ask: "What command saves your light's current state?"
- Ask: "What command restores the light to a saved state?"

### Step 3: Vibe Selection

Present the ambient interaction styles:

```
What vibe are you going for?

1. ⚡ FLASH - Quick, attention-grabbing pulses
   Best for: When you really can't miss a notification

2. 🌊 PULSE - Gentle breathing effect
   Best for: Subtle but noticeable, calming

3. 💡 SOLID - Simple color change
   Best for: Minimal distraction, just a color shift

4. 🌙 SUBTLE - Barely noticeable dim
   Best for: Deep focus mode, peripheral awareness only
```

Set `alert_style` based on their choice.

### Step 4: Color Preferences

Based on their chosen style, ask about colors:

**For flash:**
- "What color should the flash be? (cyan, red, magenta, white, etc.)"
- Default: cyan (high visibility, distinct from most ambient lighting)

**For pulse:**
- "What color should the pulse be?"
- Default: warm_white (calming)

**For solid:**
- "What color indicates 'waiting for input'?"
- Default: powder_blue (calm but distinct)

### Step 5: Waiting State

Ask: "Should the light stay a different color while waiting for your response, or just flash and return to normal?"

Options:
- Stay on waiting color until you respond (set `waiting_state.enabled: true`)
- Flash only, return to normal immediately (set `waiting_state.enabled: false`)

### Step 6: Generate Config

Create the config file at `~/.claude/ambient-alerts.json` based on their answers.

Example for a "chill" user with Hue:
```json
{
  "backend": "openhue",
  "light_name": "Desk Lamp",
  "alert_style": "pulse",
  "styles": {
    "pulse": {
      "pulse_color": "warm_white",
      "pulse_min_brightness": 30,
      "pulse_max_brightness": 70,
      "pulse_duration_ms": 1500
    }
  },
  "waiting_state": {
    "enabled": true,
    "color": "powder_blue",
    "brightness": 40
  },
  "restore_on_complete": true
}
```

Example for an "attention-grabbing" user:
```json
{
  "backend": "openhue",
  "light_name": "TV",
  "alert_style": "flash",
  "styles": {
    "flash": {
      "flash_color": "red",
      "flash_brightness": 100,
      "flash_count": 5,
      "flash_duration_ms": 100
    }
  },
  "waiting_state": {
    "enabled": true,
    "color": "orange",
    "brightness": 60
  },
  "restore_on_complete": true
}
```

### Step 7: Test

After creating config, offer to test:
- "Want me to test the notification? I'll trigger a permission request so you can see it in action."
- If they say yes, attempt a tool that needs permission

### Step 8: Fine-tuning

Ask: "How did that feel? Want to adjust anything?"
- Too subtle → increase brightness or switch to flash
- Too aggressive → decrease brightness or switch to pulse/subtle
- Wrong color → change colors
- Iterate until they're happy

## Output

Write the final config to `~/.claude/ambient-alerts.json` and confirm setup is complete.

## Vibes Reference

| Vibe | Style | Best For | Default Colors |
|------|-------|----------|----------------|
| Urgent | flash | Can't miss it | cyan/red |
| Focused | pulse | Aware but not jarring | warm_white |
| Minimal | solid | Just need to know | powder_blue |
| Zen | subtle | Deep work mode | (dim current) |
