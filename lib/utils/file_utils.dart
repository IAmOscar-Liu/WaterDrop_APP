import 'package:flutter_ad_ecommerce/models/chatroom.dart';
import 'package:image_picker/image_picker.dart';

bool isAttachmentImage(ChatMessageAttachment attachment) {
  if (attachment.mimeType == null) return false;
  if (attachment.mimeType!.toLowerCase().startsWith('image/')) return true;

  final url = attachment.url.toLowerCase();

  return url.endsWith('.jpg') ||
      url.endsWith('.jpeg') ||
      url.endsWith('.png') ||
      url.endsWith('.heic');
}

bool isAttachmentVideo(ChatMessageAttachment attachment) {
  if (attachment.mimeType == null) return false;
  if (attachment.mimeType!.toLowerCase().startsWith('video/')) return true;

  final url = attachment.url.toLowerCase();

  return url.endsWith('.mp4') || url.endsWith('.mov');
}

bool isXFileImage(XFile file) {
  final mimeType = file.mimeType ?? '';
  final lowerPath = file.path.toLowerCase();

  return mimeType.startsWith('image/') ||
      lowerPath.endsWith('.jpg') ||
      lowerPath.endsWith('.jpeg') ||
      lowerPath.endsWith('.png') ||
      lowerPath.endsWith('.heic');
}

bool isXFileVideo(XFile file) {
  final mimeType = file.mimeType ?? '';
  final lowerPath = file.path.toLowerCase();

  return mimeType.startsWith('video/') ||
      lowerPath.endsWith('.mp4') ||
      lowerPath.endsWith('.mov');
}

String? getXFileMimeType(XFile file) {
  if (file.mimeType != null) {
    return file.mimeType!;
  }
  if (isXFileImage(file)) {
    return getMimeTypeFromImagePath(file.path);
  } else if (isXFileVideo(file)) {
    return getMimeTypeFromVideoPath(file.path);
  } else {
    return null;
  }
}

String getMimeTypeFromImagePath(String path) {
  String lowerPath = path.toLowerCase();
  String ext = lowerPath.split(".").last;
  return "image/$ext";
}

String getMimeTypeFromVideoPath(String path) {
  String lowerPath = path.toLowerCase();
  String ext = lowerPath.split(".").last;

  if (ext == "mov") {
    ext = "quicktime";
  }

  return "video/$ext";
}
