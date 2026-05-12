import 'package:flutter_test/flutter_test.dart';
import 'package:passstore/core/models/strong_password_rules.dart';
import 'package:passstore/core/services/strong_password_generator.dart';

void main() {
  test('generates passwords from the selected character groups', () {
    const rules = StrongPasswordRules(
      length: 12,
      includeUppercase: false,
      includeLowercase: false,
      includeDigits: true,
      includeSymbols: false,
      excludeAmbiguous: true,
    );

    final password = StrongPasswordGenerator.generate(rules);

    expect(password.length, 12);
    expect(password, matches(RegExp(r'^[2-9]+$')));
  });

  test('default rules include every character group', () {
    final password = StrongPasswordGenerator.generate(
      StrongPasswordRules.defaults,
    );

    expect(password.length, 20);
    expect(password, matches(RegExp('[a-z]')));
    expect(password, matches(RegExp('[A-Z]')));
    expect(password, matches(RegExp(r'\d')));
    expect(password, matches(RegExp(r'[!@#%^&*()_\-=+\[\]{}]')));
  });
}
