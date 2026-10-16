import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/models/api_enums.dart';
import 'package:flutter_ad_ecommerce/provider/cart_provider.dart';
import 'package:flutter_ad_ecommerce/provider/collection_provider.dart';
import 'package:flutter_ad_ecommerce/provider/dio_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/initial_image.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/selection_option_tile.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/simple_app_bar.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:flutter_ad_ecommerce/utils/result.dart';
import 'package:flutter_ad_ecommerce/utils/product_availability.dart';
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
  bool? _isCollected;
  bool _isCheckingCollection = false;
  bool _isUpdatingCollection = false;
  String? _collectionStatusError;

  @override
  void initState() {
    super.initState();
    if (widget.extra is Map && widget.extra['product'] != null) {
      setState(() {
        _isLoading = false;
        _setProduct(widget.extra['product']);
      });
      _loadCollectionStatus();
    } else if (widget.extra is Map && widget.extra['productId'] is String) {
      Future.delayed(Duration.zero, () {
        _loadSingleProduct(widget.extra['productId']).then((value) {
          if (!mounted) return;
          if (value.isSuccess) {
            setState(() {
              _isLoading = false;
              _setProduct(value.data!);
            });
            _loadCollectionStatus();
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

  void _setProduct(Product product, {bool selectDefault = true}) {
    final previousId = _selectedVariant?.id;
    _product = product;
    _isCollected = product.isCollected ?? (_openedFromCollection ? true : null);
    final variants = product.availableVariants;
    _selectedVariant = null;
    if (!product.isPurchasable) return;
    for (final variant in variants) {
      if (variant.id == previousId) _selectedVariant = variant;
    }
    if (previousId == null && selectDefault && variants.length == 1) {
      _selectedVariant = variants.first;
    }
  }

  Future<void> _refreshUnavailableProduct() async {
    final id = _product?.id;
    if (id == null) return;
    setState(() => _isLoading = true);
    final result = await _loadSingleProduct(id);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _setProduct(result.data!, selectDefault: false);
      } else {
        _selectedVariant = null;
        _error = '商品目前無法使用，請返回後重新整理。';
      }
    });
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
    return AppScaffold(
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

  bool get _isProductActive => _product?.isPurchasable == true;

  bool get _showAddCartButton => _isProductActive && !_hideAddCartItemButton;

  bool get _showCollectionButton =>
      !_hideAddCollectionButton && (_isCollected != false || _isProductActive);

  bool get _openedFromCollection =>
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

  double get _displayPrice {
    final selectedPrice = _selectedVariant?.price ?? 0;
    if (selectedPrice > 0) return selectedPrice;
    return _product?.price ?? 0;
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

  Future<void> _loadCollectionStatus() async {
    final product = _product;
    if (product == null || _hideAddCollectionButton || _isCollected != null) {
      return;
    }
    setState(() {
      _isCheckingCollection = true;
      _collectionStatusError = null;
    });
    final result = await _loadSingleProduct(product.id);
    if (!mounted) return;
    setState(() {
      _isCheckingCollection = false;
      if (result.isSuccess && result.data!.isCollected != null) {
        _setProduct(result.data!);
      } else {
        _collectionStatusError = '無法讀取收藏狀態，請重試';
      }
    });
    if (result.isFailure) {
      _showSnackBar('無法讀取收藏狀態，請重試', isError: true);
    }
  }

  Future<void> _updateCollection() async {
    final product = _product;
    if (product == null || _isCollected == null || _isUpdatingCollection) {
      return;
    }
    final isRemoval = _isCollected!;
    setState(() => _isUpdatingCollection = true);
    final notifier = ref.read(collectionNotifierProvider.notifier);
    final result = isRemoval
        ? await notifier.removeCollection(product.id, productName: product.name)
        : await notifier.addCollection(product.id, productName: product.name);
    if (!mounted) return;
    setState(() {
      _isUpdatingCollection = false;
      if (result.isSuccess) {
        _isCollected = !isRemoval;
        _product = _product!.copyWith(isCollected: !isRemoval);
      }
    });
    _showSnackBar(
      result.isSuccess
          ? (result.data ?? (isRemoval ? '商品已移除我的收藏' : '商品已加入我的收藏'))
          : (result.error ?? '無法更新收藏，請重試'),
      isError: result.isFailure,
    );
    if (result.isFailure && result.error == productUnavailableMessage) {
      await _refreshUnavailableProduct();
      if (!mounted) return;
    }
    if (result.isSuccess && isRemoval && _openedFromCollection) {
      context.pop({'reload': true});
    }
  }

  Future<void> _addSelectedVariantToCart() async {
    final product = _product;
    final selectedVariant = _selectedVariant;
    if (product == null || !product.isPurchasable) return;
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
    if (result.isFailure && result.error == productUnavailableMessage) {
      await _refreshUnavailableProduct();
    }
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
    final readOnly = !_isProductActive || _hideAddCartItemButton;
    final variants = _isProductActive
        ? _availableVariants
        : (_product?.variants ?? const <ProductVariant>[]);
    if (variants.isEmpty) {
      return _buildVariantContainer(
        child: const Text(
          '目前沒有可購買規格',
          style: TextStyle(color: AppColors.secondaryTextColor),
        ),
      );
    }

    if (_isSingleUnnamedDefaultVariant(variants) &&
        (readOnly || _selectedVariant != null)) {
      return const SizedBox.shrink();
    }

    if (readOnly) {
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

    if (variants.length <= 1 && _selectedVariant != null) {
      return const SizedBox.shrink();
    }

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

  List<String> _getVariantImages(ProductVariant variant) {
    return variant.images
            ?.where((image) => image.trim().isNotEmpty)
            .toList(growable: false) ??
        const <String>[];
  }

  void _openVariantImagePreview(ProductVariant variant) {
    final images = _getVariantImages(variant);
    if (images.isEmpty) return;

    context.push(Routes.photoView, extra: {"urlImages": images});
  }

  Widget _buildVariantPreviewButton(ProductVariant variant) {
    final hasImages = _getVariantImages(variant).isNotEmpty;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: hasImages ? AppColors.infoColor : AppColors.mutedTextColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        tooltip: hasImages ? '預覽圖片' : '此規格沒有圖片',
        onPressed: hasImages ? () => _openVariantImagePreview(variant) : null,
        icon: const Icon(Icons.image_search_outlined, size: 19),
        color: Colors.white,
        disabledColor: AppColors.secondaryTextColor,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildVariantOptionRow(ProductVariant variant) {
    final isSelected = _selectedVariant?.id == variant.id;
    final stockText = '庫存 ${variant.availableStock}';
    final priceText = variant.price > 0
        ? variant.price.toDollarsString(prefix: "NT")
        : (_product?.price ?? 0).toDollarsString(prefix: "NT");

    return SelectionOptionTile(
      title: variant.displayName,
      primaryText: priceText,
      secondaryText: stockText,
      isSelected: isSelected,
      onTap: () => setState(() => _selectedVariant = variant),
      detailsSpacing: 8,
      trailing: _buildVariantPreviewButton(variant),
    );
  }

  Widget _buildVariantReadOnlyRow(ProductVariant variant) {
    final stockText = '庫存 ${variant.availableStock}';
    final priceText = variant.price > 0
        ? variant.price.toDollarsString(prefix: "NT")
        : (_product?.price ?? 0).toDollarsString(prefix: "NT");

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                priceText,
                style: const TextStyle(
                  color: AppColors.goldColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stockText,
                style: const TextStyle(
                  color: AppColors.secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          _buildVariantPreviewButton(variant),
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

  Widget _buildCategoryBlock() {
    final categories = _product?.categories ?? const <Category>[];
    if (categories.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Text(
            '分類',
            style: TextStyle(
              color: AppColors.primaryTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: categories
                .map(
                  (category) => _buildMetaLabel(
                    category.name,
                    backgroundColor: AppColors.primaryButtonColor,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMetaLabel(
    String text, {
    required Color backgroundColor,
    Color textColor = AppColors.primaryTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusStockChips() {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 6,
      children: [
        _buildMetaLabel(
          "狀態：${productStatusTranslation(_product!.status)}",
          backgroundColor: AppColors.secondaryButtonColor,
        ),
        _buildMetaLabel(
          "庫存：$_displayStock",
          backgroundColor: AppColors.goldColor,
          textColor: Colors.black,
        ),
      ],
    );
  }

  Widget _buildProductMetaRow() {
    final hasCategories = _product?.categories?.isNotEmpty == true;
    final chips = _buildStatusStockChips();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.containerBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!hasCategories) {
            return Align(alignment: Alignment.centerLeft, child: chips);
          }

          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryBlock(),
                const SizedBox(height: 12),
                chips,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(flex: 3, child: _buildCategoryBlock()),
              const SizedBox(width: 12),
              Flexible(
                flex: 2,
                child: Align(alignment: Alignment.topRight, child: chips),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collectionState = ref.watch(collectionNotifierProvider);
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
                      if (_product!.type == ProductType.refrigeration)
                        _buildTag("冷藏", Colors.blueAccent)
                      else if (_product!.type == ProductType.virtual)
                        _buildTag("免運", Colors.green),
                      if (_product!.allowHomeDelivery &&
                          _product!.type != ProductType.virtual)
                        _buildTag("宅配到府", Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _displayPrice.toDollarsString(prefix: "NT"),
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
                  _buildProductMetaRow(),
                  _buildMetadataTable(),
                  _buildVariantSection(),
                ],
              ),
            ),
            if (_showAddCartButton || _showCollectionButton)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    if (_showAddCartButton)
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
                    if (_showCollectionButton)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ElevatedButton(
                            onPressed:
                                _isCheckingCollection ||
                                    _isUpdatingCollection ||
                                    collectionState.isProcessing
                                ? null
                                : _collectionStatusError != null
                                ? _loadCollectionStatus
                                : _updateCollection,
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
                                  _isCollected == true
                                      ? Icons.bookmark_remove
                                      : Icons.bookmark_add,
                                ),
                                SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    _isCheckingCollection
                                        ? '讀取收藏狀態中…'
                                        : _collectionStatusError != null
                                        ? '重試讀取收藏狀態'
                                        : _isCollected == true
                                        ? '移除收藏'
                                        : '加入收藏',
                                  ),
                                ),
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
