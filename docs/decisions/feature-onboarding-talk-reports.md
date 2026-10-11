# Paid talk reports on the web portal

- **ID:** `feature-onboarding-talk-reports`
- **Status:** accepted
- **Writer:** feature:onboarding holder · @stevanovicdjordje
- **Affects:** feature:onboarding (web portal); related to the app's mocked talk-summary paywall (`mobile`, `feature:echo`)
- **Created:** 2026-10-11 · **Decided:** 2026-10-11 (by @stevanovicdjordje)

## Context

Attendees who missed a talk, and people who weren't at the conference at all, want what was said. Eho already plans paid talk summaries as its attendee monetization (`docs/PRODUCT.md`, "Talk summary (paid)"); the app has a mocked "unlock" paywall. The web portal now sells a downloadable report of a single talk.

## Decision

- **What is sold:** the report of one talk as a PDF: Echo's AI summary (takeaway, key points, problems and fixes with transcript times, labeled as AI with the model name), the audience rating of that talk (from the per-session ratings in reviews), and the top five audience questions from Echo Q&A (anonymous). Event-level review comments are **not** included (they are not about one talk and were written for the organizer).
- **Who can buy:** any signed-in user, for any talk that has ended, whether or not they attended the event. Attendance of a single talk isn't tracked, so nobody is blocked. The event's organizer downloads it free.
- **Price:** €2.99 per talk (VAT included), no event bundle.
- **Payment:** a **test checkout** in the portal (`docs/MVP.md`: payments are mocked). Card name, number (Luhn), expiry and CVC are validated; `TestProvider` accepts only Stripe's documented test cards (4242 4242 4242 4242 succeeds, 4000 0000 0000 0002 is declined, 4000 0000 0000 9995 has insufficient funds) and moves no money. Real-looking numbers are refused, so nobody believes they paid. The page says "Test mode" prominently.
- **Data kept:** `purchases/{uid}_{eventId}_{sessionId}`: user, talk, amount, currency, card brand, last four digits, payment ID, mode (`test`), time. The card number and CVC are never stored, logged or rendered back.
- **Real payments later:** a Stripe implementation of `talks.PaymentProvider` (Stripe Checkout redirect, no JS in the portal) replaces `TestProvider`; it needs a Stripe account and keys (human decision).

## Consequences / follow-ups

- Echo's `/summary` is not payment-checked server-side (its contract says the app's paywall is mocked); the portal fetches it with its own service account (custom token → ID token).
- The app's paywall stores unlocks on the phone only; if the team wants one entitlement for app and web, the app can read `purchases` (request to mobile, not made yet).
- `docs/DATA_PRIVACY.md` should list purchase records (requested from product in `contracts/onboarding/STATUS.md`).
