// Web platformu: Browser Notification API — dart:js_interop ile.
// Bu dosya yalnızca web build'inde derlenir.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('Notification')
extension type _JSNotif._(JSObject _) implements JSObject {
  external factory _JSNotif(String title, JSObject options);
  external static String get permission;
  external static JSPromise<JSString> requestPermission();
  external set onclick(JSFunction? fn);
}

bool get webNotifGranted => _JSNotif.permission == 'granted';

void webRequestPermission() {
  try {
    _JSNotif.requestPermission();
  } catch (_) {}
}

void webShowNotification({
  required String title,
  required String body,
  required String tag,
}) {
  try {
    if (!webNotifGranted) return;
    final opts = JSObject();
    opts.setProperty('body'.toJS, body.toJS);
    opts.setProperty('icon'.toJS, '/icons/Icon-192.png'.toJS);
    opts.setProperty('badge'.toJS, '/icons/Icon-192.png'.toJS);
    opts.setProperty('tag'.toJS, tag.toJS);
    opts.setProperty('requireInteraction'.toJS, false.toJS);
    final notif = _JSNotif(title, opts);
    notif.onclick = (() {
      try {
        globalContext.callMethod('focus'.toJS);
      } catch (_) {}
    }).toJS;
  } catch (_) {}
}
