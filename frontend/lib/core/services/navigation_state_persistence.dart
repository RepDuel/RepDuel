// frontend/lib/core/services/navigation_state_persistence.dart

import 'package:shared_preferences/shared_preferences.dart';

/// Holds the persisted launch configuration for the navigation shell.
class NavigationLaunchState {
  const NavigationLaunchState({
    required this.initialIndex,
    required this.lastUserId,
  });

  /// The branch index that should be used when instantiating the router.
  final int initialIndex;

  /// The identifier of the user whose navigation state produced [initialIndex].
  ///
  /// `null` represents an unauthenticated (guest) session.
  final String? lastUserId;
}

/// Persists the user's last selected bottom navigation branch.
class NavigationStatePersistence {
  NavigationStatePersistence(
    SharedPreferences preferences, {
    required this.branchCount,
    required this.defaultIndex,
  })  : assert(branchCount > 0, 'branchCount must be positive'),
        assert(defaultIndex >= 0, 'defaultIndex cannot be negative'),
        _preferences = preferences;

  final SharedPreferences _preferences;

  /// Total number of bottom navigation branches supported by the shell.
  final int branchCount;

  /// Index to fall back to when the stored value is missing or invalid.
  final int defaultIndex;

  static const String _lastUserKey = 'navigation.lastUserId';
  static const String _branchIndexKeyPrefix = 'navigation.lastBranchIndex.';
  static const String _guestSentinel = '__guest__';

  /// Restores the persisted launch state, falling back to the configured
  /// [defaultIndex] when persistence is empty or corrupted.
  NavigationLaunchState restoreLaunchState() {
    final storedUserKey =
        _preferences.getString(_lastUserKey) ?? _guestSentinel;
    final restoredIndex = _readBranchIndex(storedUserKey);
    final lastUserId =
        storedUserKey == _guestSentinel ? null : storedUserKey;

    return NavigationLaunchState(
      initialIndex: restoredIndex ?? defaultIndex,
      lastUserId: lastUserId,
    );
  }

  /// Reads the persisted branch index for [userId].
  /// Returns `null` when no value exists or the stored index is invalid.
  int? readBranchIndexForUser(String? userId) {
    final storageKey = _normalizeUserId(userId);
    return _readBranchIndex(storageKey);
  }

  /// Persists [index] for the supplied [userId]. Invalid indexes are ignored and
  /// the stored value is cleared instead.
  Future<void> persistBranchIndex(int index, {String? userId}) async {
    final storageKey = _normalizeUserId(userId);
    if (!_isValidIndex(index)) {
      await _preferences.remove(_branchIndexKey(storageKey));
      return;
    }

    await _preferences.setInt(_branchIndexKey(storageKey), index);
    await _preferences.setString(_lastUserKey, storageKey);
  }

  /// Updates the cached user identifier used to seed the next launch.
  Future<void> setLastUserId(String? userId) async {
    final storageKey = _normalizeUserId(userId);
    await _preferences.setString(_lastUserKey, storageKey);
  }

  /// Removes any persisted branch index for [userId].
  Future<void> clearBranchIndex(String? userId) {
    final storageKey = _normalizeUserId(userId);
    return _preferences.remove(_branchIndexKey(storageKey));
  }

  String _branchIndexKey(String storageKey) =>
      '$_branchIndexKeyPrefix$storageKey';

  String _normalizeUserId(String? userId) {
    final trimmed = userId?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return _guestSentinel;
    }
    return trimmed;
  }

  int? _readBranchIndex(String storageKey) {
    final storedValue = _preferences.get(_branchIndexKey(storageKey));
    if (storedValue is! int) {
      if (storedValue != null) {
        _preferences.remove(_branchIndexKey(storageKey));
      }
      return null;
    }

    if (!_isValidIndex(storedValue)) {
      _preferences.remove(_branchIndexKey(storageKey));
      return null;
    }

    return storedValue;
  }

  bool _isValidIndex(int value) => value >= 0 && value < branchCount;
}
