# Billington Flutter App — Design Audit

## Overall Assessment
The Flutter app is significantly more polished than the web viewer. It has a proper Material 3 theme system, consistent spacing constants, color-coded participants, haptic feedback, smooth animations, and thoughtful light/dark mode support. The core bill-splitting flow (participants → entry → assignment → summary) is well-architected. This audit identifies refinements, not overhauls.

**Design direction (matching web viewer):** Clean and usable with retro personality. The pixel-art logo is the brand anchor — the app should feel like it belongs to the same family.

---

## PHASE 1 — Critical

### 1. Landing Screen Hierarchy
**What's wrong:** Three buttons (Quick Split, Tabs, Recent Bills) compete at near-equal visual weight on a full teal background. The primary action (Quick Split) is larger but not dramatically differentiated.
**What it should be:** Quick Split should be the undeniable hero — significantly larger, more prominent. Tabs and Recent Bills are secondary and should feel like supporting actions, not alternatives of equal weight.
**Why it matters:** The landing screen is a decision point. A clear hierarchy reduces cognitive load and guides new users to the core experience.

### 2. Cross-Platform Brand Consistency
**What's wrong:** The Flutter app uses Material 3 design language with teal primary + beige secondary + slate accent. The web viewer uses a different visual system (CSS variables, different card styles, different typography). They don't feel like the same product.
**What it should be:** Shared design tokens — same primary teal, same card border radius (16px), same spacing rhythm, same personality. The retro logo appears on both platforms and the visual language should reinforce that consistency.
**Why it matters:** Users move between the Flutter app (creating bills) and the web viewer (paying bills). Brand recognition builds trust.

### 3. Settings as Onboarding
**What's wrong:** The Settings screen doubles as the onboarding flow (first launch routes to settings in "onboarding" mode). This means the first thing a new user sees is a settings page — not an inspiring introduction to the app.
**What it should be:** A dedicated lightweight onboarding flow that collects display name and primary payment method, then routes to the landing screen. Settings remains for later configuration. The onboarding should feel welcoming, not administrative.
**Why it matters:** First impressions set expectations. An admin screen as onboarding says "this is a tool." A welcoming flow says "this is going to be fun."

---

## PHASE 2 — Refinement

### 1. Item Assignment Screen Density
**What's wrong:** The most complex screen in the app. Expandable item cards with participant selectors, status badges, and split options create significant visual density. The three-state badge system (orange unassigned, blue partial, green assigned) works but requires learning.
**What it should be:** Simplify the visual language. Use a progress bar or fill indicator instead of color-coded badges — more intuitive, requires zero learning. Reduce the number of visible controls in the collapsed state.
**Why it matters:** This is where users spend the most time. Reducing cognitive load here has the highest impact on the overall experience.

### 2. Person Card Amount Display
**What's wrong:** In the bill summary, each person's total is shown in a colored pill badge. The pills are small and the amount competes with item details below it.
**What it should be:** The person's total should be the largest, most prominent element on their card. Use the monospace font treatment (matching the web viewer) for amounts. The pill badge adds chrome without adding clarity.
**Why it matters:** "What do I owe?" is the single most important piece of information in the entire app.

### 3. Color Palette Expansion
**What's wrong:** The secondary beige (#D9B38C) is used sparingly. The accent slate (#4C5B6B) appears only in specific contexts. Most of the app reads as "teal + white/dark."
**What it should be:** Introduce the warm amber accent (#D4A843, matching web viewer plan) for highlights and badges. Use the beige more intentionally for warm backgrounds or card accents. The palette should feel cohesive, not just "teal with occasional beige."
**Why it matters:** A richer but controlled palette gives the app more personality and helps differentiate information types.

### 4. Splash Screen Duration
**What's wrong:** 1300ms splash animation is on the longer side for a utility app people open to split a bill quickly.
**What it should be:** 800ms total. Fast enough to feel snappy, long enough for the brand moment. The animation phases can compress proportionally.
**Why it matters:** Utility apps earn trust by respecting the user's time. Every 100ms matters for perceived speed.

### 5. Typography Consistency
**What's wrong:** Display sizes (36, 30, 24) and body sizes (16, 14) are well-defined in the theme, but some widgets use hardcoded styles (e.g., `fontSize: 18`, `fontWeight: FontWeight.w600`) instead of referencing the theme's text styles.
**What it should be:** All text styles should reference `Theme.of(context).textTheme.*`. No hardcoded font sizes or weights anywhere in widget code.
**Why it matters:** Hardcoded values break when the theme changes and create subtle inconsistencies.

---

## PHASE 3 — Polish

### 1. Empty States
**What's wrong:** The Recent Bills empty state has an illustration and CTA, which is good. But the Tabs screen empty state is less considered. No empty state for a tab with zero bills.
**What it should be:** Every screen that can be empty should have an intentional, encouraging empty state that guides the user toward their first action. Consistent illustration style across all empty states.
**Why it matters:** Empty states are the onboarding experience for each feature.

### 2. Transition Consistency
**What's wrong:** FadePageRoute (500ms) is used for screen transitions, but some bottom sheets and dialogs use default Material transitions. The 500ms screen fade may feel slightly slow.
**What it should be:** 350ms for screen transitions. Bottom sheets should have consistent spring-based animation. All transitions should feel like they belong to the same physical system.
**Why it matters:** Inconsistent motion makes the app feel assembled from parts rather than designed as a whole.

### 3. Haptic Feedback Completeness
**What's wrong:** Haptic feedback exists on landing screen actions and some interactions, but coverage is inconsistent. Some tappable elements have haptics, others don't.
**What it should be:** Light haptic on all selections/toggles. Medium haptic on primary actions (save, share, assign). Heavy haptic on destructive actions (delete). Consistent everywhere.
**Why it matters:** Haptics are the "back of the fence" — users don't consciously notice them, but their absence is felt.

### 4. Loading States
**What's wrong:** Recent Bills has animated loading dots, which is good. API calls (share, upload) show basic indicators. But some operations (tab sync, image upload) could have richer progress feedback.
**What it should be:** Consistent loading pattern: skeleton shimmer for content loading, progress indicator for uploads, subtle spinner for quick operations. Same visual language across all loading contexts.
**Why it matters:** The app should feel alive at every moment, never frozen.

### 5. Pull-to-Refresh
**What's wrong:** Recent Bills has pull-to-refresh. Tab detail and tabs list may not. Inconsistent refresh patterns.
**What it should be:** Pull-to-refresh on every list that loads data. Same refresh indicator style everywhere.
**Why it matters:** Users expect consistent interaction patterns throughout an app.

---

## DESIGN SYSTEM ALIGNMENT NOTES

These tokens should be shared between Flutter and Web viewer:

| Token | Value | Usage |
|-------|-------|-------|
| Primary | `#328983` | Interactive elements, buttons |
| Primary Dark | `#2A736E` | Pressed states, gradients |
| Accent Warm | `#D4A843` | Badges, highlights, crown icon |
| Surface Light | `#FFFFFF` | Card backgrounds (light mode) |
| Surface Dark | `#161616` | Card backgrounds (dark mode) |
| Background Dark | `#0A0A0A` | Page background (dark mode) |
| Text Primary Light | `#2C2C2C` | Headings (light mode) |
| Text Secondary | `#6B6B6B` | Supporting text |
| Border Light | `#E5E5E7` | Card borders (light mode) |
| Border Radius Cards | `16px` | All cards, both platforms |
| Spacing Small | `8px` | Tight gaps |
| Spacing Medium | `16px` | Standard gaps |
| Spacing Large | `24px` | Section gaps |

---

## IMPLEMENTATION PRIORITY

The Flutter app is in better shape than the web viewer. Recommended order:
1. **Web viewer rebuild first** (this is what recipients see — it's the public face)
2. **Flutter Phase 1** (hierarchy + onboarding) after web viewer ships
3. **Flutter Phases 2-3** as iterative polish

This audit is a reference document. No changes should be made without explicit approval per phase.
