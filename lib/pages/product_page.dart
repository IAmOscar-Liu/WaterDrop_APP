import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/explore/widget/price_range_dialog.dart';
import 'package:flutter_ad_ecommerce/features/explore/widget/product_card.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/product_category_provider.dart';
import 'package:flutter_ad_ecommerce/provider/product_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/events.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:flutter_ad_ecommerce/widgets/messaging_app_bar.dart';
import 'package:flutter_ad_ecommerce/widgets/page_status.dart';
import 'package:flutter_masonry_view/flutter_masonry_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ProductPage extends ConsumerStatefulWidget {
  const ProductPage({super.key});

  @override
  ConsumerState<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends ConsumerState<ProductPage> {
  Category _selectedCategory = Category(id: "all", name: '全部');
  String _textSearch = '';
  int? _minPrice;
  int? _maxPrice;

  late StreamSubscription _routeChangeSubscription;

  @override
  void initState() {
    super.initState();
    _loadProducts();

    _routeChangeSubscription = eventBus.on<RouterChangeEvent>().listen((
      event,
    ) async {
      if (event.to == Routes.productPage && event.to != event.from) {
        log('[Home] re-enter product page');
        _loadProducts();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _routeChangeSubscription.cancel();
  }

  void _loadProducts() {
    Future.delayed(Duration.zero, () {
      ref
          .read(productNotifierProvider.notifier)
          .loadProducts(
            categoryId: _selectedCategory.id == "all"
                ? null
                : _selectedCategory.id,
            search: _textSearch.isEmpty ? null : _textSearch,
            minPrice: _minPrice,
            maxPrice: _maxPrice,
          );
    });
  }

  Widget _buildCategoryButton(
    Category category, {
    required bool isSelected,
    required void Function(Category) onSelect,
  }) {
    return isSelected
        ? ElevatedButton(
            onPressed: () => onSelect(category),
            style: ElevatedButton.styleFrom(
              foregroundColor: AppColors.primaryTextColor,
              backgroundColor: AppColors.navbarIndicatorColor,
              shape: StadiumBorder(),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(category.name),
          )
        : OutlinedButton(
            onPressed: () => onSelect(category),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.secondaryTextColor,
              side: BorderSide(color: AppColors.borderColor),
              shape: StadiumBorder(),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(category.name),
          );
  }

  Widget _buildSearchButton({required void Function(String) onSelect}) {
    return _textSearch.isNotEmpty
        ? ElevatedButton.icon(
            onPressed: () => onSelect(_textSearch),
            style: ElevatedButton.styleFrom(
              foregroundColor: AppColors.primaryTextColor,
              backgroundColor: AppColors.navbarIndicatorColor,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: const Icon(Icons.search, size: 18),
            label: Text("搜尋：$_textSearch"),
          )
        : OutlinedButton.icon(
            onPressed: () => onSelect(_textSearch),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.secondaryTextColor,
              side: BorderSide(color: AppColors.borderColor),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: const Icon(Icons.search, size: 18),
            label: const Text("關鍵字搜尋"),
          );
  }

  Widget _buildPriceRangeButton({required void Function() onPressed}) {
    return (_minPrice != null || _maxPrice != null)
        ? ElevatedButton.icon(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              foregroundColor: AppColors.primaryTextColor,
              backgroundColor: AppColors.navbarIndicatorColor,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: const Icon(Icons.paid, size: 18),
            label: Text(
              "價格：${_minPrice == null ? "無限制" : _minPrice!.toDollarsString(prefix: "NT")} ~ ${_maxPrice == null ? "無限制" : _maxPrice!.toDollarsString(prefix: "NT")}",
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.secondaryTextColor,
              side: BorderSide(color: AppColors.borderColor),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: const Icon(Icons.paid, size: 18),
            label: const Text("價格搜尋"),
          );
  }

  Widget _buildLayout({required Widget child}) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBgColor,
      appBar: MessagingAppBar(title: '市集'),
      body: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = ref.watch(productNotifierProvider);
    if (productProvider.isInitial || productProvider.isLoading) {
      return _buildLayout(child: PageLoading('載入商品中......'));
    }

    final List<Product> products = productProvider.data?.products ?? [];
    final List<Category> productCategories = ref.watch(productCategoryProvider);

    return _buildLayout(
      child: Padding(
        padding: EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 8.0,
                bottom: 4,
              ),
              child: Builder(
                builder: (context) {
                  void onSelect(Category category) {
                    setState(() {
                      _selectedCategory = category;
                    });
                    _loadProducts();
                  }

                  return Row(
                    children: [
                      _buildCategoryButton(
                        Category(id: "all", name: '全部'),
                        isSelected: _selectedCategory.id == 'all',
                        onSelect: onSelect,
                      ),
                      const SizedBox(width: 8),
                      ...productCategories.map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: _buildCategoryButton(
                            category,
                            isSelected: _selectedCategory.id == category.id,
                            onSelect: onSelect,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16,
                bottom: 4.0,
              ),
              child: Builder(
                builder: (context) {
                  void onSelectTextSearch(String textSearch) {
                    context.push(Routes.textSearch, extra: textSearch).then((
                      value,
                    ) {
                      if (value is String) {
                        setState(() {
                          _textSearch = value;
                        });
                        _loadProducts();
                      }
                    });
                  }

                  void onSelectPriceRange() {
                    showDialog(
                      context: context,
                      builder: (context) {
                        return PriceRangeDialog(
                          minPrice: _minPrice,
                          maxPrice: _maxPrice,
                          onSuccess: ({maxPrice, minPrice}) {
                            setState(() {
                              _maxPrice = maxPrice;
                              _minPrice = minPrice;
                            });
                            _loadProducts();
                          },
                        );
                      },
                      // This is important for scrollable dialogs
                      // It makes the dialog occupy the full screen height
                      // allowing the content to be scrollable if needed.
                      useSafeArea: true,
                    );
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSearchButton(onSelect: onSelectTextSearch),
                      const SizedBox(width: 8),
                      _buildPriceRangeButton(onPressed: onSelectPriceRange),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: productProvider.hasError
                  ? PageError(
                      "Failed to load products: ${productProvider.error}",
                    )
                  : productProvider.data!.products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sentiment_dissatisfied,
                            size: 48,
                            color: Colors.white,
                          ),
                          SizedBox(height: 12),
                          Text(
                            "很抱歉，找不到您想要的相關商品",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.only(left: 8, right: 8, bottom: 16),
                      child: Column(
                        children: [
                          MasonryView(
                            listOfItem: products,
                            itemPadding: 2,
                            numberOfColumn: 2,
                            itemBuilder: (item) {
                              final Product product = item;
                              if (product.id == products.last.id) {
                                return VisibilityDetector(
                                  key: Key(product.id),
                                  onVisibilityChanged: (visibilityInfo) {
                                    if (visibilityInfo.visibleFraction > 0.2) {
                                      ref
                                          .read(
                                            productNotifierProvider.notifier,
                                          )
                                          .fetchMoreProducts();
                                    }
                                  },
                                  child: ProductCard(product: product),
                                );
                              }
                              return ProductCard(product: product);
                            },
                          ),
                          if (productProvider.isFetching)
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
