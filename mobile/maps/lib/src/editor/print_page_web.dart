import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Whether [openPrintPage] can work on this platform.
const canOpenPrintPage = true;

/// Opens [html] in a new tab, where the organizer prints it with the browser.
/// Returns false if the browser blocked the new tab.
bool openPrintPage(String html) {
  final blob = web.Blob(
    [html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  return web.window.open(url, '_blank') != null;
}
