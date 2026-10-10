# Eho app design (source of truth for the design pass, M-10)

Exported from the human's Claude Design canvas "Eho app design"
(https://claude.ai/artifact/CWrqgTmmcqR4dZLzQZA2bU, version 1791673739-d8a0, 2026-10-11).
One `.dc.html` per screen, 390×844 phone frames; open them in a browser or read the inline styles.
The `<script src="./support.js">` line is the canvas runtime and isn't needed to read them.

| File | Screen |
| --- | --- |
| `Main.dc.html` | Start |
| `Join.dc.html` | Join (deep link) |
| `Onboarding.dc.html` | Onboarding · consent |
| `Events.dc.html` | My events |
| `Agenda.dc.html` | Agenda tab (incl. bottom nav) |
| `Echo.dc.html` | Echo (live talk) |
| `Map.dc.html` | Map tab (app chrome around the eho_maps viewer) |
| `Find.dc.html` | Find tab |
| `Profile.dc.html` | Profile tab |
| `Messages.dc.html` | Messages + meeting spot |
| `OrgUpload.dc.html`, `OrgReview.dc.html`, `OrgPublished.dc.html` | Organizer flow |

## Tokens seen across the screens (light theme)

| Token | Value | Used for |
| --- | --- | --- |
| background | `#F3F5F9` | screen ground (Echo and Messages use white) |
| surface | `#FFFFFF` | cards, nav bar, inputs |
| ink | `#0D1321` | text, dark hero blocks (Join header, live event card), selected filter chip |
| ink-secondary | `#4A5468` | secondary text, inactive nav |
| body-on-tint | `#1F2A44` | text on tinted cards |
| outline | `#C9D0DC` | input/secondary-button borders |
| divider | `#DDE2EB` | dividers, nav top border |
| primary | `#2F4BFF` (pressed `#1A33D6`) | primary buttons, links, active nav, AI sparkle |
| primary-container | `#E6EAFF` | active nav pill, Catch-up card, icon tiles, "Top match" |
| live (accent) | `#E85D1F` | LIVE dot, live session border, meeting-spot card border, badges |
| on-live-container | `#C2410C` | LIVE label text, meeting-spot icon |
| live-container | `#FFEDE3` | highlighted transcript line, meeting-spot icon tile |
| on-dark | `#D5DBE6`, `#B9C3FF`, `#FFB48C` | secondary text on ink blocks |

Type: **Bricolage Grotesque** (display/headlines, 700; 72 Start wordmark, 40 Join title, 32–34 screen titles, 26 event card) and **Instrument Sans** (everything else: 400/500/600; body 15–17, captions 12–14, overline 12–13 600 uppercase +0.6–0.8 letter-spacing). Both are Google Fonts (OFL).

Shape: buttons 56 h / radius 16 (primary filled, secondary white with 1.5 outline, tertiary text); chips 36 h / radius 18; cards radius 18–22, no shadow, padding 16–22; inputs 52–56 h / radius 16–18; icon buttons 44×44 circles; bottom nav: 4 items, active item has a 56×30 primary-container pill, label 12. Icons: 2 px stroke line icons (Material Symbols Rounded/outlined are a fine match).
