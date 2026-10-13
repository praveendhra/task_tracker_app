// The browser's IANA time zone (e.g. "America/New_York"), or null when it
// can't be detected (non-web builds fall back to the picker).
export 'timezone_stub.dart' if (dart.library.js_interop) 'timezone_web.dart';
