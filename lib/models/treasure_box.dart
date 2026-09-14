import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:uuid/uuid.dart';

enum TreasureBoxAccountingStatus {
  claimable,
  acquired,
  unacquired,
  zeroReward;

  static TreasureBoxAccountingStatus? fromWire(String? value) {
    return switch (value) {
      'claimable' => claimable,
      'acquired' => acquired,
      'unacquired' => unacquired,
      'zero_reward' => zeroReward,
      _ => null,
    };
  }
}

class TreasureBox {
  final String id;
  final String userId;
  final DateTime? earnedAt;
  final DateTime? openedAt;
  final double? coinsAwarded;
  final bool isOpened;
  final bool isClaimable;
  final bool? isActive;
  final TreasureBoxAccountingStatus? accountingStatus;
  final DateTime? claimDeadlineAt;
  final DateTime? localClaimDeadlineAt;
  final DateTime? archiveGraceDeadlineAt;
  final DateTime? acquiredAt;

  TreasureBox({
    required this.id,
    required this.userId,
    this.earnedAt,
    this.openedAt,
    this.coinsAwarded,
    this.isOpened = false,
    this.isClaimable = true,
    this.isActive,
    this.accountingStatus,
    this.claimDeadlineAt,
    this.localClaimDeadlineAt,
    this.archiveGraceDeadlineAt,
    this.acquiredAt,
  });

  factory TreasureBox.zero() {
    final uuid = Uuid();
    return TreasureBox(id: uuid.v4(), userId: "", isClaimable: false);
  }

  // Simple factory for demonstration, could be from JSON in a real app
  factory TreasureBox.fromMap(Map<String, dynamic> map) {
    final accountingStatus = TreasureBoxAccountingStatus.fromWire(
      ParseUtils.parseString(map['accountingStatus']),
    );
    final isActive = map['isActive'] is bool ? map['isActive'] == true : null;
    final isClaimable =
        (map['isClaimable'] is bool
            ? map['isClaimable'] == true
            : accountingStatus == null ||
                  accountingStatus == TreasureBoxAccountingStatus.claimable ||
                  accountingStatus == TreasureBoxAccountingStatus.zeroReward) &&
        isActive != false;

    return TreasureBox(
      id: ParseUtils.parseString(map['id']) ?? "",
      userId: ParseUtils.parseString(map['userId']) ?? "",
      earnedAt: ParseUtils.parseDateTime(map['earnedAt']),
      openedAt: ParseUtils.parseDateTime(map['openedAt']),
      coinsAwarded: ParseUtils.parseDouble(map['coinsAwarded']),
      isOpened: map['isOpened'] == true,
      isClaimable: isClaimable,
      isActive: isActive,
      accountingStatus: accountingStatus,
      claimDeadlineAt: ParseUtils.parseDateTime(map['claimDeadlineAt']),
      localClaimDeadlineAt: ParseUtils.parseDateTime(
        map['localClaimDeadlineAt'],
      ),
      archiveGraceDeadlineAt: ParseUtils.parseDateTime(
        map['archiveGraceDeadlineAt'],
      ),
      acquiredAt: ParseUtils.parseDateTime(map['acquiredAt']),
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
    bool? isActive,
    TreasureBoxAccountingStatus? accountingStatus,
    DateTime? claimDeadlineAt,
    DateTime? localClaimDeadlineAt,
    DateTime? archiveGraceDeadlineAt,
    DateTime? acquiredAt,
  }) {
    return TreasureBox(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      earnedAt: earnedAt ?? this.earnedAt,
      openedAt: openedAt ?? this.openedAt,
      coinsAwarded: coinsAwarded ?? this.coinsAwarded,
      isOpened: isOpened ?? this.isOpened,
      isClaimable: isClaimable ?? this.isClaimable,
      isActive: isActive ?? this.isActive,
      accountingStatus: accountingStatus ?? this.accountingStatus,
      claimDeadlineAt: claimDeadlineAt ?? this.claimDeadlineAt,
      localClaimDeadlineAt: localClaimDeadlineAt ?? this.localClaimDeadlineAt,
      archiveGraceDeadlineAt:
          archiveGraceDeadlineAt ?? this.archiveGraceDeadlineAt,
      acquiredAt: acquiredAt ?? this.acquiredAt,
    );
  }
}
