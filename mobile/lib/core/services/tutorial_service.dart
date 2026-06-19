import 'package:hive_flutter/hive_flutter.dart';
import '../constants/storage_keys.dart';

/// Tracks whether a given user has completed the initial onboarding slides.
///
/// Keyed per-user (by id) so a returning person never sees onboarding again
/// after logging out and back in — only a brand-new account (or a different
/// account on the same device) gets it on its own first run.
class TutorialService {
  static const _kOnboardingDoneLegacy = 'onboarding_done';

  Box<String> get _box => Hive.box<String>(StorageKeys.preferencesBox);

  String _key(String? userId) =>
      (userId == null || userId.isEmpty) ? _kOnboardingDoneLegacy : 'onboarding_done_$userId';

  bool isOnboardingDone({String? userId}) => _box.get(_key(userId)) == 'true';
  Future<void> markOnboardingDone({String? userId}) => _box.put(_key(userId), 'true');

  /// Resets the legacy/global onboarding flag. Kept for backward
  /// compatibility; per-user flags are intentionally never reset on logout.
  Future<void> resetAll() => _box.put(_kOnboardingDoneLegacy, 'false');
}
