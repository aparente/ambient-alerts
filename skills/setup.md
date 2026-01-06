# ambient-alerts Setup Skill

A collaborative, playful interview to design your ambient light communication system with Claude.

## Invocation

Use this skill when:
- User runs `/ambient-setup` or `/setup-ambient-alerts`
- User asks to "set up ambient alerts" or "configure light notifications"
- User wants to "customize how Claude communicates through lights"
- User installs the ambient-alerts plugin and needs configuration

## The Vibe

This isn't a form to fill out - it's a conversation about how we'll communicate. Be curious, playful, and collaborative. Demo things live. Adjust based on reactions. The goal is to co-create a visual language that feels right.

---

## Phase 1: Getting to Know Your Setup

### Light System Discovery

Start with genuine curiosity:

```
"Hey! I'd love to set up a way to communicate with you through your lights.
What smart light system do you have? (Philips Hue, LIFX, Home Assistant, something else?)"
```

If Hue, verify OpenHue:
```
"Nice! Let me check if OpenHue CLI is set up..."
*runs `openhue get lights`*
"Found your lights! Which one should be 'mine' for our communication?"
```

Show them the options with personality:
```
"I see you have:
- Pitcher (a Bloom - compact, great for desk presence)
- TV (lightstrip - dramatic but might annoy anyone watching)
- Signe floor lamps (fancy! very visible)

Which one feels right for this?"
```

---

## Phase 2: Automatic Events

### Explain with Examples

```
"First, let's set up what happens automatically - things I don't choose,
they just happen based on what's going on.

The big one: when I need your permission to do something.
Should the light grab your attention, or just... softly suggest?"
```

### Permission Requests

Demo options live:
```
*sets light to bright gold*
"This is 'HEY I NEED YOU' mode - bright gold, can't miss it"

*sets light to softer amber*
"This is 'when you have a moment' - noticeable but chill"

*dims slightly*
"Or I could be super subtle - just a hint in your peripheral vision"

"What feels right?"
```

Iterate based on feedback:
```
User: "The gold but less intense"
*adjusts to 60%*
"How about this?"
```

### Completion & Errors

```
"When I finish something successfully, should I flash a little 'done!' or just... quietly return to normal?"
```

```
"What about when something goes wrong? I'm thinking a warm coral -
noticeable but not alarming. Not angry red, more like 'hey, heads up'"
*demos coral*
"Too much? Too little?"
```

### The Room-Matching Option

If they want minimal idle presence:
```
"Here's a fun option for idle - instead of a fixed color, I can match
whatever your room's other lights are doing. So I blend in until I
actually need to tell you something.

Want to see it?"
*runs match-room script*
"I just averaged the colors from your other lights. Sneaky, right?"
```

---

## Phase 3: Volitional Mode (The Fun Part!)

### Introduce the Concept

```
"Okay, here's where it gets interesting. Everything so far is automatic -
the system triggers it. But I can also express things on my own.

Like... when I'm deep in thought on something complex, I could shift
to a cooler blue. When I'm waiting for you to respond, maybe a calm
lavender. It's me choosing to communicate, not just reacting to events.

Want to set that up? It's totally optional - some people prefer
'only bug me when you need permission' and that's valid."
```

### If They Want Volitional Mode

```
"Sweet! Let's design my emotional palette.

First: 'thinking' - when I'm working through something meaty.
I'm picturing a shift to blue... let me show you"
*sets to light_blue 60%*
"This says 'I'm here, I'm working, give me a sec'"
```

```
"'Waiting' - when I've said my piece and the ball's in your court.
Not urgent, just... present."
*sets to lavender 50%*
"Calm but distinct from idle"
```

```
"'Completed' - a little victory flash when I finish something.
Brief green, then back to idle?"
*sets to pale_green, waits 2 sec, returns to idle*
"Or skip it if that's too much celebration for your taste"
```

### The Big Question

```
"So the question is: do you want me to be expressive (thinking, waiting,
celebrating completions) or minimal (only signal when I actually need you)?

There's no wrong answer - it's about what feels right in your space."
```

Options:
1. **Expressive** - "I want to see what you're doing"
2. **Minimal** - "Just tell me when you need permission"
3. **Custom** - "Let me pick which states I want"

---

## Phase 4: Fine-Tuning

### Demo the Full Range

```
"Let me run through everything so you can see the full palette..."

*cycles through all configured states with pauses*

"idle → thinking → completed → idle → need_input → waiting → error → idle

How'd that feel? Anything jarring? Anything too subtle?"
```

### Iterate Until It Clicks

```
"We can tweak any of these. Colors, brightness, timing.
This is your space - I want to fit into it, not dominate it."
```

---

## Phase 5: Generate Config

Based on the interview, create `~/.claude/ambient-alerts.json`:

**Expressive mode example:**
```json
{
  "backend": "openhue",
  "light_name": "Pitcher",
  "states": {
    "idle": { "mode": "match_room" },
    "thinking": { "color": "light_blue", "brightness": 60 },
    "completed": { "color": "pale_green", "brightness": 60 },
    "need_input": { "color": "magenta", "brightness": 55 },
    "waiting": { "color": "lavender", "brightness": 50 },
    "error": { "color": "coral", "brightness": 70 },
    "off": {}
  },
  "events": {
    "PermissionRequest": "need_input",
    "PostToolUse.success": "completed",
    "PostToolUse.error": "error",
    "SessionStart": "idle",
    "SessionEnd": "off"
  },
  "transitions": {
    "completed": { "duration_ms": 2000, "then": "idle" },
    "error": { "duration_ms": 5000, "then": "idle" }
  },
  "volitional": { "enabled": true }
}
```

**Minimal mode example:**
```json
{
  "backend": "openhue",
  "light_name": "Pitcher",
  "states": {
    "idle": { "mode": "match_room" },
    "need_input": { "color": "magenta", "brightness": 55 },
    "error": { "color": "coral", "brightness": 70 },
    "off": {}
  },
  "events": {
    "PermissionRequest": "need_input",
    "PostToolUse.success": "idle",
    "PostToolUse.error": "error",
    "SessionStart": "idle",
    "SessionEnd": "off"
  },
  "transitions": {
    "error": { "duration_ms": 5000, "then": "idle" }
  },
  "volitional": { "enabled": false }
}
```

---

## Closing the Loop

```
"Alright, we're set up! Here's what we landed on:

[summary table of their choices]

The light is now our little communication channel. I'll try not to
abuse it - promise to only signal when it's actually meaningful.

Want to test it with a real permission request?"
```

---

## Philosophy Reminders

- **Demo everything live** - Don't describe, show
- **Iterate freely** - "Too bright" → adjust → "Better?"
- **Respect minimalism** - Some people want less, not more
- **Make it feel collaborative** - This is co-design, not configuration
- **Have fun with it** - This is kind of magical when you think about it
