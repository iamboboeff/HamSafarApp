import '../../models/app_settings.dart';
import 'strings_tg.dart';
import 'strings_tg_generated.dart';

/// Lightweight, reactive localization keyed on the Russian source string.
///
/// The app's UI was written with hardcoded Russian literals (878 of them across
/// 77 files, many in non-widget code with no `BuildContext`). Rather than invent
/// hundreds of ARB keys, we keep the Russian string as the lookup key and return
/// a Tajik translation when the Tajik locale is active. A missing key falls back
/// to the Russian source, so the app never shows a blank and the Tajik map can
/// grow incrementally.
///
/// [L10n.instance.language] is assigned from the appearance setting in
/// `app.dart` on every rebuild — so a language switch re-runs `MaterialApp`'s
/// build, the whole widget tree rebuilds, and every `tr()` call (including those
/// in models / services / state without a `BuildContext`) re-evaluates against
/// the new language.
class L10n {
  L10n._();

  static final L10n instance = L10n._();

  AppLanguage language = AppLanguage.russian;

  bool get isTajik => language == AppLanguage.tajik;
}

/// Translates a Russian source string for the active language.
///
/// Pass the Russian literal verbatim: `tr('Сообщения')`. When Russian is active
/// (or no Tajik translation exists yet) the source string is returned unchanged.
String tr(String ru) {
  if (L10n.instance.isTajik) {
    // Hand-curated entries win; the workflow-generated map fills the rest;
    // anything still unmapped falls back to the Russian source.
    return tajikStrings[ru] ?? tajikStringsGenerated[ru] ?? ru;
  }
  return ru;
}

/// Translates a template containing `{name}` placeholders, then substitutes
/// [args]. Use this for interpolated strings so the translatable text and the
/// dynamic values are decoupled.
///
/// Example: `trf('Нужно {n} место', {'n': seats})`.
String trf(String ru, Map<String, Object?> args) {
  var s = tr(ru);
  args.forEach((key, value) {
    s = s.replaceAll('{$key}', '${value ?? ''}');
  });
  return s;
}
