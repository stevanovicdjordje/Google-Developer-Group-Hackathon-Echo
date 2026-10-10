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

## v2 additions (2026-10-11, canvas version 1791674812-5888)

The human asked for the missing screens/flows. 10 new frames, same tokens and shapes as above (`canvas.json` updated). New colors used: scrim behind sheets `#59606E`, map ground `#E9EDF3`, flagged-row tint `#FFF8F4`.

| File | Screen | Route in the app | New behavior the design adds |
| --- | --- | --- | --- |
| `Session.dc.html` | Session details | `/e/:id/session/:sid` | Track + LIVE badges; speaker card; dark "Echo is on for this talk" card with **Open Echo**; outlined "Show <stage> on map" at the bottom; bookmark icon (save to my agenda, optional) |
| `EchoTranslated.dc.html` | Echo translated (SR) | Echo with translate on | Language pill becomes filled `SR`; blue banner "Translated live from English · tap SR for the original"; transcript **and** AI answers shown in Serbian; input placeholder in Serbian |
| `EchoQA.dc.html` | Q&A sheet | Echo → Q&A button | Sheet title "Questions for <speaker>"; sort chips **Top / Newest / Mine**; 52×56 vote buttons (filled blue when you voted); your question outlined in blue with "YOUR QUESTION"; AI chip "3 similar questions merged" (grouping is optional for the demo); ask-speaker input with an orange send button |
| `EchoEnded.dc.html` | Talk ended + paywall | Echo after the transcript ends | Sheet "Missed something? Get the whole talk in 2 minutes."; two radio options **This talk** / **Every talk at <event>**; prices are placeholders `[PRICE]` / `[EVENT PRICE]` (app keeps its mock price until the team decides); "Unlock summary" + "Not now" |
| `EchoSummary.dc.html` | Talk summary | after unlock | Badge "AI SUMMARY · PREMIUM"; dark **Takeaway** card first; "Key points" bullets; "Trade-offs and fixes" table whose rows end with a timestamp link back into the transcript; translate + share icon buttons |
| `OnboardingName.dc.html` | Onboarding 1/3 | `/onboarding` step 1 | 3-segment progress bar + "1 of 3"; Name, What you do |
| `OnboardingInterests.dc.html` | Onboarding 2/3 | `/onboarding` step 2 | Interest chips (selected = filled blue); "Who do you want to meet?" textarea with hint "The AI reads this to find your matches." |
| `FindResults.dc.html` | Find search results | Find after a prompt | Query stays in the field with a clear (×) button; caption "3 people at <event> fit · only people who opted in"; result cards with an AI-written fit line; speakers can appear as results |
| `Person.dc.html` | Person + contact (interactive) | `/e/:id/find/person/:pid` | Big avatar, interests, Looking for, blue "Why you should meet" card; one bottom button cycling **Send contact request → Request sent · waiting for <name> → <name> accepted · Message** (→ Messages); note "Your details are shared only after <name> accepts." |
| `MapDetail.dc.html` | Map: stage details + route | Map tab, feature selected | Route line from "You are here" to the stage; sheet with name, capacity, walk time (big blue "2 min"), "NOW" session row → session, **Start route** + **Open Echo**. The map drawing itself belongs to `feature:maps` (request it there); the sheet content is mobile's |

Also visible in v1 frames but not yet in the app: Agenda's live session card ("LIVE NOW · ECHO ON", orange border), Echo's "Ask about this" chip under a highlighted line, organizer review rows flagged by the AI ("Check: room missing in the PDF", tinted `#FFF8F4`), upload progress text "Found 3 stages, 6 sessions, 6 speakers so far…".
