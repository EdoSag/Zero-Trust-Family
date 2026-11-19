import 'package:flutter/foundation.dart';

/// What a family circle says about itself. One item per shared space,
/// encrypted like everything else in it.
@immutable
class Circle {
  const Circle({required this.name});

  factory Circle.fromJson(Map<String, Object?> j) =>
      Circle(name: (j['name'] as String? ?? '').trim());

  static const itemId = 'family.circle';
  static const kind = 'family.circle';

  /// Longest name the app saves; longer ones from elsewhere are cut.
  static const maxNameLength = 40;

  final String name;

  Map<String, Object?> toJson() => {'kind': kind, 'name': name};

  /// [input] as it would be saved, or null when there is nothing to save.
  static String? cleanName(String input) {
    final name = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return null;
    return name.length > maxNameLength
        ? name.substring(0, maxNameLength).trim()
        : name;
  }
}
