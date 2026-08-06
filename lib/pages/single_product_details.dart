import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/collection_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:flutter_ad_ecommerce/widgets/initial_image.dart';
import 'package:flutter_ad_ecommerce/widgets/simple_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SingleProductDetails extends ConsumerStatefulWidget {
  const SingleProductDetails({super.key, required this.extra});

  final dynamic extra;

  @override
  ConsumerState<SingleProductDetails> createState() =>
      _SingleProductDetailsState();
}

class _SingleProductDetailsState extends ConsumerState<SingleProductDetails> {
  Product? _product;
  ProductVariant? _selectedVariant;
  bool _isLoading = true;
  dynamic _error;

  @override
  void initState() {
    super.initState();
    if (widget.extra is Map && widget.extra['product'] != null) {
      setState(() {
        _isLoading = false;
        _setProduct(widget.extra['product']);
      });
    } else if (widget.extra is Map && widget.extra['productId'] is String) {
      Future.delayed(Duration.zero, () {
        _loadSingleProduct(widget.extra['productId']).then((value) {
          if (value.isSuccess) {
            setState(() {
              _isLoading = false;
              _setProduct(value.data!);
            });
          } else {
            setState(() {
              _isLoading = false;
              _error =
                  value.error ??
                  "Failed to load product ${widget.extra['productId']}";
            });
          }
        });
      });
    } else {
      // If data is missing, pop immediately
      WidgetsBinding.instance.addPostFrameCallback((_) => context.pop());
      return;
    }
  }

  void _setProduct(Product product) {
    _product = product;
    final availableVariants = product.availableVariants;
    if (availableVariants.length == 1) {
      _selectedVariant = availableVariants.first;
    } else if (_selectedVariant != null &&
        !availableVariants.any(
          (variant) => variant.id == _selectedVariant!.id,
        )) {
      _selectedVariant = null;
    }
  }

  Future<Result<Product>> _loadSingleProduct(String productId) async {
    try {
      final response = await ref
          .read(dioProvider)
          .get("/api/product/$productId");
      if (response.statusCode != 200) {
        throw Exception("Failed to load product $productId");
      }
      final data = response.data;
      if (data['success'] != true || data['data'] is! Map) {
        throw Exception("Failed to get response data");
      }
      Product product = Product.fromApiResponseMap(data['data']);
      return Result.success(product);
    } catch (e) {
      log("Error loading product $productId: $e");
      return Result.failure("Error loading product $productId: $e");
    }
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLayout({required Widget child}) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      appBar: SimpleAppBar(title: '商品介紹'),
      body: child,
    );
  }

  List<ProductVariant> get _availableVariants =>
      _product?.availableVariants ?? const [];

  bool get _hideAddCartItemButton =>
      widget.extra is Map && widget.extra['hideAddCartItemButton'] == true;

  bool get _hideAddCollectionButton =>
      widget.extra is Map && widget.extra['hideAddCollectionButton'] == true;

  bool get _removeFromCollection =>
      widget.extra is Map && widget.extra['removeFromCollection'] == true;

  int get _displayStock {
    final selectedStock = _selectedVariant?.availableStock;
    if (selectedStock != null) return selectedStock;

    final product = _product;
    if (product == null) return 0;
    if (product.availableStock > 0 || product.variants.isNotEmpty) {
      return product.availableStock;
    }
    return product.stock - product.reserve;
  }

  bool get _canAddToCart {
    final variants = _availableVariants;
    if (variants.isEmpty) return false;
    final selectedVariant = _selectedVariant;
    return selectedVariant != null && selectedVariant.isAvailable;
  }

  bool _isSingleUnnamedDefaultVariant(List<ProductVariant> variants) {
    return variants.length == 1 &&
        (variants.first.name == null || variants.first.name!.trim().isEmpty);
  }

  List<MapEntry<String, dynamic>> get _metadataEntries {
    final metadata = _product?.metadata;
    if (metadata == null || metadata.isEmpty) return const [];

    return metadata.entries
        .where((entry) => entry.key.trim().isNotEmpty && entry.value != null)
        .toList();
  }

  String _formatMetadataValue(dynamic value) {
    if (value is Map || value is List) {
      return jsonEncode(value);
    }
    return value.toString();
  }

  void updateCollection(Product product, {bool isRemoval = false}) {
    final updateFuture = isRemoval
        ? ref
              .read(collectionNotifierProvider.notifier)
              .removeCollection(_product!.id, productName: _product!.name)
        : ref
              .read(collectionNotifierProvider.notifier)
              .addCollection(_product!.id, productName: _product!.name);

    updateFuture.then((result) {
      if (!mounted) return;
      final message = result.isSuccess ? result.data : result.error;
      if (message == null) return;
      ScaffoldMessenger.of(
        // ignore: use_build_context_synchronously
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      if (isRemoval) {
        // ignore: use_build_context_synchronously
        context.pop({'reload': true});
      }
    });
  }

  Future<void> _addSelectedVariantToCart() async {
    final product = _product;
    final selectedVariant = _selectedVariant;
    if (product == null) return;
    if (selectedVariant == null) {
      _showSnackBar('請先選擇商品規格', isError: true);
      return;
    }
    if (!selectedVariant.isAvailable) {
      _showSnackBar('此規格目前缺貨', isError: true);
      return;
    }

    final result = await ref
        .read(cartProvider.notifier)
        .addCartItem(
          product.id,
          productVariantId: selectedVariant.id,
          productName: product.name,
        );
    if (!mounted) return;
    final message = result.isSuccess ? result.data : result.error;
    if (message == null) return;
    _showSnackBar(message, isError: result.isFailure);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildVariantSection() {
    final variants = _availableVariants;
    if (variants.isEmpty) {
      return _buildVariantContainer(
        child: const Text(
          '目前沒有可購買規格',
          style: TextStyle(color: AppColors.secondaryTextColor),
        ),
      );
    }

    if (_isSingleUnnamedDefaultVariant(variants)) {
      return const SizedBox.shrink();
    }

    if (_hideAddCartItemButton) {
      return _buildVariantContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '商品規格',
              style: TextStyle(
                color: AppColors.primaryTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            ...variants.map(_buildVariantReadOnlyRow),
          ],
        ),
      );
    }

    if (variants.length <= 1) return const SizedBox.shrink();

    return _buildVariantContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '選擇規格',
            style: TextStyle(
              color: AppColors.primaryTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Column(
            children: variants
                .map((variant) => _buildVariantOptionRow(variant))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.containerBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: child,
    );
  }

  Widget _buildVariantOptionRow(ProductVariant variant) {
    final isSelected = _selectedVariant?.id == variant.id;
    final stockText = '庫存 ${variant.availableStock}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => setState(() => _selectedVariant = variant),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.navbarIndicatorColor.withValues(alpha: 0.18)
                : AppColors.tileColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.selectedBorderColor
                  : AppColors.borderColor,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? AppColors.infoColor
                    : AppColors.secondaryTextColor,
                size: 22,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  variant.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primaryTextColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                stockText,
                style: const TextStyle(
                  color: AppColors.goldColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVariantReadOnlyRow(ProductVariant variant) {
    final stockText = '庫存 ${variant.availableStock}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 18,
            color: AppColors.secondaryTextColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              variant.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primaryTextColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            stockText,
            style: const TextStyle(
              color: AppColors.secondaryTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataTable() {
    final entries = _metadataEntries;
    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.containerBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '商品資訊',
            style: TextStyle(
              color: AppColors.primaryTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(0.9),
              1: FlexColumnWidth(1.6),
            },
            border: TableBorder.all(color: AppColors.dividerColor, width: 1),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: entries.map((entry) {
              return TableRow(
                children: [
                  _buildMetadataCell(entry.key, isKey: true),
                  _buildMetadataCell(_formatMetadataValue(entry.value)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCell(String text, {bool isKey = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          color: isKey
              ? AppColors.secondaryTextColor
              : AppColors.primaryTextColor,
          fontSize: 13,
          fontWeight: isKey ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _product == null) {
      return _buildLayout(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('載入商品中......', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    } else if (_error != null) {
      return _buildLayout(
        child: Center(
          child: Text("$_error", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final safeAreaPadding = MediaQuery.of(context).padding;
    final addCartDisabled =
        ref.watch(cartProvider).isProcessing || !_canAddToCart;

    return _buildLayout(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: safeAreaPadding.bottom + 24),
        child: Column(
          children: [
            (_product!.images != null && _product!.images!.isNotEmpty)
                ? Stack(
                    children: [
                      GestureDetector(
                        onTap: () => context.push(
                          Routes.photoView,
                          extra: {"urlImages": _product!.images},
                        ),
                        child: FadeInImage.assetNetwork(
                          placeholder: "assets/images/photo_loading.gif",
                          image: _product!.images![0],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          imageErrorBuilder: (context, error, stackTrace) {
                            return Image.asset(
                              "assets/images/photo_not_found.jpg",
                              width: double.infinity,
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.fullscreen,
                              color: Colors.white,
                            ),
                            onPressed: () => context.push(
                              Routes.photoView,
                              extra: {"urlImages": _product!.images},
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.width,
                    child: InitialImage(name: _product!.name),
                  ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        _product!.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      if (_product!.type == "refrigeration")
                        _buildTag("冷藏", Colors.blueAccent)
                      else if (_product!.type == "virtual")
                        _buildTag("免運", Colors.green),
                      if (_product!.allowHomeDelivery &&
                          _product!.type != 'virtual')
                        _buildTag("宅配到府", Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _product!.price.toDollarsString(prefix: "NT"),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                      ),
                      if (_product!.seller != null)
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey[200],
                              ),
                              child:
                                  (_product!.seller!.avatarUrl != null &&
                                      _product!.seller!.avatarUrl!.isNotEmpty)
                                  ? Image.network(
                                      _product!.seller!.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.person,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                    )
                                  : const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _product!.seller!.name,
                              style: TextStyle(
                                color: AppColors.primaryTextColor,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Description
                  if (_product!.description.isNotEmpty)
                    Text(
                      _product!.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                    ),
                  const SizedBox(height: 12),
                  // Meta chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 3,
                    children: [
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        label: Builder(
                          builder: (context) {
                            final String categoryText =
                                (_product!.categories == null ||
                                    _product!.categories!.isEmpty)
                                ? "N/A"
                                : _product!.categories!
                                      .map((c) => c.name)
                                      .join(", ");
                            return Text("分類：$categoryText");
                          },
                        ),
                        backgroundColor: AppColors.primaryButtonColor,
                      ),
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        label: Text(
                          "狀態：${_product!.status.isEmpty ? "N/A" : productStatusTranslation(_product!.status)}",
                        ),
                        backgroundColor: AppColors.secondaryButtonColor,
                      ),
                      Chip(
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        label: Text("庫存：$_displayStock"),
                        labelStyle: const TextStyle(color: Colors.black),
                        backgroundColor: AppColors.goldColor,
                      ),
                    ],
                  ),
                  _buildMetadataTable(),
                  _buildVariantSection(),
                ],
              ),
            ),
            if (!_hideAddCartItemButton || !_hideAddCollectionButton)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    if (!_hideAddCartItemButton)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ElevatedButton(
                            onPressed: addCartDisabled
                                ? null
                                : _addSelectedVariantToCart,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              disabledBackgroundColor: Colors.red.withValues(
                                alpha: 0.42,
                              ),
                              foregroundColor: AppColors.primaryTextColor,
                              disabledForegroundColor: AppColors
                                  .primaryTextColor
                                  .withValues(alpha: 0.78),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                              side: BorderSide.none,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_cart),
                                SizedBox(width: 12),
                                Text("加入購物車"),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (!_hideAddCollectionButton)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ElevatedButton(
                            onPressed:
                                ref
                                    .watch(collectionNotifierProvider)
                                    .isProcessing
                                ? null
                                : () {
                                    updateCollection(
                                      _product!,
                                      isRemoval: _removeFromCollection,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                              foregroundColor: AppColors.primaryTextColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                              side: BorderSide.none,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _removeFromCollection
                                      ? Icons.bookmark_remove
                                      : Icons.bookmark_add,
                                ),
                                SizedBox(width: 12),
                                Text(_removeFromCollection ? "移除收藏" : "加入收藏"),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
