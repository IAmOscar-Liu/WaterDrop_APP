import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';

class Advertisement {
  final String id;
  final String title;
  final String? description; // Made optional
  final String videoUrl;
  final String? fallbackVideoUrl;
  final String productId;
  final String productName;
  final double price;

  final String? avatarUrl;
  final Map<String, dynamic>? metadata; // New optional property for metadata
  final bool isCompleted;
  final Duration? duration;
  final bool? isLandscape;

  Advertisement({
    required this.id,
    required this.title,
    this.description,
    required this.videoUrl,
    this.fallbackVideoUrl,
    required this.productId,
    required this.productName,
    required this.price,

    this.avatarUrl,
    this.metadata, // New optional parameter
    this.isCompleted = false,
    this.duration,
    this.isLandscape,
  });

  // Simple factory for demonstration, could be from JSON in a real app
  factory Advertisement.fromApiResponse(
    Map<String, dynamic> map, {
    required int index,
  }) {
    index = index % 20;
    return Advertisement(
      id: ParseUtils.parseString(map['id']) ?? "",
      title: ParseUtils.parseString(map['title']) ?? "",
      description: ParseUtils.parseString(map['description']),
      videoUrl: ParseUtils.parseString(map['video_url']) ?? "",
      // videoUrl:
      //     "https://pub-c796d4f72aca45d68562ea9d55d46e5e.r2.dev/videos/8b31c0e6-86e0-4e3d-98fa-7412e6e29c2c.mp4",
      fallbackVideoUrl: 'assets/videos/istockphoto-1013711730-640_adpp_is.mp4',
      productId: ParseUtils.parseString(map['productId']) ?? "",
      productName: ParseUtils.parseString(map['product']?['name']) ?? "",
      price: ParseUtils.parseDouble(map['product']?['price']) ?? 0,
      avatarUrl: ParseUtils.parseString(map['product']?['avatar']),
      metadata: map['metadata'] is Map
          ? map['metadata']
          : null, // Handle nullable metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'productId': productId,
      'productName': productName,
      'price': price,
      'avatarUrl': avatarUrl,
      'isCompleted': isCompleted,
      'durationSeconds': duration?.inSeconds,
      'isLandscape': isLandscape == true,
      'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Advertisement &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  // A helper method to create a new Advertisement with updated properties
  Advertisement copyWith({
    String? id,
    String? title,
    String? description, // Made optional
    String? videoUrl,
    String? fallbackVideoUrl,
    String? productId,
    String? productName,
    double? price,
    String? avatarUrl,
    Map<String, dynamic>? metadata, // New optional property for metadata
    bool? isCompleted,
    Duration? duration,
    bool? isLandscape,
  }) {
    return Advertisement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      fallbackVideoUrl: fallbackVideoUrl ?? this.fallbackVideoUrl,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      metadata: metadata ?? this.metadata,
      isCompleted: isCompleted ?? this.isCompleted,
      duration: duration ?? this.duration,
      isLandscape: isLandscape ?? this.isLandscape,
    );
  }
}
