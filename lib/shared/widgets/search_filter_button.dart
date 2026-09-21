import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/filter_button.dart';

class SearchFilterButton extends StatelessWidget {
  const SearchFilterButton({
    super.key,
    required this.query,
    required this.onSelect,
  });

  final String query;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return FilterButton(
      isSelected: query.isNotEmpty,
      onPressed: () => onSelect(query),
      icon: const Icon(Icons.search, size: 18),
      child: Text(query.isNotEmpty ? '搜尋：$query' : '關鍵字搜尋'),
    );
  }
}
