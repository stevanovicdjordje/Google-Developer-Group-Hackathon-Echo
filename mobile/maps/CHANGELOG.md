## Unreleased

- Routing (phase 5): `MapsApi.getRoute`, route models, `mapsRouteProvider`.
- Viewer: "Prikaži put" in the details sheet, start picker (QR markers, entrances, tap on the map), route line with start/end and
  lift/stairs points, summary card (distance, minutes, estimate, no stairs), floor-change banner, "Vi ste ovde" dot.
- Fix: switching floors no longer keeps the previous floor's camera.
- Location (phase 6): `Georef` (mirror of the Go transform, checked on `contracts/maps/testdata/georef.json`), editor GPS screen
  (3 control points), "Moja lokacija" in the viewer (dot, accuracy, GPS route start, re-routing, "Stigli ste", fallbacks).
  New dependency: `geolocator`.

## 0.1.0

- Map data models mirroring contracts/maps 0.1.0.
