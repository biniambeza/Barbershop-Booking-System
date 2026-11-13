import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/formatters.dart';
import '../services/app_repository.dart';

/// Where the language picked on this device is remembered.
abstract class LanguageStore {
  Future<String?> read();
  Future<void> write(String code);
}

/// [LanguageStore] backed by shared_preferences (key [key]).
class SharedPrefsLanguageStore implements LanguageStore {
  const SharedPrefsLanguageStore();

  static const String key = 'app_language';

  @override
  Future<String?> read() async => (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String code) async {
    await (await SharedPreferences.getInstance()).setString(key, code);
  }
}

/// The app's display language ('en' or 'am').
///
/// - Before anyone signs in it uses the language last picked on this device
///   ([loadSaved], kept with shared_preferences across restarts), otherwise
///   the device language: Amharic if the device is set to Amharic, English
///   otherwise.
/// - When a signed-in user has `users/{uid}.language`, that wins.
/// - [setLanguage] (the EN / አማ switch) changes the language at once and, when
///   signed in, saves it to `users/{uid}.language` (Firestore, or the local
///   store in DEMO_MODE). A choice made before sign-in is saved to the
///   profile on sign-in if the profile has no language yet.
class LocaleController extends ChangeNotifier {
  LocaleController({AppRepository? repository, Locale? deviceLocale, LanguageStore? store})
      : _repoOverride = repository,
        _deviceLocale = deviceLocale,
        _store = store ?? const SharedPrefsLanguageStore();

  static LocaleController instance = LocaleController();

  static const List<String> languageCodes = ['en', 'am'];
  static const List<Locale> supportedLocales = [Locale('en'), Locale('am')];

  final AppRepository? _repoOverride;
  final Locale? _deviceLocale;
  final LanguageStore _store;
  AppRepository get _repo => _repoOverride ?? AppRepository.instance;

  String? _chosen;
  String? _lastUid;
  String? _lastUserLanguage;
  bool _started = false;

  /// Device language mapped to a supported one.
  String get deviceLanguage {
    final device = _deviceLocale ?? PlatformDispatcher.instance.locale;
    return device.languageCode == 'am' ? 'am' : 'en';
  }

  String get languageCode => _chosen ?? deviceLanguage;
  Locale get locale => Locale(languageCode);
  bool get isAmharic => languageCode == 'am';

  /// Restores the language last picked on this device. Call before
  /// [start]; a language already chosen (or a signed-in user's) wins.
  Future<void> loadSaved() async {
    String? saved;
    try {
      saved = await _store.read();
    } catch (e) {
      debugPrint('Could not read the saved language: $e');
      return;
    }
    if (saved == null || !languageCodes.contains(saved) || _chosen != null) return;
    final before = languageCode;
    _chosen = saved;
    if (before != languageCode) _changed();
  }

  /// Follows the signed-in user's saved language. Idempotent.
  void start() {
    if (_started) return;
    _started = true;
    _repo.addListener(_onRepositoryChanged);
    _onRepositoryChanged();
    _applyIntl();
  }

  @override
  void dispose() {
    if (_started) _repo.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    final user = _repo.currentUser;
    final uid = user?.uid;
    final userLanguage = user?.language;
    final userChanged = uid != _lastUid;
    final languageChanged = userLanguage != _lastUserLanguage;
    _lastUid = uid;
    _lastUserLanguage = userLanguage;
    if (user == null || (!userChanged && !languageChanged)) return;

    if (userLanguage != null) {
      if (userLanguage != languageCode || _chosen == null) {
        final before = languageCode;
        _chosen = userLanguage;
        if (before != languageCode) _changed();
        _remember(userLanguage);
      }
    } else if (userChanged && _chosen != null) {
      // The user picked a language before signing in: remember it.
      _persist(_chosen!);
    }
  }

  /// Switches the app language and saves it to the signed-in user's profile.
  Future<void> setLanguage(String code) async {
    if (!languageCodes.contains(code)) {
      throw ArgumentError.value(code, 'code', "must be 'en' or 'am'");
    }
    final before = languageCode;
    _chosen = code;
    if (before != code) _changed();
    await _remember(code);
    await _persist(code);
  }

  /// Toggles between English and Amharic.
  Future<void> toggle() => setLanguage(isAmharic ? 'en' : 'am');

  /// Saves [code] on this device (also while signed out).
  Future<void> _remember(String code) async {
    try {
      await _store.write(code);
    } catch (e) {
      debugPrint('Could not save the language on this device: $e');
    }
  }

  /// Saves [code] to the signed-in user's profile.
  Future<void> _persist(String code) async {
    final user = _repo.currentUser;
    if (user == null || user.language == code) return;
    _lastUserLanguage = code;
    try {
      await _repo.updateMyProfile(language: code);
    } catch (e) {
      debugPrint('Could not save language preference: $e');
    }
  }

  void _changed() {
    _applyIntl();
    notifyListeners();
  }

  void _applyIntl() {
    if (!_started) return;
    ensureDateFormattingData();
    Intl.defaultLocale = languageCode;
  }
}
