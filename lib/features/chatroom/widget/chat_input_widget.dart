import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ad_ecommerce/constants/colors.dart';
import 'package:image_picker/image_picker.dart';

class ChatInputWidget extends StatefulWidget {
  const ChatInputWidget({
    super.key,
    required this.disabled,
    required this.onSubmit,
  });

  final bool disabled;

  /// text can be empty if [files] is not empty.
  final void Function(String text, List<XFile> files) onSubmit;

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  static const int _maxFileSizeBytes = 50 * 1024 * 1024; // 50 MB

  // Store file + a user-friendly label (source/type)
  final List<_PickedFile> _attachments = [];

  // Prevent concurrent picker calls (fixes iOS multiple_request)
  bool _isPicking = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<bool> _validateFileSize(XFile file, String label) async {
    final size = await file.length();
    if (size <= _maxFileSizeBytes) return true;

    if (!mounted) return false;

    final mb = (size / (1024 * 1024)).toStringAsFixed(1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 檔案過大（$mb MB），上限為 50 MB'),
        backgroundColor: Colors.redAccent,
      ),
    );
    return false;
  }

  bool get _canSend {
    if (widget.disabled) return false;
    final hasText = _textController.text.trim().isNotEmpty;
    final hasFiles = _attachments.isNotEmpty;
    return hasText || hasFiles;
  }

  Future<void> _showPickSheet() async {
    if (widget.disabled || _isPicking) return;

    final _PickAction? action = await showModalBottomSheet<_PickAction>(
      context: context,
      backgroundColor: AppColors.cardBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetTile(
                  icon: Icons.photo_library,
                  title: '選擇圖片（可多選）',
                  subtitle: '圖片（相簿）',
                  onTap: () => Navigator.of(ctx).pop(_PickAction.imagesMulti),
                ),
                _SheetTile(
                  icon: Icons.photo_camera,
                  title: '拍照',
                  subtitle: '圖片（相機）',
                  onTap: () => Navigator.of(ctx).pop(_PickAction.imageCamera),
                ),
                _SheetTile(
                  icon: Icons.video_library,
                  title: '選擇影片',
                  subtitle: '影片（相簿）',
                  onTap: () => Navigator.of(ctx).pop(_PickAction.videoGallery),
                ),
                _SheetTile(
                  icon: Icons.videocam,
                  title: '錄影',
                  subtitle: '影片（相機）',
                  onTap: () => Navigator.of(ctx).pop(_PickAction.videoCamera),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );

    if (action == null) return;

    // Let the bottom sheet fully close before starting the platform view (iOS).
    await Future<void>.delayed(const Duration(milliseconds: 250));

    await _performPick(action);
  }

  Future<void> _performPick(_PickAction action) async {
    if (_isPicking || widget.disabled) return;
    _isPicking = true;

    try {
      switch (action) {
        case _PickAction.imagesMulti:
          await _pickImages();
          break;
        case _PickAction.imageCamera:
          await _pickImageFromCamera();
          break;
        case _PickAction.videoGallery:
          await _pickVideoFromGallery();
          break;
        case _PickAction.videoCamera:
          await _pickVideoFromCamera();
          break;
      }
    } on PlatformException catch (e) {
      // Common iOS image_picker concurrency error if two requests overlap.
      if (e.code != 'multiple_request' && e.code != 'already_active') {
        rethrow;
      }
    } finally {
      _isPicking = false;
    }
  }

  Future<void> _pickImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isEmpty || !mounted) return;

    for (final img in images) {
      final ok = await _validateFileSize(img, '圖片');
      if (!ok) continue;

      setState(() {
        _attachments.add(_PickedFile(img, '圖片（相簿）'));
      });
    }
  }

  Future<void> _pickImageFromCamera() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image == null || !mounted) return;

    final ok = await _validateFileSize(image, '圖片');
    if (!ok) return;

    setState(() {
      _attachments.add(_PickedFile(image, '圖片（相機）'));
    });
  }

  Future<void> _pickVideoFromGallery() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video == null || !mounted) return;

    final ok = await _validateFileSize(video, '影片');
    if (!ok) return;

    setState(() {
      _attachments.add(_PickedFile(video, '影片（相簿）'));
    });
  }

  Future<void> _pickVideoFromCamera() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
    if (video == null || !mounted) return;

    final ok = await _validateFileSize(video, '影片');
    if (!ok) return;

    setState(() {
      _attachments.add(_PickedFile(video, '影片（相機）'));
    });
  }

  void _removeAttachmentAt(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  void _handleSend() {
    if (!_canSend) return;

    final text = _textController.text.trim();
    final files = List<XFile>.unmodifiable(_attachments.map((e) => e.file));

    widget.onSubmit(text, files);

    _textController.clear();
    setState(() {
      _attachments.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8, top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_attachments.isNotEmpty) ...[
            _AttachmentPreview(
              files: _attachments,
              onRemove: _removeAttachmentAt,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              IconButton(
                onPressed: widget.disabled ? null : _showPickSheet,
                icon: const Icon(Icons.attach_file),
                color: widget.disabled
                    ? AppColors.mutedTextColor
                    : AppColors.primaryTextColor,
                tooltip: '附加圖片/影片',
              ),
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: AppColors.primaryTextColor),
                  minLines: 1,
                  maxLines: 6,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '輸入訊息...',
                    hintStyle: const TextStyle(color: AppColors.mutedTextColor),
                    filled: true,
                    fillColor: AppColors.fieldInputColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: _canSend
                    ? AppColors.infoColor
                    : AppColors.mutedTextColor,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _canSend ? _handleSend : null,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.send, color: AppColors.primaryTextColor),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _PickAction { imagesMulti, imageCamera, videoGallery, videoCamera }

class _PickedFile {
  final XFile file;
  final String label; // e.g. 圖片（相簿）/圖片（相機）/影片（相簿）/影片（相機）

  const _PickedFile(this.file, this.label);
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryTextColor),
      title: Text(
        title,
        style: const TextStyle(color: AppColors.primaryTextColor),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(color: AppColors.mutedTextColor),
            ),
      onTap: onTap,
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.files, required this.onRemove});

  final List<_PickedFile> files;
  final void Function(int index) onRemove;

  bool _isVideo(_PickedFile f) => f.label.startsWith('影片');

  String _nameOf(XFile f) {
    // Avoid importing path package just for basename.
    final parts = f.path.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? f.path : parts.last;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(files.length, (i) {
          final picked = files[i];
          final isVideo = _isVideo(picked);

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.fieldInputColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVideo ? Icons.videocam : Icons.image,
                  size: 18,
                  color: AppColors.primaryTextColor,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    '${picked.label} · ${_nameOf(picked.file)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.primaryTextColor),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => onRemove(i),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColors.mutedTextColor,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
