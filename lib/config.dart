/// Build with `--dart-define=DEMO=true` to run on in-memory data without
/// Firebase (used for UI work and CI screenshots).
const kDemo = bool.fromEnvironment('DEMO');

/// In demo builds, `?screen=…&task=…&theme=…` in the URL opens a specific
/// view on load so screenshots can be taken without clicking.
Map<String, String> get demoParams =>
    kDemo ? Uri.base.queryParameters : const <String, String>{};
