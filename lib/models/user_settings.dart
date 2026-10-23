/// Per-user preferences stored on `users/{uid}`.
class UserSettings {
  const UserSettings({
    this.dailyEmail = false,
    this.emailHour = 9,
    this.timezone = '',
    this.pushReminders = false,
    this.pushEvery = 1,
    this.pushFrom = 9,
    this.pushTo = 21,
  });

  /// Send a summary email every morning.
  final bool dailyEmail;

  /// Local hour (0-23) to send it.
  final int emailHour;

  /// IANA time zone, e.g. "America/New_York". Empty until detected.
  final String timezone;

  /// Send push reminders with what's open and what's next.
  final bool pushReminders;

  /// Hours between reminders (1 = every hour).
  final int pushEvery;

  /// First and last local hour (0-23, inclusive) reminders may arrive.
  final int pushFrom;
  final int pushTo;

  UserSettings copyWith({
    bool? dailyEmail,
    int? emailHour,
    String? timezone,
    bool? pushReminders,
    int? pushEvery,
    int? pushFrom,
    int? pushTo,
  }) =>
      UserSettings(
        dailyEmail: dailyEmail ?? this.dailyEmail,
        emailHour: emailHour ?? this.emailHour,
        timezone: timezone ?? this.timezone,
        pushReminders: pushReminders ?? this.pushReminders,
        pushEvery: pushEvery ?? this.pushEvery,
        pushFrom: pushFrom ?? this.pushFrom,
        pushTo: pushTo ?? this.pushTo,
      );

  Map<String, dynamic> toMap() => {
        'dailyEmail': dailyEmail,
        'emailHour': emailHour,
        'timezone': timezone,
        'pushReminders': pushReminders,
        'pushEvery': pushEvery,
        'pushFrom': pushFrom,
        'pushTo': pushTo,
      };

  factory UserSettings.fromMap(Map<String, dynamic>? m) {
    int hour(String k, int d) => ((m?[k] as num?)?.toInt() ?? d).clamp(0, 23);
    return UserSettings(
      dailyEmail: (m?['dailyEmail'] as bool?) ?? false,
      emailHour: hour('emailHour', 9),
      timezone: (m?['timezone'] as String?) ?? '',
      pushReminders: (m?['pushReminders'] as bool?) ?? false,
      pushEvery: ((m?['pushEvery'] as num?)?.toInt() ?? 1).clamp(1, 12),
      pushFrom: hour('pushFrom', 9),
      pushTo: hour('pushTo', 21),
    );
  }
}

/// Common time zones for the picker; the detected zone is added if missing.
const commonTimezones = <String>[
  'America/New_York', 'America/Chicago', 'America/Denver', 'America/Phoenix',
  'America/Los_Angeles', 'America/Anchorage', 'Pacific/Honolulu',
  'America/Toronto', 'America/Vancouver', 'America/Mexico_City',
  'America/Sao_Paulo', 'America/Argentina/Buenos_Aires',
  'Europe/London', 'Europe/Dublin', 'Europe/Lisbon', 'Europe/Paris',
  'Europe/Berlin', 'Europe/Madrid', 'Europe/Rome', 'Europe/Amsterdam',
  'Europe/Stockholm', 'Europe/Athens', 'Europe/Istanbul', 'Europe/Moscow',
  'Africa/Lagos', 'Africa/Cairo', 'Africa/Johannesburg', 'Africa/Nairobi',
  'Asia/Dubai', 'Asia/Karachi', 'Asia/Kolkata', 'Asia/Dhaka',
  'Asia/Bangkok', 'Asia/Singapore', 'Asia/Kuala_Lumpur', 'Asia/Jakarta',
  'Asia/Shanghai', 'Asia/Hong_Kong', 'Asia/Taipei', 'Asia/Manila',
  'Asia/Seoul', 'Asia/Tokyo', 'Australia/Perth', 'Australia/Adelaide',
  'Australia/Brisbane', 'Australia/Sydney', 'Australia/Melbourne',
  'Pacific/Auckland', 'UTC',
];
