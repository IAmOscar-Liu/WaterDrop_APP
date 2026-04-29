import 'package:flutter_ad_ecommerce/models/advertisement.dart';

enum DemoStatus { initial, loading, fetching, processing, done, error }

class Demo {
  final DemoStatus status;
  final List<Advertisement>? items;

  Demo({this.status = DemoStatus.initial, this.items});

  Demo copyWith({DemoStatus? status, List<Advertisement>? items}) {
    return Demo(status: status ?? this.status, items: items ?? this.items);
  }
}
