# Mobile rule module — Flutter / Dart

**Append to `<project>/.claude/rules.md`** when the project uses Flutter.

---

### M-FL-01 — All async UI work has loading + error states
**Status:** ACTIVE
**Why:** Without explicit loading + error states, the UI either freezes or shows blank screens.
**Detect:** `FutureBuilder` / `StreamBuilder` / Riverpod `AsyncValue` without `loading:` and `error:` cases.
**Fix:** explicit handlers for all 3 states (data, loading, error). Show a `CircularProgressIndicator` for loading and a `Text('Error: $error')` (env-gated per S-13) for errors.

### M-FL-02 — Riverpod / Provider: select on the field, not the whole object
**Status:** ACTIVE
**Why:** Watching a large state object causes rebuilds on every change, even when the widget only cares about one field.
**Detect:** `ref.watch(provider)` of large state objects in widgets that only need one field.
**Fix:** `ref.watch(provider.select((s) => s.field))`.

### M-FL-03 — `const` constructors wherever possible
**Status:** ACTIVE
**Why:** Performance — `const` widgets aren't rebuilt when their parent rebuilds.
**Detect:** widgets without `const` that could have it (the Dart analyzer suggests this).
**Fix:** add `const`. Enable `prefer_const_constructors` lint rule in `analysis_options.yaml` and treat as error.

### M-FL-04 — Use `flutter_secure_storage` for tokens / credentials
**Status:** ACTIVE (reinforces A-03)
**Why:** `Hive`, `SharedPreferences`, and plain files are not encrypted at rest.
**Detect:** `Hive.box.put('token'`, `SharedPreferences.setString('token'`, `File('...').writeAsString(token)`.
**Fix:** `FlutterSecureStorage().write(key: 'token', value: ...)` — uses iOS Keychain + Android EncryptedSharedPreferences under the hood.

### M-FL-05 — Logout clears ALL local state
**Status:** ACTIVE
**Why:** Partial logout (clearing token but not user state) lets the next user see the previous user's data on first launch.
**Detect:** logout handlers that don't call secure-storage delete + state invalidation + navigation reset.
**Fix:** logout = clear secure storage + clear all Riverpod / Provider state (`ref.invalidate(...)`) + navigate to login (`Navigator.pushAndRemoveUntil(context, ..., (route) => false)`).

### M-FL-06 — `await` Future before passing to FormData / API call
**Status:** ACTIVE
**Why:** Passing an unawaited `Future<MultipartFile>` to `FormData.fromMap` serializes it as `Instance of 'Future<...>'` — breaks all uploads silently.
**Detect:** `FormData.fromMap({ key: someAsyncFn() })` patterns where `someAsyncFn()` returns a Future.
**Fix:** `final file = await someAsyncFn(); FormData.fromMap({ key: file });`. For multiple parallel: `final results = await Future.wait([...]);` then build the map.

### M-FL-07 — `print` only in tests / `_test.dart` files
**Status:** ACTIVE (reinforces Q-03)
**Detect:** `print(` in `lib/` (not in `test/`).
**Fix:** use a logger package: `talker`, `logger`, or wrap `developer.log()`.

### M-FL-08 — Don't expose error.toString() in production UI
**Status:** ACTIVE (reinforces S-13)
**Detect:** `showSnackBar(e.toString())`, `showDialog(... Text(error.toString()))` without `kDebugMode` gate.
**Fix:** `kDebugMode ? 'DEV: $e' : 'Something went wrong'`. Always log full error via `logger.e(e)`.

### M-FL-09 — Use `MaterialPageRoute` / `go_router` consistently for navigation
**Status:** ACTIVE
**Why:** Mixing imperative (`Navigator.push`) and declarative (`go_router`) navigation causes back-stack bugs and deep-link issues.
**Detect:** mixed use of `Navigator.push` and `context.go(...)` / `context.push(...)` in the same project.
**Fix:** pick one and stick to it. `go_router` is the recommended modern choice for production apps.

### M-FL-10 — Asset paths declared in `pubspec.yaml` must exist on disk
**Status:** ACTIVE
**Why:** Runtime crash on first access. The Flutter analyzer doesn't catch this.
**Detect:** `assets:` entries in `pubspec.yaml` whose paths don't resolve to actual files/directories.
**Fix:** verify every declared asset exists. Add a CI check: `bash scripts/verify-assets.sh` that fails if any declared asset is missing.

### M-FL-13 — User-facing strings go through `AppLocalizations` when i18n is configured
**Status:** ACTIVE (when applicable — reinforces W-04)
**Why:** If the app ships multiple locales, a bare `'Continue'` in a widget ships untranslated to every non-default locale. Catching this at code-review / audit time is cheaper than a locale regression in prod.
**Detect — i18n is considered configured if:**
  - `pubspec.yaml` has `flutter_localizations:` (from SDK) AND `intl:` dependency
  - Project has `l10n.yaml` at root OR `lib/l10n/` dir with `.arb` files
  - `MaterialApp` wires `localizationsDelegates` / `supportedLocales`
**Then detect violations:** any `Text('...')`, `label: '...'`, `tooltip: '...'`, `SnackBar(content: Text('...'))`, `hintText: '...'`, `errorText: '...'` in `lib/features/**` / `lib/shared/**` where the string is user-facing and non-brand.
**Exclusions (may remain as literals):**
  - Brand / product names: the app name, "Google", "Apple", proper nouns
  - `semanticsLabel` when it's programmatic (a11y hints can be localized but not a violation if missed)
  - `debugLabel`, `debugFillProperties` output, `assert` messages
  - Asset path strings
**Fix:** add the key to `lib/l10n/app_en.arb` + `app_fr.arb` (and every other locale), run `flutter gen-l10n` (or let the build do it), then consume:
```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.signInWithGoogle)
```
Keep keys feature-scoped: `auth_sign_in_google`, `home_greeting` — not flat `btn1`.

### M-FL-12 — Every widget in `lib/features/**` or `lib/shared/widgets/**` has a matching test
**Status:** ACTIVE (reinforces W-02)
**Why:** Without a widget test, a trivial refactor breaks a screen silently and the bug ships. Flutter widget tests are cheap (milliseconds) and catch 80% of UI regressions.
**Detect:** new file at `lib/features/<feature>/<name>.dart` (or `lib/shared/widgets/<name>.dart`) with no corresponding `test/features/<feature>/<name>_test.dart` (or `test/shared/widgets/<name>_test.dart`).
**Fix:** scaffold at minimum:
```dart
void main() {
  testWidgets('<Widget> renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: <Widget>(...)));
    expect(find.text('<key label>'), findsOneWidget);
  });
}
```
Run via `flutter test --dart-define=ENV=testing test/features/<feature>/<name>_test.dart`.

### M-FL-11 — No hardcoded design values in widgets (colors / radii / spacing / shadows / typography)
**Status:** ACTIVE (reinforces Q-11 DRY)
**Why:** Inline `Color(0xFF...)`, magic radii, repeated `BoxShadow` lists, and ad-hoc spacing drift across screens and break theming/dark-mode. Tokens must live in ONE place (ThemeData, ThemeExtension, or a tokens file) so a single change propagates everywhere.
**Detect (inside `lib/features/**`, `lib/shared/widgets/**`, `lib/presentation/**` — widget files, NOT the theme/tokens layer):**
  - `Color(0x[0-9A-Fa-f]{8})` literals (except `Colors.transparent`)
  - `Colors\.(white|black|red|blue|...)` named colors (except as the explicit design choice in the tokens file)
  - `BorderRadius.circular(\d+)` / `Radius.circular(\d+)` with numeric literals
  - Inline `BoxShadow(...)` lists (2+ entries) — should be a named constant
  - Hardcoded `fontSize`, `letterSpacing`, `height` in `TextStyle(...)` — should use `Theme.of(context).textTheme.*`
  - Repeated `EdgeInsets.*(\d+)` values across 3+ files — should be a spacing token
**Fix:**
  - Colors → `Theme.of(context).colorScheme.X`, a `ThemeExtension`, or `AppColors.x` in `lib/core/theme/`
  - Radii → `AppRadius.sm / md / lg` constants
  - Shadows → `AppShadows.card / button / modal` `List<BoxShadow>` constants
  - Typography → `Theme.of(context).textTheme.X`; extend `ThemeData` if a variant is missing
  - Spacing → `AppSpacing.xs / sm / md / lg / xl` constants
  - **Allowed location for literals:** the theme/tokens files themselves (`lib/core/theme/**`). Those define tokens; everything else consumes them.
