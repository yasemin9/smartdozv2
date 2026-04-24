// Conditional export: web'de js_interop impl, diğer platformlarda stub.
export '_notif_stub.dart' if (dart.library.html) '_notif_web.dart';
