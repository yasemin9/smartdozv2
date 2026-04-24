// Conditional export: web'de dart:html, diğer platformlarda no-op stub.
export '_mic_stub.dart' if (dart.library.html) '_mic_web.dart';
