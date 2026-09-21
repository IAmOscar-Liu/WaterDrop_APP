import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/features/explore/widget/product_card.dart';
import 'package:flutter_ad_ecommerce/models/collection.dart';
import 'package:flutter_ad_ecommerce/provider/collection_provider.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/shared/layouts/app_scaffold.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/messaging_app_bar.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/page_status.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/search_filter_button.dart';
import 'package:flutter_masonry_view/flutter_masonry_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

class CollectionPage extends ConsumerStatefulWidget {
  const CollectionPage({super.key});

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage> {
  String _textSearch = '';

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  void _loadCollections() {
    Future.delayed(Duration.zero, () {
      ref
          .read(collectionNotifierProvider.notifier)
          .loadCollections(search: _textSearch.isEmpty ? null : _textSearch);
    });
  }

  Widget _buildLayout({required Widget child}) {
    return AppScaffold(
      appBar: MessagingAppBar(title: '我的收藏'),
      useSafeArea: true,
      body: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final collectionProvider = ref.watch(collectionNotifierProvider);
    if (collectionProvider.isInitial || collectionProvider.isLoading) {
      return _buildLayout(child: PageLoading('載入收藏中......'));
    }

    final List<Collection> collections =
        collectionProvider.data?.collections ?? [];

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
              child: Builder(
                builder: (context) {
                  void onSelectTextSearch(String textSearch) {
                    context
                        .push(
                          Routes.textSearch,
                          extra: {
                            'textSearch': textSearch,
                            'source': 'collection',
                          },
                        )
                        .then((value) {
                          if (value is String) {
                            setState(() {
                              _textSearch = value;
                            });
                            _loadCollections();
                          }
                        });
                  }

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SearchFilterButton(
                        query: _textSearch,
                        onSelect: onSelectTextSearch,
                      ),
                      const SizedBox(width: 8),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: collectionProvider.hasError
                  ? PageError(
                      "Failed to load collections: ${collectionProvider.error}",
                    )
                  : collectionProvider.data!.collections.isEmpty
                  ? Center(
                      child: Builder(
                        builder: (context) {
                          if (_textSearch.isEmpty) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.bookmark_remove,
                                  size: 80,
                                  color: AppColors.mutedTextColor,
                                ),
                                SizedBox(height: 24),
                                Text(
                                  '收藏是空的',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryTextColor,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  '快去逛逛，把喜歡的商品加入收藏吧！',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.secondaryTextColor,
                                  ),
                                ),
                              ],
                            );
                          }
                          return EmptyState("很抱歉，找不到您想要的相關商品");
                        },
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.only(left: 8, right: 8, bottom: 16),
                      child: Column(
                        children: [
                          MasonryView(
                            listOfItem: collections,
                            itemPadding: 2,
                            numberOfColumn: 2,
                            itemBuilder: (item) {
                              final Collection collection = item;
                              if (collection.id == collections.last.id) {
                                return VisibilityDetector(
                                  key: Key(collection.id),
                                  onVisibilityChanged: (visibilityInfo) {
                                    if (visibilityInfo.visibleFraction > 0.2) {
                                      ref
                                          .read(
                                            collectionNotifierProvider.notifier,
                                          )
                                          .fetchMoreCollections();
                                    }
                                  },
                                  child: ProductCard(
                                    product: collection.product,
                                    onCollectionRemoved: _loadCollections,
                                  ),
                                );
                              }
                              return ProductCard(
                                product: collection.product,
                                onCollectionRemoved: _loadCollections,
                              );
                            },
                          ),
                          if (collectionProvider.isFetching)
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
