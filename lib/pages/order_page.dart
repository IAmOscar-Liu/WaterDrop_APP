import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/order/widgets/order_card.dart';
import 'package:flutter_ad_ecommerce/models/order.dart';
import 'package:flutter_ad_ecommerce/provider/order_provider.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/filter_button.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/messaging_app_bar.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/page_status.dart';
import 'package:flutter_masonry_view/flutter_masonry_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

class OrderPage extends ConsumerStatefulWidget {
  const OrderPage({super.key});

  @override
  ConsumerState<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends ConsumerState<OrderPage> {
  String _order = "desc";

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    Future.delayed(Duration.zero, () {
      ref.read(orderNotifierProvider.notifier).loadOrders(order: _order);
    });
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
      icon: const Icon(Icons.sort, size: 18),
      child: Text(_order == "asc" ? "由前到後" : "由後到前"),
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
    if (orderProvider.isInitial || orderProvider.isLoading) {
      return _buildLayout(child: PageLoading('載入訂單中......'));
    }

    final List<Order> orders = orderProvider.data?.orders ?? [];

    return _buildLayout(
      child: Padding(
        padding: EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16,
                bottom: 4.0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [_buildOrderButton(), const SizedBox(width: 8)],
              ),
            ),
            Expanded(
              child: orderProvider.hasError
                  ? PageError("Failed to load orders: ${orderProvider.error}")
                  : orderProvider.data!.orders.isEmpty
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
                            '訂單是空的',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryTextColor,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            '快去逛逛，喜歡就立即下訂吧！',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          MasonryView(
                            listOfItem: orders,
                            itemPadding: 2,
                            numberOfColumn: 1,
                            itemBuilder: (item) {
                              final Order order = item;
                              if (order.id == orders.last.id) {
                                return VisibilityDetector(
                                  key: Key(order.id),
                                  onVisibilityChanged: (visibilityInfo) {
                                    if (visibilityInfo.visibleFraction > 0.2) {
                                      ref
                                          .read(orderNotifierProvider.notifier)
                                          .fetchMoreOrders();
                                    }
                                  },
                                  child: OrderCard(order: order),
                                );
                              }
                              return OrderCard(order: order);
                            },
                          ),
                          if (orderProvider.isFetching)
                            Center(child: CircularProgressIndicator()),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
