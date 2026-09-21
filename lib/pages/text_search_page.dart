import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/simple_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TextSearchSource {
  product,
  collection,
  message;

  String get historyKey => 'text-search-history-$name';

  String get historyTitle => switch (this) {
    TextSearchSource.product => '商品搜尋記錄',
    TextSearchSource.collection => '收藏搜尋記錄',
    TextSearchSource.message => '訊息搜尋記錄',
  };

  bool get showsPopularSearches => this != TextSearchSource.message;
}

class TextSearchPage extends ConsumerStatefulWidget {
  const TextSearchPage({
    super.key,
    required this.textSearch,
    this.source = TextSearchSource.product,
  });

  final String textSearch;
  final TextSearchSource source;

  @override
  ConsumerState<TextSearchPage> createState() => _TextSearchPageState();
}

class _TextSearchPageState extends ConsumerState<TextSearchPage> {
  static const _maxSearchHistory = 10;

  late final TextEditingController _textController;

  List<String> _suggestions = [];

  List<String> _filteredSuggestions = [];
  List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    // Initialize the text controller with the text from the previous page
    _textController = TextEditingController(text: widget.textSearch);
    _textController.addListener(() {
      setState(() {});
    });
    _filteredSuggestions = _buildFilteredSuggestions();
    _loadSearchHistory();
    if (widget.source.showsPopularSearches) {
      _loadProductSuggestions();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadProductSuggestions() async {
    try {
      Map<String, dynamic> data =
          ref.read(systemNotifierProvider).productRecommendation ?? {};

      if (data.isEmpty) {
        final result = await ref
            .read(systemNotifierProvider.notifier)
            .loadProductRecommendation();
        if (result.isFailure) {
          debugPrint('Error loading product suggestions: ${result.error}');
          return;
        }
        data = result.data ?? {};
      }

      final popular = data['popular'];
      final suggestions = popular is Iterable
          ? popular.whereType<String>().toSet().toList()
          : <String>[];

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _filteredSuggestions = _buildFilteredSuggestions();
        });
      }
    } catch (e) {
      // Handle any errors that might occur during loading/parsing
      debugPrint('Error loading product suggestions: $e');
    }
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(widget.source.historyKey) ?? [];

    if (mounted) {
      setState(() {
        _searchHistory = history;
      });
    }
  }

  Future<void> _saveSearchHistory(String searchText) async {
    final trimmedSearchText = searchText.trim();
    if (trimmedSearchText.isEmpty) {
      return;
    }

    final history = [
      trimmedSearchText,
      ..._searchHistory.where((item) => item != trimmedSearchText),
    ].take(_maxSearchHistory).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(widget.source.historyKey, history);

    if (mounted) {
      setState(() {
        _searchHistory = history;
      });
    }
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(widget.source.historyKey);

    if (mounted) {
      setState(() {
        _searchHistory = [];
      });
    }
  }

  List<String> _buildFilteredSuggestions() {
    final String query = _textController.text.toLowerCase();

    if (query.isEmpty) {
      return _suggestions.take(5).toList();
    }

    final List<String> matches = _suggestions
        .where((suggestion) => suggestion.toLowerCase().contains(query))
        .toList();

    matches.sort((a, b) {
      final int aCount = a.toLowerCase().split(query).length - 1;
      final int bCount = b.toLowerCase().split(query).length - 1;
      return bCount.compareTo(aCount); // Sort in descending order
    });

    final filteredSuggestions = matches.take(5).toList();

    // Add the user's input as the first item if it's not already in the list
    if (!filteredSuggestions.any((s) => s.toLowerCase() == query)) {
      filteredSuggestions.insert(0, _textController.text);
    }

    return filteredSuggestions;
  }

  void _filterSuggestions() {
    setState(() {
      _filteredSuggestions = _buildFilteredSuggestions();
    });
  }

  Future<void> _performSearch(String searchText) async {
    final trimmedSearchText = searchText.trim();
    if (trimmedSearchText.isEmpty) {
      if (mounted) {
        context.pop('');
      }
      return;
    }

    debugPrint('Performing search for: $trimmedSearchText');
    await _saveSearchHistory(trimmedSearchText);
    if (mounted) {
      context.pop(trimmedSearchText);
    }
  }

  Widget _buildHighlightedText(String text, String query) {
    final lowerCaseText = text.toLowerCase();
    final lowerCaseQuery = query.toLowerCase();

    if (lowerCaseQuery.isEmpty || !lowerCaseText.contains(lowerCaseQuery)) {
      return Text(
        text,
        style: const TextStyle(color: AppColors.primaryTextColor),
      );
    }

    final startIndex = lowerCaseText.indexOf(lowerCaseQuery);
    final endIndex = startIndex + lowerCaseQuery.length;

    final leadingText = text.substring(0, startIndex);
    final matchedText = text.substring(startIndex, endIndex);
    final trailingText = text.substring(endIndex);

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppColors.primaryTextColor),
        children: [
          TextSpan(text: leadingText),
          TextSpan(
            text: matchedText,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.goldColor,
            ),
          ),
          TextSpan(text: trailingText),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onClear}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.primaryTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: '清除搜尋記錄',
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.mutedTextColor,
              ),
              onPressed: onClear,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchItem(String text, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryTextColor),
      title: _buildHighlightedText(text, _textController.text),
      onTap: () {
        _performSearch(text);
      },
    );
  }

  List<String> _filterItems(List<String> items) {
    final query = _textController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return items;
    }

    return items.where((item) => item.toLowerCase().contains(query)).toList();
  }

  Widget _buildSearchGroups() {
    final history = _filterItems(_searchHistory);
    final popularSearches = _textController.text.trim().isEmpty
        ? _suggestions.take(8).toList()
        : _filteredSuggestions;

    return ListView(
      children: [
        if (history.isNotEmpty) ...[
          _buildSectionHeader(
            widget.source.historyTitle,
            onClear: _clearSearchHistory,
          ),
          ...history.map((item) => _buildSearchItem(item, Icons.history)),
        ],
        if (widget.source.showsPopularSearches) ...[
          _buildSectionHeader('熱門搜尋'),
          ...popularSearches.map(
            (item) => _buildSearchItem(item, Icons.search),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: SimpleAppBar(title: '關鍵字搜尋'),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _textController,
                onChanged: (_) => _filterSuggestions(),
                onSubmitted: (value) => _performSearch(value),
                style: const TextStyle(color: AppColors.primaryTextColor),
                decoration: InputDecoration(
                  hintText: '輸入關鍵字搜尋',
                  hintStyle: const TextStyle(color: AppColors.mutedTextColor),
                  filled: true,
                  fillColor: AppColors.fieldInputColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: InkWell(
                    onTap: () {
                      _performSearch(_textController.text);
                    },
                    child: const Icon(
                      Icons.search,
                      color: AppColors.mutedTextColor,
                    ),
                  ),
                  suffixIcon: _textController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: AppColors.mutedTextColor,
                          ),
                          onPressed: () {
                            _textController.clear();
                            _filterSuggestions();
                          },
                        )
                      : null,
                ),
              ),
            ),
            Expanded(child: _buildSearchGroups()),
          ],
        ),
      ),
    );
  }
}
