import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../core/utils/formatters.dart';
import '../services/app_repository.dart';

/// The app's display language ('en' or 'am').
///
/// - Before anyone signs in it follows the device: Amharic if the device is
///   set to Amharic, English otherwise.
/// - When a signed-in user has `users/{uid}.language`, that wins.
/// - [setLanguage] (the EN / አማ switch) changes the language at once and, when
///   signed in, saves it to `users/{uid}.language` (Firestore, or the local
///   store in DEMO_MODE). A choice made before sign-in is saved to the
///   profile on sign-in if the profile has no language yet.
class LocaleController extends ChangeNotifier {
  LocaleController({AppRepository? repository, Locale? deviceLocale})
      : _repoOverride = repository,
        _deviceLocale = deviceLocale;

  static LocaleController instance = LocaleController();

  static const List<String> languageCodes = ['en', 'am'];
  static const List<Locale> supportedLocales = [Locale('en'), Locale('am')];

  final AppRepository? _repoOverride;
  final Locale? _deviceLocale;
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
    await _persist(code);
  }

  /// Toggles between English and Amharic.
  Future<void> toggle() => setLanguage(isAmharic ? 'en' : 'am');

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
