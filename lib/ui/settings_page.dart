import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// The shared Zero-Trust settings screen. Family's own rows (location
/// sharing, alerts) are added with those features.
class FamilySettingsPage extends StatelessWidget {
  const FamilySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ZtSettingsPage(
      showSyncStatus: true,
      onSignedOut: () => Navigator.of(context).popUntil((r) => r.isFirst),
      onOpenUrl: (url) => launchUrl(url, mode: LaunchMode.externalApplication),
      privacyPolicyUrl: Uri.parse('https://zerotrust.bz/privacy'),
      termsUrl: Uri.parse('https://zerotrust.bz/terms'),
      supportUrl: Uri.parse('https://zerotrust.bz/support'),
    );
  }
}
