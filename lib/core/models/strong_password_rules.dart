class StrongPasswordRules {
  const StrongPasswordRules({
    required this.length,
    required this.includeUppercase,
    required this.includeLowercase,
    required this.includeDigits,
    required this.includeSymbols,
    required this.excludeAmbiguous,
  });

  final int length;
  final bool includeUppercase;
  final bool includeLowercase;
  final bool includeDigits;
  final bool includeSymbols;
  final bool excludeAmbiguous;

  static const lengthOptions = [12, 16, 20, 24, 32];

  static const defaults = StrongPasswordRules(
    length: 20,
    includeUppercase: true,
    includeLowercase: true,
    includeDigits: true,
    includeSymbols: true,
    excludeAmbiguous: true,
  );

  bool get hasCharacterGroup =>
      includeUppercase || includeLowercase || includeDigits || includeSymbols;

  StrongPasswordRules normalized() {
    final normalizedLength = lengthOptions.contains(length)
        ? length
        : defaults.length;
    if (!hasCharacterGroup) {
      return defaults.copyWith(length: normalizedLength);
    }
    return copyWith(length: normalizedLength);
  }

  StrongPasswordRules copyWith({
    int? length,
    bool? includeUppercase,
    bool? includeLowercase,
    bool? includeDigits,
    bool? includeSymbols,
    bool? excludeAmbiguous,
  }) {
    return StrongPasswordRules(
      length: length ?? this.length,
      includeUppercase: includeUppercase ?? this.includeUppercase,
      includeLowercase: includeLowercase ?? this.includeLowercase,
      includeDigits: includeDigits ?? this.includeDigits,
      includeSymbols: includeSymbols ?? this.includeSymbols,
      excludeAmbiguous: excludeAmbiguous ?? this.excludeAmbiguous,
    );
  }

  Map<String, Object?> toJson() => {
    'length': length,
    'includeUppercase': includeUppercase,
    'includeLowercase': includeLowercase,
    'includeDigits': includeDigits,
    'includeSymbols': includeSymbols,
    'excludeAmbiguous': excludeAmbiguous,
  };

  factory StrongPasswordRules.fromJson(Map<String, Object?>? json) {
    if (json == null) return defaults;
    return StrongPasswordRules(
      length: json['length'] as int? ?? defaults.length,
      includeUppercase:
          json['includeUppercase'] as bool? ?? defaults.includeUppercase,
      includeLowercase:
          json['includeLowercase'] as bool? ?? defaults.includeLowercase,
      includeDigits: json['includeDigits'] as bool? ?? defaults.includeDigits,
      includeSymbols:
          json['includeSymbols'] as bool? ?? defaults.includeSymbols,
      excludeAmbiguous:
          json['excludeAmbiguous'] as bool? ?? defaults.excludeAmbiguous,
    ).normalized();
  }

  @override
  bool operator ==(Object other) {
    return other is StrongPasswordRules &&
        other.length == length &&
        other.includeUppercase == includeUppercase &&
        other.includeLowercase == includeLowercase &&
        other.includeDigits == includeDigits &&
        other.includeSymbols == includeSymbols &&
        other.excludeAmbiguous == excludeAmbiguous;
  }

  @override
  int get hashCode => Object.hash(
    length,
    includeUppercase,
    includeLowercase,
    includeDigits,
    includeSymbols,
    excludeAmbiguous,
  );
}
