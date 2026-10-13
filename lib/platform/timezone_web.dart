import 'dart:js_interop';

@JS('Intl.DateTimeFormat')
extension type _DateTimeFormat._(JSObject _) implements JSObject {
  external factory _DateTimeFormat();
  external _ResolvedOptions resolvedOptions();
}

extension type _ResolvedOptions._(JSObject _) implements JSObject {
  external String? get timeZone;
}

String? detectTimezone() {
  try {
    final tz = _DateTimeFormat().resolvedOptions().timeZone;
    return (tz == null || tz.isEmpty) ? null : tz;
  } catch (_) {
    return null;
  }
}
