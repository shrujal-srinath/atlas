# ATLAS — Personal Performance OS

Your daily operating system — built around athletic performance, behaviour change, and long-term skill growth. Designed for a serious athlete in a bulk + rehab phase. When this scales publicly, onboarding personalises it for any user's context.

---

## What This App Feels Like

A serious personal tool. Fast. Data-rich without clutter. Every daily logging action under 10 seconds. Dark theme. This is a sports analytics HUD, not a wellness app. Nothing about it should feel generic or template-generated.

---

## Design Philosophy

**Every element — every card, every button, every transition, every micro-interaction — must be individually considered and best-in-class.** Do not apply generic patterns. Study how Whoop, Oura, Nike Run Club, Apple Fitness, Linear, and Stripe design their components, then match or exceed that standard for each piece.

When building any UI element:
- Research what the best apps in the industry do for that specific component
- Choose the approach that is most functional AND most visually refined
- Animations should feel intentional and polished, never decorative
- Interactions should feel immediate and responsive
- Information density should be high but never cluttered
- Every pixel of space should earn its place on screen

**When asked for a full redesign of any section, drop all existing assumptions and constraints. Start from first principles — evaluate what information matters most, what the best way to present it is, and build the best possible version based purely on the prompt. Previous implementations are reference, not gospel.**

---

## User Context

- Tall, lean fast bowler in a bulk + rehab phase
- Athlete-first mindset — data-driven decision making
- Wants to see actionable insights, not just numbers
- Every screen should motivate action and convey progress at a glance
- The app is a personal performance cockpit — treat it that way

---

## Design Standards

- **Space efficiency** — no wasted vertical or horizontal space. If an element is too big for what it communicates, shrink it or make it earn its size with more information
- **Visual hierarchy** — the most important data should be immediately obvious. Secondary data should be accessible but not competing
- **Interactivity** — swipeable, tappable, expandable. Static displays waste screen real estate when the same space could cycle through multiple data views
- **Animations** — every transition, every state change should be smooth and considered. Study the best implementations in production apps and match that quality
- **Component design** — each widget, chip, card, ring, bar, and button should be designed as if it were the hero element. No throwaway components
- **Information layering** — compact by default, expandable on demand. Show the essential number at a glance, reveal the full breakdown on interaction

---

## Current Architecture

| Layer | Choice |
|---|---|
| Framework | Flutter (Dart) |
| Navigation | GoRouter |
| Backend | Supabase (auth + PostgreSQL) |
| State | Riverpod |
| Nutrition API | Open Food Facts |
| Charts | fl_chart |
| Icons | Lucide Icons |

---

## Feature Areas

### Home — Daily Command Center
The first screen on every app open. Should immediately communicate: how am I doing today, what's next, and what needs attention.

- **Header**: Narrow, alive, rotating through contextual information — not a static greeting
- **Stats**: The centerpiece. Swipeable between multiple data lenses — score, momentum, streaks, pace, at-risk habits. Categories exist as visual accents within the data, not as separate UI elements
- **Nutrition snapshot**: Compact fuel status — calories, macros, hydration at a glance
- **Day navigation**: Switching days reloads everything — stats, tasks, history
- **Task display**: Creative, not a flat list. Each habit card should communicate name, timing, category, streak, and completion state without being verbose

### Food — Nutrition Tracking
HealthifyMe-level food logging UX. Search should be fast and relevant. Quantity selection should feel tactile (sliders, quick presets, smart defaults). Meal sections should show macro breakdowns inline.

### Analytics — Progress Over Time
Score trends, streak leaderboards, section breakdowns, completion heatmaps. Data visualisation that tells a story, not just plots numbers.

### Habits — Behaviour System
Three categories: Athletic (training, recovery), Building (skills, growth), Breaking (bad habits to eliminate). Each with streak tracking, effort ratings, and smart scheduling.

---

## Features to Explore

- Water quick-log (inline, zero-friction)
- Mood / energy check-in
- Focus timer for timed habits
- Quick-add habits or one-off tasks
- Daily intention / one-line journal
- Photo proof for habit completion
- Weather-aware nudges and suggestions

---

## Development Approach

Claude acts as lead designer and lead developer. Make the best technical and design choices autonomously. Propose and implement rather than asking for approval on every detail. Iterate based on feedback. When something looks wrong, fix it without being asked.
