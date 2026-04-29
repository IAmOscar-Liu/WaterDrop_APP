import 'dart:convert';

import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';
import 'package:uuid/uuid.dart';

/// A class to hold user account information.
class AccountInfo {
  final String id;
  final String email;
  final String oauthProvider;
  final String oauthId;
  final String? groupId;
  final String level;
  final double coins;
  final double? coinsExpireSoon;
  final double discountRate;
  final String referralCode;
  final int referralCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String name;
  final String? phone;
  final String? address;
  final String? timezone;
  final DateTime? termsAcceptedAt;

  /// Constructs an [AccountInfo] instance.
  const AccountInfo({
    required this.id,
    required this.email,
    required this.oauthProvider,
    required this.oauthId,
    this.groupId,
    required this.level,
    required this.coins,
    this.coinsExpireSoon,
    required this.discountRate,
    required this.referralCode,
    required this.referralCount,
    this.createdAt,
    this.updatedAt,
    required this.name,
    this.phone,
    this.address,
    this.timezone,
    this.termsAcceptedAt,
  });

  /// Creates a new [AccountInfo] instance with updated values.
  ///
  /// This method allows you to create a copy of the current object
  /// while modifying specific fields.
  AccountInfo copyWith({
    String? id,
    String? email,
    String? oauthProvider,
    String? oauthId,
    String? groupId,
    String? level,
    double? coins,
    double? coinsExpireSoon,
    double? discountRate,
    String? referralCode,
    int? referralCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    String? name,
    String? phone,
    String? address,
    String? timezone,
    DateTime? termsAcceptedAt,
  }) {
    return AccountInfo(
      id: id ?? this.id,
      email: email ?? this.email,
      oauthProvider: oauthProvider ?? this.oauthProvider,
      oauthId: oauthId ?? this.oauthId,
      groupId: groupId ?? this.groupId,
      level: level ?? this.level,
      coins: coins ?? this.coins,
      coinsExpireSoon: coinsExpireSoon ?? this.coinsExpireSoon,
      discountRate: discountRate ?? this.discountRate,
      referralCode: referralCode ?? this.referralCode,
      referralCount: referralCount ?? this.referralCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      timezone: timezone ?? this.timezone,
      termsAcceptedAt: termsAcceptedAt ?? this.termsAcceptedAt,
    );
  }

  factory AccountInfo.zero() {
    final uuid = Uuid();
    return AccountInfo(
      id: uuid.v4(),
      email: "",
      oauthProvider: "google",
      oauthId: "",
      level: "A0",
      coins: 0,
      discountRate: 0.2,
      referralCode: "",
      referralCount: 0,
      name: "",
    );
  }

  factory AccountInfo.fromApiResponseMap(Map<String, dynamic> map) {
    return AccountInfo(
      id: ParseUtils.parseString(map['id']) ?? "",
      email: ParseUtils.parseString(map['email']) ?? "",
      oauthProvider: ParseUtils.parseString(map['oauthProvider']) ?? "",
      oauthId: ParseUtils.parseString(map['oauthId']) ?? "",
      groupId: ParseUtils.parseString(map['groupId']),
      level: ParseUtils.parseString(map['level']) ?? "",
      coins: ParseUtils.parseDouble(map['coins']) ?? 0,
      coinsExpireSoon: ParseUtils.parseDouble(map['coinsExpireSoon']),
      discountRate: ParseUtils.parseDouble(map['discountRate']) ?? 0.2,
      referralCode: ParseUtils.parseString(map['referralCode']) ?? "",
      referralCount: ParseUtils.parseInt(map['referralCount']) ?? 0,
      createdAt: ParseUtils.parseDateTime(map['createdAt']),
      updatedAt: ParseUtils.parseDateTime(map['updatedAt']),
      name: ParseUtils.parseString(map['name']) ?? "",
      phone: ParseUtils.parseString(map['phone']),
      address: ParseUtils.parseString(map['address']),
      timezone: ParseUtils.parseString(map['timezone']),
      termsAcceptedAt: ParseUtils.parseDateTime(map['termsAcceptedAt']),
    );
  }

  /// Converts the [AccountInfo] instance to a JSON map.
  ///
  /// This method converts DateTime objects back to Unix timestamps (in seconds).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'oauth_provider': oauthProvider,
      'level': level,
      'coins': coins,
      'coinsExpireSoon': coinsExpireSoon,
      'referral_code': referralCode,
      'referral_count': referralCount,
      'created_at': createdAt == null
          ? null
          : createdAt!.millisecondsSinceEpoch ~/ 1000,
      'updated_at': updatedAt == null
          ? null
          : updatedAt!.millisecondsSinceEpoch ~/ 1000,
      'name': name,
      'phone': phone,
      'address': address,
      'timezone': timezone,
    };
  }

  /// A utility method to convert the object to a formatted JSON string.
  @override
  String toString() {
    return json.encode(toJson());
  }
}
