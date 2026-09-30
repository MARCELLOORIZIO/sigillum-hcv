import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'commercial_account_service.dart';
import 'registry_verify_copy.dart';
import 'sigillum_theme.dart';
import 'verified_originals_publish_service.dart';
import 'verified_originals_reference.dart';

class ManualReferenceComparePage extends StatefulWidget {
  const ManualReferenceComparePage({
    super.key,
    required this.hcvId,
    required this.mediaPath,
    required this.languageCode,
    this.automaticVerdictTitle,
  });

  final String hcvId;
  final String mediaPath;
  final String languageCode;
  final String? automaticVerdictTitle;

  @override
  State<ManualReferenceComparePage> createState() =>
      _ManualReferenceComparePageState();
}

class _ManualReferenceComparePageState
    extends State<ManualReferenceComparePage> {
  final VerifiedOriginalsPublishService _publisher =
      const VerifiedOriginalsPublishService();

  VideoPlayerController? _videoController;
  VerifiedOriginalsReference? _reference;
  String? _error;
  bool _loading = true;
  bool _muted = false;

  String _r(String key) => RegistryVerifyCopy.t(widget.languageCode, key);

  bool get _isVideo {
    final lower = widget.mediaPath.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v');
  }

  bool get _isPhoto {
    final lower = widget.mediaPath.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    final controller = _videoController;
    if (controller != null) {
      controller.removeListener(_onVideoTick);
      controller.dispose();
    }
    super.dispose();
  }

  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final media = File(widget.mediaPath);
      if (!await media.exists() || (!_isVideo && !_isPhoto)) {
        throw StateError('MANUAL_COMPARE_MEDIA_UNAVAILABLE');
      }

      final billing = await const CommercialAccountService().billingStatus();
      if (billing['status']?.toString() != 'active') {
        throw StateError('SUBSCRIPTION_REQUIRED');
      }

      final live = await _publisher.entitledLiveReference(widget.hcvId);
      final reference = VerifiedOriginalsReference.fromRegistry(
        live,
        requestedHcvId: widget.hcvId,
      );
      if (reference == null) {
        throw StateError('REFERENCE_RESPONSE_INVALID');
      }

      VideoPlayerController? controller;
      if (_isVideo) {
        controller = VideoPlayerController.file(media);
        await controller.initialize();
        await controller.setLooping(false);
        controller.addListener(_onVideoTick);
      }

      if (!mounted) {
        await controller?.dispose();
        return;
      }
      setState(() {
        _reference = reference;
        _videoController = controller;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      final raw = error.toString();
      setState(() {
        _loading = false;
        if (raw.contains('SUBSCRIPTION_REQUIRED')) {
          _error = _r('manualCompareSubscriptionRequired');
        } else if (raw.contains('REFERENCE_PLATFORM_UNAVAILABLE') ||
            raw.contains('REFERENCE_NOT_AVAILABLE')) {
          _error = _r('manualCompareReferenceUnavailable');
        } else if (raw.contains('MANUAL_COMPARE_MEDIA_UNAVAILABLE')) {
          _error = _r('manualCompareMediaUnavailable');
        } else {
          _error = _r('manualCompareLoadError');
        }
      });
    }
  }

  String _format(Duration value) {
    final totalSeconds = value.inSeconds < 0 ? 0 : value.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _togglePlayback() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    _muted = !_muted;
    await controller.setVolume(_muted ? 0 : 1);
    if (mounted) setState(() {});
  }

  Future<void> _openOfficialReference() async {
    final reference = _reference;
    if (reference == null) return;

    var target = reference.publicUrl;
    final controller = _videoController;
    if (controller != null && controller.value.isInitialized) {
      await controller.pause();
      final seconds = controller.value.position.inSeconds;
      if (seconds > 0) {
        target = Uri.https(
          reference.publicUrl.host,
          reference.publicUrl.path,
          <String, String>{
            ...reference.publicUrl.queryParameters,
            't': '${seconds}s',
          },
        );
      }
    }

    final opened = await launchUrl(
      target,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      setState(() => _error = _r('manualCompareOpenError'));
    }
  }

  Widget _localMedia() {
    if (_isPhoto) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(widget.mediaPath),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_r('manualCompareMediaUnavailable')),
          ),
        ),
      );
    }

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final duration = controller.value.duration;
    final position = controller.value.position;
    final maxMs =
        duration.inMilliseconds <= 0 ? 1.0 : duration.inMilliseconds.toDouble();
    final positionMs =
        position.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();

    return Column(
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio <= 0
              ? 16 / 9
              : controller.value.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
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
              tooltip: _r('manualComparePlayPause'),
            ),
            Expanded(
              child: Slider(
                value: positionMs,
                min: 0,
                max: maxMs,
                onChanged: (value) {
                  controller.seekTo(
                    Duration(milliseconds: value.round()),
                  );
                },
              ),
            ),
            IconButton(
              onPressed: _toggleMute,
              icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
              tooltip: _r('manualCompareAudio'),
            ),
          ],
        ),
        Text(
          '${_format(position)} / ${_format(duration)}',
          style: const TextStyle(
            color: SigillumTheme.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    final currentTime = controller != null && controller.value.isInitialized
        ? _format(controller.value.position)
        : null;

    return Scaffold(
      backgroundColor: SigillumTheme.deep,
      appBar: AppBar(
        backgroundColor: SigillumTheme.panel,
        foregroundColor: SigillumTheme.ink,
        title: Text(_r('manualCompareTitle')),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline, color: SigillumTheme.ink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _r('manualCompareSubscriberOnly'),
                        style: const TextStyle(
                          color: SigillumTheme.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _r('manualCompareIntro'),
                  style: const TextStyle(
                    color: SigillumTheme.muted,
                    height: 1.35,
                  ),
                ),
                if (widget.automaticVerdictTitle != null &&
                    widget.automaticVerdictTitle!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    '${_r('manualCompareAutomaticVerdict')}: '
                    '${widget.automaticVerdictTitle}',
                    style: const TextStyle(
                      color: SigillumTheme.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: SigillumTheme.border),
                    ),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: SigillumTheme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else ...[
                  Text(
                    _r('manualCompareLocalTitle'),
                    style: const TextStyle(
                      color: SigillumTheme.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _localMedia(),
                  const SizedBox(height: 24),
                  Text(
                    _r('manualCompareOfficialTitle'),
                    style: const TextStyle(
                      color: SigillumTheme.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isVideo
                        ? _r('manualCompareVideoHelp')
                        : _r('manualComparePhotoHelp'),
                    style: const TextStyle(
                      color: SigillumTheme.muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _openOfficialReference,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(
                      _isVideo && currentTime != null
                          ? _r('manualCompareOpenAtTime')
                              .replaceAll('{time}', currentTime)
                          : _r('manualCompareOpenOfficial'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _r('manualCompareReturnHelp'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: SigillumTheme.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
