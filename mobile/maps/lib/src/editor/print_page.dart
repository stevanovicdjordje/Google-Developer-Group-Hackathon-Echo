// Opens a printable HTML page; only possible on web.
export 'print_page_stub.dart'
    if (dart.library.js_interop) 'print_page_web.dart';
