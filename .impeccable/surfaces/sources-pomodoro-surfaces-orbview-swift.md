---
version: 1
slug: "sources-pomodoro-surfaces-orbview-swift"
primary_target: "Sources/Pomodoro/Surfaces/OrbView.swift"
related_targets: ["Sources/Pomodoro/Shell/OrbController.swift"]
---

# Floating orb

Scope: the always-on presence that floats over every app (`OrbView`, `OrbController`). Visitor mode: Operate.

Audience and job: the PRODUCT.md user, heads-down in another app, who forgets Pomodoro exists because it hides in the menu bar. Task: notice you have gone too long without a block and start one in one click; while a block runs, glance at minutes left.

Constraints: established Momentum Engine world (DESIGN.md), unchanged. Escalation thresholds 20 and 45 minutes idle. Click while idle starts a 25 minute block instantly with no setup. No continuously repainting animation. Honors Reduce Motion.

Memorable moment: the "Start focus" pill sliding out of the orb, once, the first time you cross 20 minutes idle.

Unresolved: work-hours gating of escalation (deferred).

## Direction contract

THESIS: Pomodoro owns a corner of every screen and asks for a block in proportion to how long you have gone without one. It refuses the category default of a status item that waits to be remembered.

OWN-WORLD: Canvas disc, Line ring track, phase accent arc (Ember in focus, Tidal Teal on break), heavy rounded monospaced minutes inside. Ember capsule with Canvas text for the urgent pill, Ember outline for the nudge pill. Window shadow only. No amber.

STORY: The user sees a quiet dim dot in the corner of their editor. At 20 minutes idle a "Start focus" pill slides out once; at 45 it fills Ember and shows idle minutes. One click starts focus. While running the ring counts down; hover reveals pause and skip; clicking the ring opens the full timer.

FIRST VIEWPORT: Bottom-right of the visible screen frame, 20px inset. A 56px orb sits at the corner; the 40px pill extends toward screen center from behind it. Drag snaps to any corner. Nothing else on screen belongs to Pomodoro.

FORM: Floating orb, position 1 of 7 on the ordered list. seed:87d5749f42895e2e

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
