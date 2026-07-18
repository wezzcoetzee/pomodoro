---
name: Pomodoro
description: A motivating focus timer that turns deep work into visible momentum.
colors:
  focus-ember: "oklch(68% 0.19 35)"
  focus-ember-soft: "oklch(74% 0.13 35)"
  break-teal: "oklch(72% 0.11 195)"
  break-teal-soft: "oklch(78% 0.08 195)"
  streak-amber: "oklch(80% 0.16 85)"
  streak-amber-soft: "oklch(86% 0.11 85)"
  reward-amber: "oklch(84% 0.15 70)"
  canvas: "oklch(17% 0.012 35)"
  surface: "oklch(22% 0.014 35)"
  line: "oklch(34% 0.016 35)"
  ink: "oklch(95% 0.006 35)"
  ink-dim: "oklch(72% 0.012 35)"
typography:
  display:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "76px (full) / 30px (compact)"
    fontWeight: 900
    lineHeight: 1
  headline:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "20px"
    fontWeight: 700
  title:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "15px"
    fontWeight: 600
  body:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "13px"
    fontWeight: 400
  label:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "11px"
    fontWeight: 500
    letterSpacing: "0.8px"
rounded:
  bar: "2px"
  field: "10px"
  button: "14px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  xxl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.focus-ember}"
    textColor: "{colors.canvas}"
    rounded: "{rounded.button}"
    padding: "14px 0"
  ticket-badge:
    backgroundColor: "{colors.focus-ember-soft}"
    textColor: "{colors.canvas}"
    rounded: "{rounded.pill}"
    padding: "4px 9px"
  input-field:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.field}"
    padding: "10px 12px"
  history-row:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.field}"
    padding: "8px 12px"
---

# Design System: Pomodoro

## 1. Overview

**Creative North Star: "The Momentum Engine"**

This is an instrument for focus that rewards you for running it. The system treats a work session like fuel and completion like ignition: quiet and contained while a block runs, then a burst of committed color and motion the moment it finishes. Color is not decoration here, it is state. Each mode of the session owns a named color role, so the interface tells you where you are before you read a single word. The entire neutral scale re-derives from the active phase hue at runtime, so even the background carries a trace of what you are doing.

One rounded geometric sans (SF Pro Rounded) runs the whole app with aggressive weight and size contrast. The timer digits, heavy weight with monospaced figures, are the largest thing on any surface by a wide margin. Everything else steps down sharply from there.

This system explicitly rejects the **generic SaaS dashboard** (no KPI tiles, no card grids, no cool-gray sameness), the **sterile corporate tool** (no navy-and-gray enterprise chrome), and the **cluttered surface** (nothing competes with the running timer). Gamified energy is welcome, but it must read as earned and sharp, never toy-like.

**Key Characteristics:**
- Color encodes session state; neutrals are tinted per active phase hue.
- One rounded geometric sans, extreme hierarchy, the timer as hero.
- Flat and calm during a block, loud at completion.
- Momentum (streaks, counts, progress) is the emotional payload.

## 2. Colors

Four named functional roles mapped to phases of the focus loop, on a dark phase-tinted canvas. OKLCH is the single source of truth (see `DesignTokens.swift`); changing a color means changing its OKLCH triple, never a hand-tuned hex.

### Primary
- **Ember** (oklch(68% 0.19 35)): The warm driving color of an active focus block. Owns the timer digits, progress ring, and primary button while you are heads-down. **Ember Soft** (74% 0.13 35) fills the ticket badge and invalid-input hints.

### Secondary
- **Tidal Teal** (oklch(72% 0.11 195)): The cool restful color of break phases. Every role Ember plays during focus, Teal plays during breaks, so a glance tells you the mode. **Teal Soft** (78% 0.08 195) is its badge/soft counterpart.

### Tertiary
- **Charged Amber** (oklch(80% 0.16 85)): Streak flame and count, and the celebration ring burst. The app's rarest, highest-energy color.
- **Milestone Amber** (oklch(84% 0.15 70)): Reward moments at milestones.

### Neutral
All neutrals are re-derived at runtime with the active phase's hue (35 during focus/idle, 195 during breaks); values below are the hue-35 reference.
- **Canvas** (oklch(17% 0.012 h)): The window background.
- **Surface** (oklch(22% 0.014 h)): Inputs, history rows, one step forward from canvas.
- **Line** (oklch(34% 0.016 h)): Ring tracks, borders, dividers.
- **Ink** (oklch(95% 0.006 h)) / **Ink Dim** (oklch(72% 0.012 h)): Text hierarchy.
- **On-Accent**: filled accent shapes always use Canvas as their text color, never Ink; light ink on an accent fill fails AA.

Verified WCAG AA on the hue-35 canvas: ink 16.5:1, ink-dim 7.7:1, ember digits 6.1:1, teal digits 8.1:1, amber 10.1:1.

### Named Rules
**The State-Is-Color Rule.** Color is never chosen for looks alone. If the surface changes color, the session state changed. Focus, Break, Streak, and Reward each own their hue, and no role borrows another's.

**The Earned-Accent Rule.** Charged and Milestone Amber appear only at genuine momentum moments: the streak flame/count and the completion celebration. They are forbidden as ambient decoration; the history activity bars use the phase accent, not amber.

## 3. Typography

**Display Font:** SF Pro Rounded (system `.rounded` design)
**Body Font:** Same family, lighter weights
**Label/Mono Font:** Same family with `monospacedDigit()` for the timer and streak numbers

**Character:** One confident rounded geometric sans doing all the work through weight and scale. Precise and energetic, never soft or corporate.

### Hierarchy
- **Display / Timer** (heavy 900, 76px full / 30px compact, monospaced digits): The countdown. The single largest element on every surface.
- **Streak Number** (heavy, 34px, monospaced digits): The streak count in history.
- **Headline** (bold, 20px): Mode labels and section titles.
- **Title** (semibold, 15px): Session names, controls.
- **Body** (regular, 13px): Settings text, history descriptions.
- **Label** (medium, 11px, +0.8px kerning, uppercase): Stat labels, badges, small metadata.

### Named Rules
**The Hero-Digit Rule.** The timer is always the largest thing on the screen during a session. Digits are monospaced so nothing jitters as they tick, including in the menu bar countdown.

## 4. Elevation

Flat by default, everywhere. Depth is conveyed by the two-step tonal ladder (canvas → surface) rather than shadows; there is no shadow vocabulary in the app. Stats and history sit one layer back, revealed on demand rather than stacked on screen. Panels (pinned panel, mini card) rely on the system's window layering, not decorative shadows.

### Named Rules
**The Flat-At-Rest Rule.** During an active block the surface is flat and quiet. The only motion is the ring's progress fill; the only lift is the completion celebration.

## 5. Components

### Buttons
- **Shape:** Continuously-rounded rectangle (14px radius) for the primary start button; plain circular hit areas (46-64px) for transport controls.
- **Primary:** Phase accent fill, canvas-colored label, 14px vertical padding, full width of the setup card (360px).
- **Transport (play/pause/skip):** Borderless circular buttons; the main control is 64px (40px in compact), secondary controls 46px.
- **Hover / Focus:** Flat at rest; system focus ring respected.

### Chips
- **Ticket badge:** Capsule, accent-soft fill, canvas text, 9x4px padding, uppercase label type. Clickable, deep-links to the Jira/GitHub ticket.
- **Preset summary:** Capsule, surface fill, 8x4px padding.

### Cards / Containers
- **History rows:** Surface fill, 10px continuous radius, 12x8px padding, 1px line border only where separation is needed. Never nested.
- **Setup card:** 28px internal padding, 360px wide.

### Inputs / Fields
- **Style:** Surface fill, 10px continuous radius, 1px line stroke, 12x10px padding.
- **Ticket parse feedback:** Live; invalid input shifts the stroke to accent-soft rather than a red error state.

### Navigation
- **Status item:** Phase-tinted timer glyph, optional live MM:SS countdown in monospaced digits (fixed width, no jitter). Left-click toggles the active surface; right-click opens Settings/Quit menu.

### The Timer Ring (signature)
- Full: 240px ring, 16px stroke; compact: 74px ring, 7px stroke. Line-colored track, phase-accent progress arc with round caps, digits centered. Ring fill animates 0.3s ease-in-out, instant under reduced motion. The celebration replays the ring in Charged Amber (150px, 14px stroke) for under 1.5s.

## 6. Do's and Don'ts

### Do:
- **Do** let color encode session state; derive every color from the OKLCH triples in `DesignTokens.swift`, never a hand-tuned hex (the status item tint included).
- **Do** make the timer digits the hero: largest element on every surface, monospaced figures.
- **Do** keep the active session surface calm and flat, then spend Charged Amber and motion on the completion moment only.
- **Do** tint every neutral toward the active phase hue; never `#000` or `#fff`.
- **Do** honor `accessibilityReduceMotion` in every animated view (ring fill and celebration both branch on it); motion degrades to instant state changes without losing information.
- **Do** use Canvas as the text color on any accent fill (the On-Accent rule); Ink on accent fails AA.

### Don't:
- **Don't** build a **generic SaaS dashboard**: no KPI tiles, no hero-metric template, no identical card grids, no cool-gray Inter-everywhere sameness.
- **Don't** go **sterile corporate**: no navy-and-gray enterprise chrome, no humorless flat tool.
- **Don't** clutter the focus surface. Stats and history live one layer back behind an explicit toggle.
- **Don't** spend Charged or Milestone Amber as ambient decoration; the history bars use the phase accent.
- **Don't** reach for gradient text, side-stripe borders, glassmorphism, or decorative shadows; the system is flat with a tonal ladder.
- **Don't** use em dashes in any UI copy.

*Known exception: SettingsView uses stock grouped Form styling with system semantic colors, a deliberate native-controls tradeoff for the preferences pane.*
