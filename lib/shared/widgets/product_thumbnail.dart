import 'package:flutter_ad_ecommerce/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/initial_image.dart';

/// Small product image with the common loading, error, and no-image fallbacks.
/// Callers choose the variant/product URL and supply any badges or tap action.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 60,
  });

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
      child: imageUrl != null
          ? AppNetworkImage(imageUrl: imageUrl!)
          : InitialImage(name: name),
    );
  }
}
