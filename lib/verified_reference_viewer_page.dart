import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VerifiedReferenceViewerPage extends StatefulWidget {
  const VerifiedReferenceViewerPage({
    super.key,
    required this.file,
    required this.title,
    this.deleteOnDispose = true,
  });

  final File file;
  final String title;
  final bool deleteOnDispose;

  @override
  State<VerifiedReferenceViewerPage> createState() =>
      _VerifiedReferenceViewerPageState();
}

class _VerifiedReferenceViewerPageState
    extends State<VerifiedReferenceViewerPage> {
  VideoPlayerController? _controller;
  Object? _error;
  bool _loading = true;

  bool get _isVideo {
    final lower = widget.file.path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v');
  }

  bool get _isPhoto {
    final lower = widget.file.path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_initialize);
  }

  Future<void> _initialize() async {
    try {
      if (!await widget.file.exists() || (!_isVideo && !_isPhoto)) {
        throw StateError('REFERENCE_MEDIA_UNAVAILABLE');
      }
      if (_isVideo) {
        final controller = VideoPlayerController.file(widget.file);
        await controller.initialize();
        await controller.setLooping(false);
        controller.addListener(_onVideoTick);
        if (!mounted) {
          await controller.dispose();
          return;
        }
        _controller = controller;
      }
      if (mounted) setState(() => _loading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onVideoTick);
      unawaited(controller.dispose());
    }
    if (widget.deleteOnDispose) {
      unawaited(_deleteTemporaryReference());
    }
    super.dispose();
  }

  Future<void> _deleteTemporaryReference() async {
    try {
      if (await widget.file.exists()) await widget.file.delete();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Center(
          child: _loading
              ? const CircularProgressIndicator()
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error.toString(),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : _isPhoto
                      ? InteractiveViewer(
                          child: Image.file(
                            widget.file,
                            fit: BoxFit.contain,
                          ),
                        )
                      : _videoBody(),
        ),
      ),
    );
  }

  Widget _videoBody() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const CircularProgressIndicator();
    }
    final durationMs = controller.value.duration.inMilliseconds;
    final maxMs = durationMs <= 0 ? 1.0 : durationMs.toDouble();
    final positionMs = controller.value.position.inMilliseconds
        .clamp(0, maxMs.toInt())
        .toDouble();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio <= 0
                ? 16 / 9
                : controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed: _togglePlayback,
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill,
              ),
            ),
            Expanded(
              child: Slider(
                min: 0,
                max: maxMs,
                value: positionMs,
                onChanged: (value) => controller.seekTo(
                  Duration(milliseconds: value.round()),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
