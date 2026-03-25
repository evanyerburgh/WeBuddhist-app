/// Centralized configuration for protected API routes that require authentication.
class ProtectedRoutes {
  /// List of all protected API paths.
  ///
  /// Paths can contain path parameters in curly braces like {planId}, {taskId}, etc.
  /// These parameters will match any value in that segment position.
  ///
  /// IMPORTANT: These paths should NOT include the /api/v1 prefix as the base URL
  /// is already configured with it. Match the exact paths used in API calls.
  static const List<String> paths = [
    // User profile
    '/users/info',
    '/users/upload',

    // User progress - all /users/me routes require auth
    '/users/me',
    '/users/me/plans',
    '/users/me/plans/{planId}',
    '/users/me/tasks',
    '/users/me/tasks/{taskId}/complete',
    '/users/me/sub-tasks',
    '/users/me/sub-tasks/{subTaskId}/complete',
    '/users/me/task/{taskId}',
    '/users/me/plan/{planId}/days/{dayNumber}',
    '/users/me/plan/{planId}/days/{dayNumber}/content',

    // Recitations
    '/users/me/recitations',
    '/users/me/recitations/{recitationId}',

    // AI chat
    '/chats',
    '/threads',
    '/threads/{threadId}',

    // Plans (public endpoints but may need auth for user-specific data)
    '/plans/{planId}',
    '/plans/{planId}/days',
    '/plans/{planId}/days/{dayNumber}',

    // Catch-all for all /users/me paths (better to be safe)
    '/users/me/',
  ];

  /// Check if a given path is protected (requires authentication).
  ///
  /// Returns true if the path matches any protected route pattern.
  static bool isProtected(String path) {
    return paths.any((route) => _matchesPathPattern(path, route));
  }

  /// Matches a path against a pattern that may contain path parameters like {planId}.
  ///
  /// Examples:
  /// - `_matchesPathPattern('/api/v1/users/me', '/api/v1/users/me')` → true
  /// - `_matchesPathPattern('/api/v1/users/me/plans/123', '/api/v1/users/me/plans/{planId}')` → true
  /// - `_matchesPathPattern('/api/v1/users/me/plans/123/tasks', '/api/v1/users/me/plans/{planId}')` → false
  static bool _matchesPathPattern(String path, String pattern) {
    // If no parameters in pattern, do simple prefix match
    if (!pattern.contains('{')) {
      return path.startsWith(pattern);
    }

    // Split both path and pattern into segments
    final pathSegments = path.split('/').where((s) => s.isNotEmpty).toList();
    final patternSegments = pattern.split('/').where((s) => s.isNotEmpty).toList();

    // Must have same number of segments
    if (pathSegments.length != patternSegments.length) {
      return false;
    }

    // Compare each segment
    for (var i = 0; i < pathSegments.length; i++) {
      final pathSegment = pathSegments[i];
      final patternSegment = patternSegments[i];

      // If pattern segment is a parameter (e.g., {planId}), it matches any value
      if (patternSegment.startsWith('{') && patternSegment.endsWith('}')) {
        continue;
      }

      // Otherwise, segments must match exactly
      if (pathSegment != patternSegment) {
        return false;
      }
    }

    return true;
  }
}
