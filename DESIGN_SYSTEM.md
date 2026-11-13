# Billington Design System

This file records the existing visual language used by the mobile app and web bill viewer. It is a reference for implementation, not a proposal to change the brand.

## Color

Web CSS variables in `web-bill-viewer/src/app/globals.css` are the source for web colors:

| Token | Existing value | Use |
| --- | --- | --- |
| `--primary` | `#328983` | Main actions and selected states |
| `--primary-dark` | `#2a736e` | Darker action and text treatment |
| `--primary-light` | `#4a9b95` | Light brand accent |
| `--secondary` | `#f5f5f7` | Soft backgrounds |
| `--accent` / `--text-dark` | `#1d1d1f` | Primary text |
| `--accent-warm` | `#d4a843` | Warm brand accent |
| `--text-secondary` | `#6e6e73` light / `#98989d` dark | Supporting text on opaque surfaces |
| `--border-light` | `#e5e5e7` | Light theme dividers and outlines |
| `--border-dark` | `#2d2d2f` | Dark theme dividers and outlines |
| `--dark-bg` | `#0a0a0a` | Dark page background |
| `--card-bg-light` | `#ffffff` | Light cards |
| `--card-bg-dark` | `#161616` | Dark cards |

Flutter uses the matching `AppTheme` colors in `mobile/lib/config/theme.dart`. Users can change the primary accent through the existing app setting.

Participant colors belong to their saved occurrence, not amount rank. Single-person rosters and several people choosing the same color are valid data. Preserve receipt occurrence ordinals and references. Use the existing `AppTheme.foregroundOn` on the changed light-theme avatar, panel and row surfaces; preserve ink that already reads. Bill Details avatar initials derive ink from their composited surface in both themes. Other dark-theme branches are unchanged by this candidate. Shared items use the existing neutral palette instead of implying one person owns them.

## Typography

- Web uses Inter for interface text and JetBrains Mono for monetary figures and other aligned numeric values.
- Flutter uses Material 3 text styles. Existing hierarchy uses 36/30/24 px bold display styles, 20 px semibold headline, 18 px semibold title, and 16/14 px body text.
- Web paid cards stay opaque; check avatars, strike-through, green amounts and borders show paid state. Locked item controls and names may dim, while status text keeps full secondary ink.
- Use the secondary text color for instructions and metadata. Keep currency values in the existing monospace treatment where the surrounding component already uses it.
- On Settings accent surfaces, derive readable ink from the effective base, blended panel, input or button surface with `AppTheme.foregroundOn`. Supporting text keeps its smaller type hierarchy with readable ink; preserve the user's accent and use it for text only when contrast permits.

## Spacing and shape

- Flutter spacing constants are 8, 16, and 24 px (`AppSpacing.small`, `medium`, `large`).
- Web layouts use Tailwind spacing utilities already present in adjacent components; keep new screens aligned to their card padding and vertical rhythm.
- Keep Flutter screen bodies between the system side insets with `SafeArea(top: false, bottom: false)` when the app bar and footer handle their own insets. Size proportional bars from layout constraints, not `MediaQuery.size`, because side insets narrow the body.
- Cards and input fields use a 16 px radius in Flutter. Web cards use the established rounded-xl through rounded-3xl treatments according to hierarchy.
- Existing web cards use subtle shadows in light mode and border definition in dark mode. Keep focus and disabled states visible.

## Interaction patterns

- One primary action per step, with secondary navigation presented as a quiet text or outlined action.
- Keep item selection rows thumb-friendly and visibly distinguish available, selected, unavailable, and paid items.
- Show four real avatars for four assignees; above four, show three avatars and the remaining-person count. Keep item counts singular/plural and chevrons consistent with actual expansion. Auto-added owners may reuse their saved custom color while receiving fresh occurrence references.
- Settings accent choices expose distinct color names, button roles and selected states. Keep at least 48 logical points per target by reducing columns at narrow widths; allow Settings row titles and action text to wrap. Payment-row options use a method-name tooltip without an identifier.
- Confirmation sheets pin their actions and scroll everything above them, so every row and both actions stay reachable on short displays and at large text. The Finalize sheet keeps its 70% height limit, except that a display shorter than about 630 points may use up to 440 points (or its full height). At accessibility text sizes a settlement amount moves below its name; action labels shrink to fit rather than wrap, and money is never truncated.
- Tab detail wraps the Per Person heading at any text size where it would otherwise overflow. Above 150% text size, Per Person and receipt cards place amounts below their other content, allowing full monetary text to wrap. Default text geometry and the floating action button stay unchanged. Empty-state copy preserves the entered tab name.
- Preserve keyboard operation, descriptive labels, and accessible error announcements in web controls.
- Respect system light/dark mode. Do not hard-code a new brand color or introduce a competing component style.

The [UI candidate note](docs/reviews/2026-11-06-ui-quality-candidate.md) separates source guidance and proposed checks from unexecuted widget/native/accessibility/screenshot acceptance.
