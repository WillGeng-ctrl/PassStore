import 'dart:math' as math;

import '../models/strong_password_rules.dart';

class StrongPasswordGenerator {
  const StrongPasswordGenerator._();

  static String generate(StrongPasswordRules rules, {math.Random? random}) {
    final normalized = rules.normalized();
    final source = random ?? math.Random.secure();
    final groups = _characterGroups(normalized);
    final length = math.max(normalized.length, groups.length);
    final characters = [
      for (final group in groups) _pick(group, source),
      ...List.generate(
        length - groups.length,
        (_) => _pick(groups.join(), source),
      ),
    ]..shuffle(source);
    return characters.join();
  }

  static List<String> _characterGroups(StrongPasswordRules rules) {
    final groups = <String>[];
    if (rules.includeUppercase) {
      groups.add(
        rules.excludeAmbiguous
            ? 'ABCDEFGHJKLMNPQRSTUVWXYZ'
            : 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
      );
    }
    if (rules.includeLowercase) {
      groups.add(
        rules.excludeAmbiguous
            ? 'abcdefghijkmnpqrstuvwxyz'
            : 'abcdefghijklmnopqrstuvwxyz',
      );
    }
    if (rules.includeDigits) {
      groups.add(rules.excludeAmbiguous ? '23456789' : '0123456789');
    }
    if (rules.includeSymbols) {
      groups.add('!@#%^&*()_-=+[]{}');
    }
    return groups;
  }

  static String _pick(String source, math.Random random) {
    return source[random.nextInt(source.length)];
  }
}
