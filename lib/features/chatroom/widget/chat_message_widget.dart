import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:flutter_ad_ecommerce/models/chatroom.dart';
import 'package:flutter_ad_ecommerce/router/routes.dart';
import 'package:flutter_ad_ecommerce/utils/file_utils.dart';
import 'package:flutter_ad_ecommerce/utils/formatter.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;
  const ChatMessageWidget({super.key, required this.message});

  List<ChatMessageAttachment> _getValidAttachments() {
    return message.attachments
            ?.where((a) => isAttachmentImage(a) || isAttachmentVideo(a))
            .toList() ??
        [];
  }

  List<ChatMessageAttachment> _getImageAttachments() {
    return message.attachments?.where((a) => isAttachmentImage(a)).toList() ??
        [];
  }

  Widget _buildAttachment(
    BuildContext context,
    ChatMessageAttachment attachment,
    double size,
  ) {
    final imageAttachments = _getImageAttachments();
    if (isAttachmentImage(attachment)) {
      return GestureDetector(
        onTap: () {
          context.push(
            Routes.photoView,
            extra: {
              "urlImages": imageAttachments.map((a) => a.url).toList(),
              "index": imageAttachments.indexWhere(
                (a) => a.id == attachment.id,
              ),
            },
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: size,
            height: size,
            child: CachedNetworkImage(
              imageUrl: attachment.url,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.error),
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    } else if (isAttachmentVideo(attachment)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: size,
          height: size,
          color: Colors.black,
          child: _VideoAttachment(url: attachment.url),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final validAttachments = _getValidAttachments();
    final hasContent = message.content.isNotEmpty;
    final hasAttachments = validAttachments.isNotEmpty;

    // Adjust size based on length of attachment
    final double attachmentSize = validAttachments.length > 1 ? 120.0 : 200.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Column(
        crossAxisAlignment: message.senderType != 'user'
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          Padding(
            padding: EdgeInsetsGeometry.symmetric(vertical: 4, horizontal: 4),
            child: Text(
              Formatter.formatDateTime(message.createdAt),
              style: TextStyle(color: AppColors.mutedTextColor, fontSize: 14),
            ),
          ),
          if (hasContent || (!hasContent && !hasAttachments))
            Container(
              margin: hasAttachments ? const EdgeInsets.only(bottom: 4) : null,
              padding: const EdgeInsets.all(12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              decoration: BoxDecoration(
                color:
                    (message.senderType == 'admin' ||
                        message.senderType == 'seller')
                    ? AppColors.mutedTextColor
                    : AppColors.infoColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                hasContent ? message.content : "無法顯示訊息",
                style: const TextStyle(color: AppColors.primaryTextColor),
              ),
            ),
          if (hasAttachments)
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              child: Wrap(
                spacing: 2,
                runSpacing: 2,
                children: validAttachments
                    .map((a) => _buildAttachment(context, a, attachmentSize))
                    .toList(),
              ),
            ),
          if (message.senderType != "admin" &&
              message.senderType != "seller" &&
              (message.id == "pending" || message.isRead))
            Padding(
              padding: EdgeInsetsGeometry.only(top: 4, right: 8),
              child: Text(
                message.id == "pending" ? "發送中" : "已讀",
                style: TextStyle(color: AppColors.mutedTextColor, fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoAttachment extends StatefulWidget {
  final String url;
  const _VideoAttachment({required this.url});

  @override
  State<_VideoAttachment> createState() => _VideoAttachmentState();
}

class _VideoAttachmentState extends State<_VideoAttachment>
    with AutomaticKeepAliveClientMixin {
  late VideoPlayerController _videoPlayerController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
    );
    await _videoPlayerController.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_videoPlayerController.value.isInitialized) {
      return GestureDetector(
        onTap: () {
          context.push(Routes.fullScreenVideoPlayerPage, extra: widget.url);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoPlayerController.value.size.width,
                height: _videoPlayerController.value.size.height,
                child: VideoPlayer(_videoPlayerController),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 50,
              ),
            ),
          ],
        ),
      );
    } else {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      );
    }
  }
}
