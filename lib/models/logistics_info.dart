import 'package:flutter_ad_ecommerce/utils/parse_utils.dart';

class LogisticsMapInfo {
  final String MerchantID;
  final String? MerchantTradeNo;
  final String LogisticsSubType;
  final String CVSStoreID;
  final String CVSStoreName;
  final String CVSAddress;
  final String? CVSTelephone;
  final int? CVSOutSide;
  final dynamic ExtraData;

  const LogisticsMapInfo({
    required this.MerchantID,
    this.MerchantTradeNo,
    required this.LogisticsSubType,
    required this.CVSStoreID,
    required this.CVSStoreName,
    required this.CVSAddress,
    this.CVSTelephone,
    this.CVSOutSide,
    this.ExtraData,
  });

  factory LogisticsMapInfo.fromApiResponseMap(Map<String, dynamic> map) {
    return LogisticsMapInfo(
      MerchantID: ParseUtils.parseString(map['MerchantID']) ?? "",
      MerchantTradeNo: ParseUtils.parseString(map['MerchantTradeNo']),
      LogisticsSubType: ParseUtils.parseString(map['LogisticsSubType']) ?? "",
      CVSStoreID: ParseUtils.parseString(map['CVSStoreID']) ?? "",
      CVSStoreName: ParseUtils.parseString(map['CVSStoreName']) ?? "",
      CVSAddress: ParseUtils.parseString(map['CVSAddress']) ?? "",
      CVSTelephone: ParseUtils.parseString(map['CVSTelephone']),
      CVSOutSide: ParseUtils.parseInt(map['CVSOutSide']) ?? 0,
      ExtraData: map['ExtraData'],
    );
  }
}
