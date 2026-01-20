import 'dart:typed_data';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// A full-screen image viewer with zoom and save functionality.
class FullScreenImageViewer extends StatefulWidget {
  const FullScreenImageViewer({
    super.key,
    this.imageUrl,
    this.imageBytes,
  });

  final String? imageUrl;
  final Uint8List? imageBytes;

  static void show(BuildContext context,
      {String? imageUrl, Uint8List? imageBytes}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FullScreenImageViewer(
            imageUrl: imageUrl,
            imageBytes: imageBytes,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  final TransformationController _transformationController =
      TransformationController();
  bool _isSaving = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _saveImage() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      Uint8List? bytes = widget.imageBytes;

      // Download from URL if needed
      if (bytes == null && widget.imageUrl != null) {
        final response = await http.get(Uri.parse(widget.imageUrl!));
        if (response.statusCode == 200) {
          bytes = response.bodyBytes;
        } else {
          throw Exception('Failed to download image');
        }
      }

      if (bytes == null) {
        throw Exception('No image data available');
      }

      // Save to temporary file first, then to gallery
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/VibSNS_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);

      // Save to gallery using Gal with album name for Google Photos visibility
      await Gal.putImage(tempFile.path, album: 'VibSNS');

      // Clean up temp file
      await tempFile.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)?.imageSaved ?? '画像を保存しました'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.imageSaveFailed ??
                '画像の保存に失敗しました'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Dismiss on tap background
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.transparent),
          ),
          // Zoomable image
          Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              child: _buildImage(),
            ),
          ),
          // Top bar with close and save buttons
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close button
                _buildIconButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                // Save button
                _buildIconButton(
                  icon: _isSaving
                      ? Icons.hourglass_empty
                      : Icons.download_rounded,
                  onTap: _isSaving ? null : _saveImage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (widget.imageBytes != null) {
      return Image.memory(
        widget.imageBytes!,
        fit: BoxFit.contain,
      );
    }
    if (widget.imageUrl != null) {
      return Image.network(
        widget.imageUrl!,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: 200,
            height: 200,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 200,
            height: 200,
            color: Colors.grey[800],
            child:
                const Icon(Icons.broken_image, color: Colors.white, size: 48),
          );
        },
      );
    }
    return const SizedBox.shrink();
  }
}
