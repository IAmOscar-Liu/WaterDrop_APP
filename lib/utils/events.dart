import 'package:event_bus/event_bus.dart';

EventBus eventBus = EventBus();

class RouterChangeEvent {
  String from;
  String to;

  RouterChangeEvent({required this.from, required this.to});
}

class TokenChangeEvent {
  String? token;

  TokenChangeEvent({required this.token});
}

class NotificationTappedEvent {
  String? title;
  String? body;
  Map<String, dynamic>? data;

  NotificationTappedEvent({this.title, this.body, this.data});
}
