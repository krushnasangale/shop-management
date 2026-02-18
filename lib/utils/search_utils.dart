/// Utility functions for search functionality across the application
class SearchUtils {
  /// Check if search query matches as subsequence in text
  /// (characters appear in order, not necessarily consecutive)
  /// Case-insensitive matching
  static bool matchesSubsequence(String text, String query) {
    if (query.isEmpty) return true;
    if (text.isEmpty) return false;

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    int queryIndex = 0;
    for (
      int i = 0;
      i < lowerText.length && queryIndex < lowerQuery.length;
      i++
    ) {
      if (lowerText[i] == lowerQuery[queryIndex]) {
        queryIndex++;
      }
    }
    return queryIndex == lowerQuery.length;
  }

  /// Legacy contains-based search (kept for backward compatibility)
  static bool matchesContains(String text, String query) {
    if (query.isEmpty) return true;
    return text.toLowerCase().contains(query.toLowerCase());
  }
}
