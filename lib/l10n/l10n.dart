import 'package:flutter/widgets.dart';

import 'generated/app_l10n.dart';

export 'generated/app_l10n.dart';

/// ZT Family's own strings, in English and Hebrew (`app_en.arb`,
/// `app_he.arb`). The language is the one picked under Settings →
/// Appearance → Language (`ztLanguageProvider` in the core).
extension AppL10nContext on BuildContext {
  AppL10n get l => AppL10n.of(this);
}
