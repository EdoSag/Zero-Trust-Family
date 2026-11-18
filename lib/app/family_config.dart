import 'package:flutter/material.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import '../model/circle.dart';

/// Family in the suite. Not in the core's `ZtSuite` list yet, so the other
/// apps don't link to it before it's released.
const ZtSuiteApp familySuiteApp = ZtSuiteApp(
  appId: 'family',
  name: 'Family',
  tagline: 'Private location sharing and check-ins for your family',
  icon: Icons.family_restroom,
  accent: Color(0xFF14B8A6), // teal
  androidPackage: 'dev.sagron.zerotrustfamily',
);

const ZtAppConfig familyAppConfig = ZtAppConfig(
  appId: 'family',
  displayName: 'Zero-Trust Family',
  accent: Color(0xFF14B8A6),
);

/// A circle's name is changed by its owners only. Whatever a member says
/// about themselves (`family.me/<userId>`, from phase L1 on) can be written
/// by that member alone, not even by an owner: nobody can put a location or
/// a check-in in someone else's name. The server enforces both too.
const SpacePolicy familySpacePolicy = SpacePolicy(
  adminOnlyKinds: {Circle.kind},
  ownedPrefixes: {'family.me/'},
);
