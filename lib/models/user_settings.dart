/// Per-user preferences stored on `users/{uid}`.
class UserSettings {
  const UserSettings({
    this.dailyEmail = false,
    this.emailHour = 9,
    this.timezone = '',
  });

  /// Send a summary email every morning.
  final bool dailyEmail;

  /// Local hour (0-23) to send it.
  final int emailHour;

  /// IANA time zone, e.g. "America/New_York". Empty until detected.
  final String timezone;

  UserSettings copyWith({bool? dailyEmail, int? emailHour, String? timezone}) =>
      UserSettings(
        dailyEmail: dailyEmail ?? this.dailyEmail,
        emailHour: emailHour ?? this.emailHour,
        timezone: timezone ?? this.timezone,
      );

  Map<String, dynamic> toMap() => {
        'dailyEmail': dailyEmail,
        'emailHour': emailHour,
        'timezone': timezone,
      };

  factory UserSettings.fromMap(Map<String, dynamic>? m) => UserSettings(
        dailyEmail: (m?['dailyEmail'] as bool?) ?? false,
        emailHour: ((m?['emailHour'] as num?)?.toInt() ?? 9).clamp(0, 23),
        timezone: (m?['timezone'] as String?) ?? '',
      );
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
