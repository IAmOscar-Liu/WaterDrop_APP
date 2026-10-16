import 'package:flutter_ad_ecommerce/shared/widgets/pagination_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/order/order_date_range.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/order_card.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/order_date_filter.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/provider/order_provider.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/filter_button.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/messaging_app_bar.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/page_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

class OrderPage extends ConsumerStatefulWidget {
  const OrderPage({super.key});

  @override
  ConsumerState<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends ConsumerState<OrderPage> {
  String _order = "desc";
  OrderDateRange? _dateRange;
  String? _paginationError;
  int _queryGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadOrders();
    });
  }

  void _loadOrders() {
    _queryGeneration++;
    setState(() => _paginationError = null);
    ref
        .read(orderNotifierProvider.notifier)
        .loadOrders(
          order: _order,
          startDate: _dateRange?.startUtc,
          endDate: _dateRange?.endExclusiveUtc,
        );
  }

  Future<void> _fetchMoreOrders() async {
    if (!ref.read(orderNotifierProvider).isDone) return;
    final generation = _queryGeneration;
    final error = await ref
        .read(orderNotifierProvider.notifier)
        .fetchMoreOrders();
    if (!mounted || generation != _queryGeneration) return;
    setState(() => _paginationError = error);
  }

  Widget _buildOrderButton() {
    return FilterButton(
      isSelected: true,
      onPressed: () {
        setState(() {
          _order = _order == "asc" ? "desc" : "asc";
        });
        _loadOrders();
      },
      icon: Icon(
        _order == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
        size: 18,
      ),
      child: Text(_order == "asc" ? "由前往後" : "由後往前"),
    );
  }

  Widget _buildLayout({required Widget child}) {
    return AppScaffold(
      appBar: MessagingAppBar(title: '訂單記錄'),
      useSafeArea: true,
      body: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = ref.watch(orderNotifierProvider);
    final List<Order> orders = orderProvider.data?.orders ?? [];

    return _buildLayout(
      child: Padding(
        padding: EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  _buildOrderButton(),
                  const SizedBox(width: 8),
                  OrderDateFilter(
                    range: _dateRange,
                    onChanged: (range) {
                      setState(() => _dateRange = range);
                      _loadOrders();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: orderProvider.isInitial || orderProvider.isLoading
                  ? PageLoading('載入訂單中......')
                  : orderProvider.hasError
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PageError('無法載入訂單：${orderProvider.error}'),
                        TextButton(
                          onPressed: _loadOrders,
                          child: const Text('重試'),
                        ),
                      ],
                    )
                  : orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.list_alt_outlined,
                            size: 80,
                            color: AppColors.mutedTextColor,
                          ),
                          SizedBox(height: 24),
                          Text(
                            _dateRange == null ? '訂單是空的' : '此期間內沒有訂單',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryTextColor,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            _dateRange == null
                                ? '快去逛逛，喜歡就立即下訂吧！'
                                : '請選擇其他日期，或選擇「全部」',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: orders.length + 1,
                      itemBuilder: (context, index) {
                        if (index == orders.length) {
                          return PaginationFooter(
                            loading: orderProvider.isFetching,
                            hasError: _paginationError != null,
                            onLoadMore:
                                orderProvider.data!.page <
                                    orderProvider.data!.totalPages
                                ? _fetchMoreOrders
                                : null,
                          );
                        }
                        final order = orders[index];
                        Widget card = OrderCard(order: order);
                        if (index == orders.length - 1) {
                          card = VisibilityDetector(
                            key: Key('$_queryGeneration-${order.id}'),
                            onVisibilityChanged: (visibilityInfo) {
                              if (mounted &&
                                  _paginationError == null &&
                                  visibilityInfo.visibleFraction > 0.2) {
                                _fetchMoreOrders();
                              }
                            },
                            child: card,
                          );
                        }
                        return Padding(
                          key: ValueKey(order.id),
                          padding: const EdgeInsets.all(2),
                          child: card,
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
