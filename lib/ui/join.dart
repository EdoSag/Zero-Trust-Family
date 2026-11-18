import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zt_sharing_ui/zt_sharing_ui.dart';

import '../data/family_data.dart';

/// Opens the suite's join screen (paste, scan or an opened link) and
/// remembers the circle as waiting until an owner lets this account in.
Future<void> joinCircle(
  BuildContext context,
  WidgetRef ref, {
  String? initialLink,
}) async {
  final actions = ref.read(familyActionsProvider);
  final started = await ZtJoinSpacePage.open(context, initialLink: initialLink);
  if (started == null) return;
  try {
    await actions.rememberJoin(started.spaceId);
  } on Object {
    // Only the "waiting" card is lost; the join itself went through.
  }
}
