import 'package:qr/qr.dart';

/// Link an attendee opens by scanning the "you are here" QR [markerId]:
/// `{base}/e/{eventId}?at={markerId}` (`docs/decisions/team-event-join.md`).
String markerLink(String base, String eventId, String markerId) {
  final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return '$b/e/${Uri.encodeComponent(eventId)}'
      '?at=${Uri.encodeComponent(markerId)}';
}

/// [data] as a QR code in SVG (one path, 4-module quiet zone), so it prints
/// sharp at any size. Error correction M survives some wear on printed signs.
String qrSvg(String data) {
  final img = QrImage(
    QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
  );
  final n = img.moduleCount;
  const q = 4;
  final d = StringBuffer();
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      if (img.isDark(r, c)) d.write('M${c + q} ${r + q}h1v1h-1z');
    }
  }
  final size = n + 2 * q;
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $size $size" '
      'shape-rendering="crispEdges"><rect width="$size" height="$size" '
      'fill="#fff"/><path fill="#000" d="$d"/></svg>';
}

/// One printed sign.
typedef QrCard = ({String title, String subtitle, String link});

/// Fixed texts of the print sheet, from the app's localizations.
typedef QrSheetTexts = ({
  String lang,
  String pageTitle,
  String youAreHere,
  String instructions,
  String printButton,
});

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');

/// A standalone A4 HTML page with two signs per sheet, ready to print.
String qrPrintHtml({
  required String eventName,
  required List<QrCard> cards,
  required QrSheetTexts texts,
}) {
  final body = StringBuffer();
  for (final c in cards) {
    body.write('''
<section class="card">
  <p class="event">${_esc(eventName)}</p>
  <p class="here">${_esc(texts.youAreHere)}</p>
  <h1>${_esc(c.title)}</h1>
  ${c.subtitle.isEmpty ? '' : '<p class="sub">${_esc(c.subtitle)}</p>'}
  <div class="qr">${qrSvg(c.link)}</div>
  <p class="how">${_esc(texts.instructions)}</p>
  <p class="link">${_esc(c.link)}</p>
</section>''');
  }
  return '''<!doctype html>
<html lang="${_esc(texts.lang)}"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${_esc(texts.pageTitle)} · ${_esc(eventName)}</title>
<style>
@page { size: A4; margin: 0; }
* { box-sizing: border-box; }
body { margin: 0; font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; color: #111; background: #eee; }
.bar { position: sticky; top: 0; padding: 12px 16px; background: #fff; border-bottom: 1px solid #ccc; text-align: right; }
.bar button { font: inherit; padding: 8px 20px; border-radius: 20px; border: 0; background: #1b5e20; color: #fff; cursor: pointer; }
.card { width: 210mm; height: 148.5mm; margin: 8px auto; padding: 10mm 16mm; background: #fff;
  display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center;
  break-inside: avoid; border-bottom: 1px dashed #999; }
.event { margin: 0; font-size: 12pt; color: #555; }
.here { margin: 2mm 0 0; font-size: 14pt; font-weight: 600; text-transform: uppercase; letter-spacing: .08em; color: #1b5e20; }
h1 { margin: 1mm 0 0; font-size: 26pt; line-height: 1.1; }
.sub { margin: 1mm 0 0; font-size: 12pt; color: #555; }
.qr { width: 78mm; height: 78mm; margin: 4mm 0; }
.qr svg { width: 100%; height: 100%; }
.how { margin: 0; font-size: 13pt; }
.link { margin: 2mm 0 0; font-size: 8pt; color: #777; word-break: break-all; }
@media print {
  body { background: #fff; }
  .bar { display: none; }
  .card { margin: 0; }
  .card:nth-of-type(2n) { border-bottom: 0; break-after: page; }
}
</style></head>
<body>
<div class="bar"><button onclick="print()">${_esc(texts.printButton)}</button></div>
$body
</body></html>''';
}
