import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/shared/widgets/swipe_action_pane.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';

/// Left swipes reveal explicit actions; swiping alone never mutates a message.
class MessageSwipeActions extends StatelessWidget {
  const MessageSwipeActions({
    super.key,
    required this.open,
    required this.enabled,
    required this.isRead,
    required this.onOpenChanged,
    required this.onDelete,
    required this.onMarkRead,
    required this.child,
  });

  final bool open;
  final bool enabled;
  final bool isRead;
  final ValueChanged<bool> onOpenChanged;
  final VoidCallback onDelete;
  final VoidCallback onMarkRead;
  final Widget child;

  @override
  Widget build(BuildContext context) => SwipeActionPane(
    open: open,
    enabled: enabled,
    width: isRead ? 88 : 176,
    onOpenChanged: onOpenChanged,
    actions: [
      if (!isRead)
        _action(
          icon: Icons.mark_email_read_outlined,
          label: '標為已讀',
          color: AppColors.infoColor,
          onPressed: enabled ? onMarkRead : null,
        ),
      _action(
        icon: Icons.delete_outline,
        label: '刪除',
        color: AppColors.dangerButtonColor,
        onPressed: enabled ? onDelete : null,
      ),
    ],
    child: child,
  );

  Widget _action({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) => Expanded(
    child: Tooltip(
      message: label,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: AppColors.mutedTextColor,
          backgroundColor: AppColors.tileColor,
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(icon), const SizedBox(height: 4), Text(label)],
        ),
      ),
    ),
  );
}
