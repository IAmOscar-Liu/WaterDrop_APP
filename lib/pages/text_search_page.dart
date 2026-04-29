import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/widgets/simple_app_bar.dart';
import 'package:go_router/go_router.dart';

class TextSearchPage extends StatefulWidget {
  const TextSearchPage({super.key, required this.textSearch});

  final String textSearch;

  @override
  State<TextSearchPage> createState() => _TextSearchPageState();
}

class _TextSearchPageState extends State<TextSearchPage> {
  // Use a TextEditingController to manage the text field's state
  late final TextEditingController _textController;

  // Mock data for search suggestions
  List<String> _suggestions = [
    '手機殼',
    '保護貼',
    '充電線',
    '藍牙耳機',
    '行動電源',
    '智慧手錶',
    '筆記型電腦',
    '平板電腦',
    '相機',
    '遊戲機',
    '手機',
    '電視',
    '手機支架',
    '手機貼膜',
    '手機充電器',
    '平板電腦保護殼',
  ];

  // The list of suggestions to display, filtered based on user input
  List<String> _filteredSuggestions = [];

  @override
  void initState() {
    super.initState();
    _loadProductSuggestions();
    // Initialize the text controller with the text from the previous page
    _textController = TextEditingController(text: widget.textSearch);
    // Add a listener to the text controller to rebuild the widget when the text changes.
    // This is needed to show/hide the clear button.
    _textController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadProductSuggestions() async {
    try {
      // 1. Load the JSON file as a string from the assets folder.
      // Make sure you have created the file at this path: /assets/json/mock_product_list.json
      // And declared it in your pubspec.yaml file.
      final String jsonString = await rootBundle.loadString(
        'assets/json/mock_product_list.json',
      );

      // 2. Decode the JSON string into a Dart Map.
      // The structure is Map<String, dynamic> where the value is a List<dynamic>.
      final Map<String, dynamic> data = json.decode(jsonString);

      // 3. Create a temporary list to hold all items.
      final List<String> allItems = [];

      // 4. Iterate over the values of the map (which are the lists of products).
      for (var productList in data.values) {
        // Ensure each item is a String and add it to our master list.
        allItems.addAll(List<String>.from(productList));
      }

      // 5. Update the state with the loaded data.
      // This will trigger a rebuild of the widget to display the list.
      if (mounted) {
        print("suggestions length: ${allItems.length} ");
        final combineList = [..._suggestions, ...allItems];
        setState(() {
          _suggestions = combineList.toSet().toList();
          // Call _filterSuggestions() here to ensure the list is filtered after data is loaded
          _filterSuggestions();
        });
      }
    } catch (e) {
      // Handle any errors that might occur during loading/parsing
      print('Error loading product suggestions: $e');
    }
  }

  // A method to filter the suggestions based on user input
  void _filterSuggestions() {
    final String query = _textController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        // If the input is empty, show the first 5 suggestions
        _filteredSuggestions = _suggestions.take(5).toList();
      } else {
        // If there's input, filter and show the most relevant 5
        final List<String> matches = _suggestions
            .where((suggestion) => suggestion.toLowerCase().contains(query))
            .toList();

        // Sort the matched suggestions based on relevance
        matches.sort((a, b) {
          final int aCount = a.toLowerCase().split(query).length - 1;
          final int bCount = b.toLowerCase().split(query).length - 1;
          return bCount.compareTo(aCount); // Sort in descending order
        });

        _filteredSuggestions = matches.take(5).toList();

        // Add the user's input as the first item if it's not already in the list
        if (!_filteredSuggestions.any((s) => s.toLowerCase() == query)) {
          _filteredSuggestions.insert(0, _textController.text);
        }
      }
    });
  }

  // A method to handle item taps and keyboard "send" action
  void _performSearch(String searchText) {
    // This is a placeholder for `Navigator.pop(context, searchText)`.
    // Since we don't have access to Navigator here, we will print the result.
    // Replace this with `Navigator.pop(context, searchText);` in a real app.

    debugPrint('Performing search for: $searchText');
    context.pop(searchText);
  }

  // A helper function to build a RichText widget with highlighted matched query.
  Widget _buildHighlightedText(String text, String query) {
    final lowerCaseText = text.toLowerCase();
    final lowerCaseQuery = query.toLowerCase();

    // If the query is empty or doesn't exist, return a normal Text widget.
    if (lowerCaseQuery.isEmpty || !lowerCaseText.contains(lowerCaseQuery)) {
      return Text(
        text,
        style: const TextStyle(color: AppColors.primaryTextColor),
      );
    }

    // Find the starting index of the query in the text
    final startIndex = lowerCaseText.indexOf(lowerCaseQuery);
    final endIndex = startIndex + lowerCaseQuery.length;

    // Split the string into three parts: before, the match, and after.
    final leadingText = text.substring(0, startIndex);
    final matchedText = text.substring(startIndex, endIndex);
    final trailingText = text.substring(endIndex);

    // Return a RichText widget with different styles for each part.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBgColor,
      appBar: SimpleAppBar(title: '關鍵字搜尋'),
      resizeToAvoidBottomInset: true,
      // Use GestureDetector to dismiss the keyboard when clicking outside the text field
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            // The search text field
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
            // The list of suggestions
            Expanded(
              child: ListView.builder(
                itemCount: _filteredSuggestions.length,
                itemBuilder: (context, index) {
                  final String suggestion = _filteredSuggestions[index];
                  return ListTile(
                    leading: const Icon(
                      Icons.search,
                      color: AppColors.primaryTextColor,
                    ),
                    title: _buildHighlightedText(
                      suggestion,
                      _textController.text,
                    ),
                    onTap: () {
                      _performSearch(suggestion);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
