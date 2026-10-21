import 'package:flutter/material.dart';

/// Destinations SultanShareDialog can offer. Adding a new one only means
/// adding a case here (+ its native package/scheme in [ShareService] and
/// its icon/color in the dialog) — no other call site changes.
enum ShareChannel { whatsapp, telegram }

extension ShareChannelInfo on ShareChannel {
  String get label => switch (this) {
        ShareChannel.whatsapp => 'WhatsApp',
        ShareChannel.telegram => 'Telegram',
      };

  /// Candidate Android package names, used both for the `ACTION_SEND`
  /// `setPackage` call and for checking whether the app is installed. Some
  /// channels ship under more than one applicationId in the wild (e.g.
  /// Telegram builds distributed outside the Play Store) — the native side
  /// tries each in order and uses the first one actually installed.
  List<String> get androidPackages => switch (this) {
        ShareChannel.whatsapp => const ['com.whatsapp'],
        ShareChannel.telegram => const [
            'org.telegram.messenger',
            'org.telegram.messenger.web',
          ],
      };

  /// URL scheme used on iOS to detect installation via `canOpenURL`.
  String get iosScheme => switch (this) {
        ShareChannel.whatsapp => 'whatsapp',
        ShareChannel.telegram => 'tg',
      };

  Color get brandColor => switch (this) {
        ShareChannel.whatsapp => const Color(0xFF25D366),
        ShareChannel.telegram => const Color(0xFF29A9EA),
      };

  IconData get icon => switch (this) {
        ShareChannel.whatsapp => Icons.chat_rounded,
        ShareChannel.telegram => Icons.send_rounded,
      };
}
