// Conflict resolution for offline sync
// Strategy: Last-write-wins with deep merge for JSONB fields

class ConflictResolver {
  /// Resolve conflict between local and remote data
  /// Returns the merged data to be used
  Map<String, dynamic> resolve(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    // Get timestamps
    final localUpdatedAt = DateTime.parse(local['updated_at'] as String);
    final remoteUpdatedAt = DateTime.parse(remote['updated_at'] as String);

    // Last-write-wins based on updated_at
    if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return local;
    } else if (remoteUpdatedAt.isAfter(localUpdatedAt)) {
      return remote;
    }

    // Timestamps equal - deep merge JSONB data field
    return _deepMerge(local, remote);
  }

  /// Deep merge two maps (used for JSONB data field)
  Map<String, dynamic> _deepMerge(
    Map<String, dynamic> map1,
    Map<String, dynamic> map2,
  ) {
    final result = Map<String, dynamic>.from(map1);

    map2.forEach((key, value) {
      if (result.containsKey(key)) {
        if (value is Map<String, dynamic> &&
            result[key] is Map<String, dynamic>) {
          // Recursively merge nested maps
          result[key] = _deepMerge(
            result[key] as Map<String, dynamic>,
            value,
          );
        } else if (value is List && result[key] is List) {
          // Merge lists (taking remote)
          result[key] = value;
        } else {
          // Take remote value for primitives
          result[key] = value;
        }
      } else {
        // Add new key from remote
        result[key] = value;
      }
    });

    return result;
  }

  /// Resolve list conflicts (e.g., invoice items)
  /// Strategy: Prefer remote for complete replacement
  List<dynamic> resolveList(
    List<dynamic> local,
    List<dynamic> remote,
  ) {
    return remote;
  }

  /// Resolve numeric conflicts (e.g., stock quantity)
  /// Strategy: Take the larger value (safer for stock)
  num resolveNumeric(num local, num remote) {
    return local > remote ? local : remote;
  }

  /// Check if conflict is significant enough to notify user
  bool isSignificantConflict(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
    List<String> criticalFields,
  ) {
    for (final field in criticalFields) {
      if (local[field] != remote[field]) {
        return true;
      }
    }
    return false;
  }
}

/// Extension for DateTime comparison
extension DateTimeComparison on DateTime {
  bool isNewerThan(DateTime other) {
    return isAfter(other);
  }

  bool isOlderThan(DateTime other) {
    return isBefore(other);
  }
}
