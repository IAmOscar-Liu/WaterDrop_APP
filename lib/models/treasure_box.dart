import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:uuid/uuid.dart';

class TreasureBox {
  final String id;
  final String userId;
  final DateTime? earnedAt;
  final DateTime? openedAt;
  final double? coinsAwarded;
  final bool isOpened;
  final bool isClaimable;

  TreasureBox({
    required this.id,
    required this.userId,
    this.earnedAt,
    this.openedAt,
    this.coinsAwarded,
    this.isOpened = false,
    this.isClaimable = true,
  });

  factory TreasureBox.zero() {
    final uuid = Uuid();
    return TreasureBox(id: uuid.v4(), userId: "", isClaimable: false);
  }

  // Simple factory for demonstration, could be from JSON in a real app
  factory TreasureBox.fromMap(Map<String, dynamic> map) {
    return TreasureBox(
      id: ParseUtils.parseString(map['id']) ?? "",
      userId: ParseUtils.parseString(map['userId']) ?? "",
      earnedAt: ParseUtils.parseDateTime(map['earnedAt']),
      openedAt: ParseUtils.parseDateTime(map['openedAt']),
      coinsAwarded: ParseUtils.parseDouble(map['coinsAwarded']),
      isOpened: map['isOpened'] == true,
    );
  }

  // A helper method to create a new TreasureBox with updated properties
  TreasureBox copyWith({
    String? id,
    String? userId,
    DateTime? earnedAt,
    DateTime? openedAt,
    double? coinsAwarded,
    bool? isOpened,
    bool? isClaimable,
  }) {
    return TreasureBox(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      earnedAt: earnedAt ?? this.earnedAt,
      openedAt: openedAt ?? this.openedAt,
      coinsAwarded: coinsAwarded ?? this.coinsAwarded,
      isOpened: isOpened ?? this.isOpened,
      isClaimable: isClaimable ?? this.isClaimable,
    );
  }
}
