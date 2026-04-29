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
  bool _isLoading = true;
  dynamic _error;

  @override
  void initState() {
    super.initState();
    if (widget.extra is Map && widget.extra['product'] != null) {
      setState(() {
        _isLoading = false;
        _product = widget.extra['product'];
      });
    } else if (widget.extra is Map && widget.extra['productId'] is String) {
      Future.delayed(Duration.zero, () {
        _loadSingleProduct(widget.extra['productId']).then((value) {
          if (value.isSuccess) {
            setState(() {
              _isLoading = false;
              _product = value.data!;
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
                            color: Colors.black.withOpacity(0.5),
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
                    runSpacing: 8,
                    children: [
                      Chip(
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
                        label: Text(
                          "狀態：${_product!.status.isEmpty ? "N/A" : productStatusTranslation(_product!.status)}",
                        ),
                        backgroundColor: AppColors.secondaryButtonColor,
                      ),
                      Chip(
                        label: Text(
                          "庫存：${_product!.stock - _product!.reserve}",
                        ),
                        backgroundColor: AppColors.dangerButtonColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.extra['hideAddCartItemButton'] != true ||
                widget.extra['hideAddCollectionButton'] != true)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    if (widget.extra['hideAddCartItemButton'] != true)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ElevatedButton(
                            onPressed: ref.watch(cartProvider).isProcessing
                                ? null
                                : () {
                                    ref
                                        .read(cartProvider.notifier)
                                        .addCartItem(
                                          _product!.id,
                                          productName: _product!.name,
                                        )
                                        .then((result) {
                                          if (!mounted) return;
                                          final message = result.isSuccess
                                              ? result.data
                                              : result.error;
                                          if (message == null) return;
                                          ScaffoldMessenger.of(
                                            // ignore: use_build_context_synchronously
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(message),
                                              backgroundColor: Colors.green,
                                              duration: const Duration(
                                                seconds: 2,
                                              ),
                                            ),
                                          );
                                        });
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
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
                                Icon(Icons.shopping_cart),
                                SizedBox(width: 12),
                                Text("加入購物車"),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (widget.extra['hideAddCollectionButton'] != true)
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
                                      isRemoval:
                                          widget
                                              .extra['removeFromCollection'] ==
                                          true,
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
                                  widget.extra['removeFromCollection'] == true
                                      ? Icons.bookmark_remove
                                      : Icons.bookmark_add,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  widget.extra['removeFromCollection'] == true
                                      ? "移除收藏"
                                      : "加入收藏",
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
