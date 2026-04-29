// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class PhotoViewPage extends StatefulWidget {
  PhotoViewPage({super.key, required this.urlImages, this.index = 0})
    : pageController = PageController(initialPage: index ?? 0);

  final List<String> urlImages;
  final int? index;
  final PageController pageController;

  @override
  State<PhotoViewPage> createState() => _PhotoViewPageState();
}

class _PhotoViewPageState extends State<PhotoViewPage> {
  late int _index = widget.index ?? 0;

  @override
  Widget build(BuildContext context) {
    final safeAreaPadding = MediaQuery.of(context).padding;

    return Scaffold(
      body: Stack(
        children: [
          Container(color: Colors.black),
          PhotoViewGallery.builder(
            pageController: widget.pageController,
            itemCount: widget.urlImages.length,
            onPageChanged: (index) => setState(() {
              _index = index;
            }),
            builder: (context, index) {
              final urlImage = widget.urlImages[index];

              return PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(urlImage),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.contained * 4,
                errorBuilder: (context, error, stackTrace) {
                  return Image.asset("assets/images/photo_not_found.jpg");
                },
              );
            },
          ),
          Positioned(
            top: safeAreaPadding.top + (Platform.isAndroid ? 16 : 4),
            left: 12,
            child: InkWell(
              onTap: () => context.pop(),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      "回上頁",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Positioned(
          //   bottom: safeAreaPadding.bottom + 48,
          //   left: 0,
          //   right: 0,
          //   child: SizedBox(
          //     width: 200,
          //     child: Text(
          //       'Image ${_index + 1}/${widget.urlImages.length}',
          //       style: TextStyle(color: Colors.white, fontSize: 18),
          //       textAlign: TextAlign.center,
          //     ),
          //   ),
          // ),
          if (widget.urlImages.length > 1)
            Positioned(
              bottom: safeAreaPadding.bottom + 48,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.urlImages.length,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Container(
                      width: 8.0,
                      height: 8.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _index == index
                            ? Colors.white
                            : AppColors.mutedTextColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
