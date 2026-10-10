# Venue map — realtime data (Firestore, read-only for clients)

Decision: [`docs/decisions/contracts-realtime-transport.md`](../../docs/decisions/contracts-realtime-transport.md). Clients **never write** to Firestore (rules deny it); every change goes through [`openapi.yaml`](openapi.yaml). Attendees subscribe with snapshot listeners to the published map, so a publish shows up without a reload.

## Paths

| Path | Who can read | Shape |
| --- | --- | --- |
| `events/{eventId}` | owner; any signed-in user once `publishedVersion > 0` | `Event` (openapi) without `id` |
| `events/{eventId}/published/map` | signed-in, published events | `{version: int, publishedAt: timestamp}` |
| `events/{eventId}/published/map/floors/{floorId}` | same | `Floor` without `id` (doc ID = floor ID) |
| `events/{eventId}/published/map/features/{featureId}` | same | `Feature` without `id` |
| `events/{eventId}/published/map/graphs/{floorId}` | same | `{nodes: Node[], edges: Edge[]}` (doc ID = floor ID) |
| `events/{eventId}/draft/map/**` | owner only | same shapes as published (the editor normally uses `GET /v1/events/{id}/draft`) |
| `events/{eventId}/stats/{yyyy-mm-dd}` | owner only | defined in a later version |

Field names are identical to the JSON in `openapi.yaml`. Timestamps are Firestore timestamps.

## Client rules

- Listen to `published/map` (one small doc) and to the `floors`, `features` and `graphs` subcollections. A publish writes all of them in one transaction, so the data is consistent.
- Floor images: Firebase Storage path `Floor.imagePath`; readable by any signed-in user once the event is published (and by the owner always).
- Attendee positions are never written anywhere.
