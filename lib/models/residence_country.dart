/// Ported from `ResidenceCountry` in `Models.swift`.
enum ResidenceCountry {
  uzbekistan,
  tajikistan;

  String get title => switch (this) {
    ResidenceCountry.uzbekistan => 'Узбекистан',
    ResidenceCountry.tajikistan => 'Таджикистан',
  };

  /// Currency code per country so prices can be shown in the right currency
  /// (Tajikistan → TJS, Uzbekistan → UZS). Previously hardcoded to TJS, which
  /// made UZS impossible to represent (QA #99).
  String get currencyCode => switch (this) {
    ResidenceCountry.uzbekistan => 'UZS',
    ResidenceCountry.tajikistan => 'TJS',
  };

  /// Mirrors `formatAmount` — decimal grouping with a space separator and the
  /// currency code appended (e.g. `1 200 TJS`).
  String formatAmount(int amount) {
    final digits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final sign = amount < 0 ? '-' : '';
    return '$sign$buffer $currencyCode';
  }
}
