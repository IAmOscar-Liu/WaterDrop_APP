import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Use the same URL/cache identity for thumbnails and full-size images.
/// Freshness and revalidation follow the image server's HTTP cache headers.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) => CachedNetworkImage(
    imageUrl: imageUrl,
    width: width,
    height: height,
    fit: fit,
    fadeInDuration: Duration.zero,
    fadeOutDuration: Duration.zero,
    placeholder: (context, url) => Image.asset(
      'assets/images/photo_loading.gif',
      width: width,
      height: height,
      fit: fit,
    ),
    errorWidget: (context, url, error) =>
        errorWidget ??
        Image.asset(
          'assets/images/photo_not_found.jpg',
          width: width,
          height: height,
          fit: fit,
        ),
  );
}
