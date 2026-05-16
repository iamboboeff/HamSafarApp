/// Ported from `ResidenceCountry` in `Models.swift`.
enum ResidenceCountry {
  uzbekistan,
  tajikistan;

  String get title => switch (this) {
    ResidenceCountry.uzbekistan => 'Узбекистан',
    ResidenceCountry.tajikistan => 'Таджикистан',
  };

  /// The Swift app always reports `TJS` regardless of the country.
  String get currencyCode => 'TJS';

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
