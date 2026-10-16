import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/provider/system_provider.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/simple_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BankSearchPage extends ConsumerStatefulWidget {
  const BankSearchPage({super.key, this.selectedCode});
  final String? selectedCode;

  @override
  ConsumerState<BankSearchPage> createState() => _BankSearchPageState();
}

class _BankSearchPageState extends ConsumerState<BankSearchPage> {
  final _search = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (ref.read(systemNotifierProvider).bankList?.isNotEmpty != true) {
      Future.microtask(_load);
    }
  }

  Future<void> _load() async {
    if (!mounted || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(systemNotifierProvider.notifier)
        .loadBankList();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isFailure) _error = '銀行資料載入失敗';
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final terms = _search.text.trim().toLowerCase().split(RegExp(r'\s+'));
    final banks = <String, String>{};
    for (final raw in ref.watch(systemNotifierProvider).bankList ?? []) {
      if (raw is! Map) continue;
      final code = raw['code']?.toString().trim() ?? '';
      final name = raw['name']?.toString().trim() ?? '';
      if (code.isNotEmpty &&
          name.isNotEmpty &&
          terms.every((term) => '$code $name'.toLowerCase().contains(term))) {
        banks[code] = name;
      }
    }
    final entries = banks.entries.toList();
    return AppScaffold(
      appBar: const SimpleAppBar(title: '銀行搜尋'),
      useSafeArea: true,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.primaryTextColor),
              decoration: InputDecoration(
                hintText: '輸入銀行代碼或名稱',
                hintStyle: const TextStyle(color: AppColors.mutedTextColor),
                filled: true,
                fillColor: AppColors.fieldInputColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.mutedTextColor,
                ),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除搜尋',
                        icon: const Icon(
                          Icons.clear,
                          color: AppColors.mutedTextColor,
                        ),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: TextButton(
                      onPressed: _load,
                      child: Text('$_error，點擊重試'),
                    ),
                  )
                : entries.isEmpty
                ? const Center(
                    child: Text(
                      '沒有符合的銀行',
                      style: TextStyle(color: AppColors.primaryTextColor),
                    ),
                  )
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final bank = entries[index];
                      return ListTile(
                        title: Text(
                          '${bank.key} ${bank.value}',
                          style: const TextStyle(
                            color: AppColors.primaryTextColor,
                          ),
                        ),
                        trailing: bank.key == widget.selectedCode
                            ? const Icon(
                                Icons.check,
                                color: AppColors.goldColor,
                              )
                            : null,
                        onTap: () => context.pop(bank),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
