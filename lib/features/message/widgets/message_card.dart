import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/models/message.dart';
import 'package:flutter_ad_ecommerce/pages/message_page.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart';

class MessageCard extends StatelessWidget {
  final Message message;
  final void Function()? onTap;

  const MessageCard({super.key, required this.message, required this.onTap});

  String _getTypeLabel(String? type) {
    if (type == null) return '其他';
    try {
      return MessageType.values.firstWhere((e) => e.name == type).label;
    } catch (_) {
      return '其他';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: message.isRead
            ? const Color(0xFF1E2127)
            : const Color(0xFF2B303A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF393E46), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (onTap != null) {
              onTap!();
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        message.title,
                        style: TextStyle(
                          color: message.isRead ? Colors.white70 : Colors.white,
                          fontSize: 16,
                          fontWeight: message.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getTypeLabel(message.type),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.body,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      Formatter.formatDateTime(message.createdAt),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
