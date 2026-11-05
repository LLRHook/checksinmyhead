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
| `--text-secondary` | `#86868b` | Supporting text |
| `--border-light` | `#e5e5e7` | Light theme dividers and outlines |
| `--border-dark` | `#2d2d2f` | Dark theme dividers and outlines |
| `--dark-bg` | `#0a0a0a` | Dark page background |
| `--card-bg-light` | `#ffffff` | Light cards |
| `--card-bg-dark` | `#161616` | Dark cards |

Flutter uses the matching `AppTheme` colors in `mobile/lib/config/theme.dart`. Users can change the primary accent through the existing app setting.

## Typography

- Web uses Inter for interface text and JetBrains Mono for monetary figures and other aligned numeric values.
- Flutter uses Material 3 text styles. Existing hierarchy uses 36/30/24 px bold display styles, 20 px semibold headline, 18 px semibold title, and 16/14 px body text.
- Use the secondary text color for instructions and metadata. Keep currency values in the existing monospace treatment where the surrounding component already uses it.
- On Settings accent surfaces, derive readable ink from the effective base, blended panel, input or button surface with `AppTheme.foregroundOn`. Supporting text keeps its smaller type hierarchy with readable ink; preserve the user's accent and use it for text only when contrast permits.

## Spacing and shape

- Flutter spacing constants are 8, 16, and 24 px (`AppSpacing.small`, `medium`, `large`).
- Web layouts use Tailwind spacing utilities already present in adjacent components; keep new screens aligned to their card padding and vertical rhythm.
- Cards and input fields use a 16 px radius in Flutter. Web cards use the established rounded-xl through rounded-3xl treatments according to hierarchy.
- Existing web cards use subtle shadows in light mode and border definition in dark mode. Keep focus and disabled states visible.

## Interaction patterns

- One primary action per step, with secondary navigation presented as a quiet text or outlined action.
- Keep item selection rows thumb-friendly and visibly distinguish available, selected, unavailable, and paid items.
- Settings accent choices expose distinct color names, button roles and selected states. Keep at least 48 logical points per target by reducing columns at narrow widths; allow Settings row titles and action text to wrap. Payment-row options use a method-name tooltip without an identifier.
- Preserve keyboard operation, descriptive labels, and accessible error announcements in web controls.
- Respect system light/dark mode. Do not hard-code a new brand color or introduce a competing component style.
