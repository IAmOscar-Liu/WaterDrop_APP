// help_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/provider/account_provider.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/widgets/page_status.dart';
import 'package:flutter_ad_ecommerce/widgets/simple_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HelpPage extends ConsumerStatefulWidget {
  const HelpPage({super.key});

  @override
  ConsumerState<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends ConsumerState<HelpPage> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContentIfNeeded();
  }

  Future<void> _loadContentIfNeeded() async {
    final content = ref.read(systemNotifierProvider).customerSupportContent;
    if (content?.isNotEmpty == true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(systemNotifierProvider.notifier)
        .loadCustomerSupportContent();

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = result.error;
    });
  }

  String _readString(Map<String, dynamic> map, String key, String fallback) {
    final value = map[key];
    return value is String && value.trim().isNotEmpty ? value : fallback;
  }

  int _readSortOrder(Map<String, dynamic> map) {
    final value = map['sortOrder'];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  List<Map<String, dynamic>> _readSections(Map<String, dynamic> content) {
    final sections = content['sections'];
    if (sections is! List) {
      return [];
    }

    return sections.whereType<Map>().map(Map<String, dynamic>.from).toList()
      ..sort((a, b) => _readSortOrder(a).compareTo(_readSortOrder(b)));
  }

  List<Map<String, dynamic>> _readItems(Map<String, dynamic> section) {
    final items = section['items'];
    if (items is! List) {
      return [];
    }

    return items.whereType<Map>().map(Map<String, dynamic>.from).toList()
      ..sort((a, b) => _readSortOrder(a).compareTo(_readSortOrder(b)));
  }

  Widget _buildFAQText(String text) {
    return Text(text, style: const TextStyle(color: Colors.white, height: 1.6));
  }

  Widget _buildFAQExpansionTile(
    BuildContext context, {
    required String title,
    required Widget content,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Material(
        color: AppColors.tileColor,
        borderRadius: BorderRadius.circular(8),
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            expansionTileTheme: const ExpansionTileThemeData(
              iconColor: AppColors.secondaryTextColor,
              collapsedIconColor: AppColors.secondaryTextColor,
            ),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Align(alignment: Alignment.centerLeft, child: content),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryTextColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHelpContent(Map<String, dynamic> content) {
    final sections = _readSections(content);
    if (sections.isEmpty) {
      return const PageError('目前沒有客服幫助內容');
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            for (final section in sections) ...[
              if (_readString(section, 'title', '').isNotEmpty)
                _buildSectionTitle(_readString(section, 'title', '')),
              for (final entry in _readItems(section).indexed)
                _buildFAQExpansionTile(
                  context,
                  title:
                      'Q${entry.$1 + 1}：${_readString(entry.$2, 'question', '')}',
                  content: _buildFAQText(_readString(entry.$2, 'answer', '')),
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(systemNotifierProvider).customerSupportContent;
    final support = content?['support'] is Map
        ? Map<String, dynamic>.from(content!['support'] as Map)
        : <String, dynamic>{};
    final page = content?['page'] is Map
        ? Map<String, dynamic>.from(content!['page'] as Map)
        : <String, dynamic>{};
    final supportEnabled = support['enabled'] != false;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBgColor,
      appBar: SimpleAppBar(title: _readString(page, 'title', '客服/幫助中心')),
      floatingActionButton: supportEnabled
          ? FloatingActionButton.extended(
              onPressed: () {
                final userId = ref.read(accountNotifierProvider).id;
                context.push(
                  Routes.chatroomPage,
                  extra: {
                    "title": _readString(support, 'chatroomTitle', '水滴客服'),
                    "userId": userId,
                  },
                );
              },
              backgroundColor: AppColors.infoColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              icon: const Icon(Icons.support_agent),
              label: Text(_readString(support, 'label', '聯絡客服')),
            )
          : null,
      body: SafeArea(
        child: content?.isNotEmpty == true
            ? _buildHelpContent(content!)
            : _isLoading
            ? const PageLoading('載入客服幫助內容中......')
            : PageError(_errorMessage ?? '目前沒有客服幫助內容'),
      ),
    );
  }
}
