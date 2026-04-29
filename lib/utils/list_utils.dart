extension FirstWhereOrNullExtension<T> on Iterable<T> {
  /// Returns the first element that matches [test], or null if none found.
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (_) {
      return null;
    }
  }
}
