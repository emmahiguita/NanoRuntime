import 'package:flutter_riverpod/flutter_riverpod.dart';

class BrowserHistoryItem {
  final String url;
  final String title;
  final DateTime visitedAt;

  const BrowserHistoryItem({
    required this.url,
    required this.title,
    required this.visitedAt,
  });
}

class BrowserBookmarkItem {
  final String url;
  final String title;
  final DateTime? addedAt;

  const BrowserBookmarkItem({
    required this.url,
    required this.title,
    this.addedAt,
  });
}

class BrowserHistoryState {
  final List<BrowserHistoryItem> history;
  final List<BrowserBookmarkItem> bookmarks;

  const BrowserHistoryState({
    this.history = const [],
    this.bookmarks = const [
      BrowserBookmarkItem(url: 'https://www.google.com', title: 'Google'),
      BrowserBookmarkItem(url: 'https://m.youtube.com', title: 'YouTube'),
      BrowserBookmarkItem(url: 'https://github.com', title: 'GitHub'),
      BrowserBookmarkItem(url: 'https://en.wikipedia.org', title: 'Wikipedia'),
    ],
  });

  bool isBookmarked(String url) => bookmarks.any((b) => b.url == url);

  BrowserHistoryState copyWith({
    List<BrowserHistoryItem>? history,
    List<BrowserBookmarkItem>? bookmarks,
  }) {
    return BrowserHistoryState(
      history: history ?? this.history,
      bookmarks: bookmarks ?? this.bookmarks,
    );
  }
}

class BrowserHistoryNotifier extends StateNotifier<BrowserHistoryState> {
  BrowserHistoryNotifier() : super(const BrowserHistoryState(history: []));

  void recordVisit(String url, String title) {
    if (url.isEmpty || url.startsWith('about:')) return;
    final item = BrowserHistoryItem(
      url: url,
      title: title.isNotEmpty ? title : url,
      visitedAt: DateTime.now(),
    );
    // Evitar duplicados inmediatos consecutivos
    final filtered = state.history.where((h) => h.url != url).toList();
    state = state.copyWith(history: [item, ...filtered].take(50).toList());
  }

  void clearHistory() {
    state = state.copyWith(history: []);
  }

  void toggleBookmark(String url, String title) {
    if (url.isEmpty) return;
    if (state.isBookmarked(url)) {
      state = state.copyWith(
        bookmarks: state.bookmarks.where((b) => b.url != url).toList(),
      );
    } else {
      final newBm = BrowserBookmarkItem(
        url: url,
        title: title.isNotEmpty ? title : url,
        addedAt: DateTime.now(),
      );
      state = state.copyWith(bookmarks: [...state.bookmarks, newBm]);
    }
  }

  void removeBookmark(String url) {
    state = state.copyWith(
      bookmarks: state.bookmarks.where((b) => b.url != url).toList(),
    );
  }
}

final browserHistoryProvider =
    StateNotifierProvider<BrowserHistoryNotifier, BrowserHistoryState>((ref) {
      return BrowserHistoryNotifier();
    });
