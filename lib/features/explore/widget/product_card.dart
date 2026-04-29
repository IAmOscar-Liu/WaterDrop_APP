import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/models/product.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/number_formatter_extension.dart';
import 'package:flutter_ad_ecommerce/widgets/initial_image.dart';
import 'package:go_router/go_router.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onCollectionRemoved,
  });

  final Product product;
  final Function()? onCollectionRemoved;

  @override
  Widget build(BuildContext context) {
    // A little variety in heights so the masonry layout looks natural.
    final int hash = product.name.hashCode;
    final double dynamicHeight = 140 + (hash % 120); // 140–259

    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              context
                  .push(
                    Routes.singleProductDetails,
                    extra: {
                      "product": product,
                      "removeFromCollection": onCollectionRemoved != null,
                    },
                  )
                  .then((value) {
                    if (onCollectionRemoved != null &&
                        value is Map &&
                        value['reload'] == true) {
                      onCollectionRemoved!();
                    }
                  });
            },
            child: (product.images != null && product.images!.isNotEmpty)
                ? FadeInImage.assetNetwork(
                    // placeholder: "assets/images/photo_not_found.jpg",
                    placeholder: "assets/images/photo_loading.gif",
                    image: product.images![0],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    imageErrorBuilder: (context, error, stackTrace) {
                      // This builder is used if the network image fails to load.
                      return Image.asset(
                        "assets/images/photo_not_found.jpg",
                        width: double.infinity,
                        fit: BoxFit.cover,
                      );
                    },
                  )
                : SizedBox(
                    width: double.infinity,
                    height: dynamicHeight.toDouble(),
                    child: InitialImage(name: product.name),
                  ),
          ),

          // Text section: name, description, price
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  product.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                // Description
                Text(
                  product.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.75),
                  ),
                ),
                const SizedBox(height: 10),
                // Price
                Row(
                  children: [
                    Text(
                      product.price.toDollarsString(prefix: "NT"),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
