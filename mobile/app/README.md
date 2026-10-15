# eho

A new Flutter project.

## Build-time settings

Passed with `--dart-define` (full list in `lib/core/config.dart`; Firebase and `DEMO_EVENT_ID` in `mobile/README.md`).

| Define | Default | What |
| --- | --- | --- |
| `EMULATOR_HOST` | `localhost` | Host of the Auth/Firestore/Storage emulators. On a physical Android phone use `0.0.0.0` (FlutterFire rewrites `localhost` to `10.0.2.2` on Android); `scripts/phone_android.sh` does this. |
| `USE_ECHO_API` | `true` | Use the Echo service when Firebase is up and its `/healthz` answers; demo data otherwise. |
| `ECHO_API_BASE_URL` | `http://localhost:8082` | Echo service (`backend/echo`, `contracts/echo`). |
| `USE_FIND_API` | `true` | Use the Find service (profile + consents, recommendations, search, person, contacts, meeting spot) when Firebase is up and its `/healthz` answers; demo data otherwise. |
| `FIND_API_BASE_URL` | `http://localhost:8083` | Find service (`backend/find`, `contracts/find`). |

Both services take the anonymous Firebase ID token. When a service isn't running, its screens look exactly like the demo.
