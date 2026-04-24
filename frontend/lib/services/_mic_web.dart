// Web platformu: mikrofon izni için dart:html getUserMedia çağrısı.
// Bu dosya yalnızca web build'inde derlenir.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<bool> requestMicPermissionWeb() async {
  try {
    final stream = await html.window.navigator.mediaDevices
        ?.getUserMedia({'audio': true, 'video': false});
    stream?.getTracks().forEach((t) => t.stop());
    return true;
  } catch (_) {
    return false;
  }
}
