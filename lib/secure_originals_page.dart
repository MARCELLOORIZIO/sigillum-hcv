import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'hcv_secure_media_vault.dart';
import 'hcv_secure_preview_service.dart';
import 'sigillum_localization.dart';
import 'verified_originals_publish_service.dart';

class SecureOriginalsPage extends StatefulWidget {
  const SecureOriginalsPage({
    super.key,
    required this.languageCode,
    this.selectionMode = false,
  });

  final String languageCode;
  final bool selectionMode;

  @override
  State<SecureOriginalsPage> createState() => _SecureOriginalsPageState();
}

class _SecureOriginalsPageState extends State<SecureOriginalsPage> {
  final HCVSecureMediaVault _vault = const HCVSecureMediaVault();
  final HCVSecurePreviewService _preview = const HCVSecurePreviewService();
  final VerifiedOriginalsPublishService _publisher =
      const VerifiedOriginalsPublishService();

  final Map<String, Future<File?>> _previewFutures = {};
  List<HCVSecureOriginalRecord> _records = const [];
  bool _loading = true;
  String? _message;
  String? _busyId;

  String _t(String key) => SigillumCopy.t(widget.languageCode, key);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    unawaited(_preview.clearCache());
    super.dispose();
  }

  Future<File?> _previewFor(HCVSecureOriginalRecord record) {
    return _previewFutures.putIfAbsent(
      record.hcvId,
      () => _preview.thumbnail(record).catchError((_) => null),
    );
  }

  String _recordDate(HCVSecureOriginalRecord record) {
    final local = record.createdAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} · '
        '${two(local.hour)}:${two(local.minute)}';
  }

  void _select(HCVSecureOriginalRecord record) {
    Navigator.of(context).pop(record);
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _message = null;
      });
    }
    try {
      final records = await _vault.list();
      if (!mounted) return;
      setState(() {
        _records = records;
        final ids = records.map((item) => item.hcvId).toSet();
        _previewFutures.removeWhere((key, _) => !ids.contains(key));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '${_t('secureOriginalsLoadError')}: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _view(HCVSecureOriginalRecord record) async {
    if (_busyId != null) return;
    setState(() => _busyId = record.hcvId);
    File? clear;
    try {
      clear = await _vault.materializeOriginal(record, purpose: 'view');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _SecureOriginalViewerPage(
            file: clear!,
            record: record,
            languageCode: widget.languageCode,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _message = '${_t('secureOriginalsViewError')}: $error');
      }
    } finally {
      if (clear != null) await _vault.deleteMaterialized(clear);
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<_ShareDecision?> _shareDecision() async {
    var rights = false;
    var monetization = false;
    return showDialog<_ShareDecision>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(_t('secureOriginalsShareTitle')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_t('secureOriginalsShareDisclosure')),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: rights,
                  onChanged: (value) =>
                      setLocalState(() => rights = value == true),
                  title: Text(_t('secureOriginalsRightsConfirm')),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: monetization,
                  onChanged: (value) =>
                      setLocalState(() => monetization = value),
                  title: Text(_t('secureOriginalsMonetization')),
                  subtitle: Text(_t('secureOriginalsMonetizationHint')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_t('cancel')),
            ),
            FilledButton(
              onPressed: rights
                  ? () => Navigator.pop(
                        dialogContext,
                        _ShareDecision(
                          monetizationConsent: monetization,
                        ),
                      )
                  : null,
              child: Text(_t('secureOriginalsContinueShare')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share(HCVSecureOriginalRecord record) async {
    if (_busyId != null) return;
    final decision = await _shareDecision();
    if (decision == null || !mounted) return;

    setState(() {
      _busyId = record.hcvId;
      _message = _t('secureOriginalsPublishingReference');
    });

    File? clear;
    try {
      await _publisher.ensureReference(
        record,
        monetizationConsent: decision.monetizationConsent,
      );

      final refreshed = await _vault.find(record.hcvId) ?? record;
      clear = await _vault.materializeOriginal(refreshed, purpose: 'social');
      if (!mounted) return;
      setState(() => _message = _t('secureOriginalsReferenceReady'));

      await Share.shareXFiles(
        [
          XFile(
            clear.path,
            mimeType: refreshed.mediaType == 'video'
                ? 'video/mp4'
                : _photoMime(clear.path),
          ),
        ],
        text:
            '${_t('secureOriginalsShareText')}\nHCV-ID: ${refreshed.hcvId}\nhttps://sigillum-hcv.com/originals/${refreshed.hcvId}?lang=${widget.languageCode}',
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      );
      if (mounted) {
        setState(() => _message = _t('secureOriginalsShareComplete'));
      }
      await _reload();
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = '${_t('secureOriginalsShareBlocked')}: $error';
        });
      }
    } finally {
      if (clear != null) await _vault.deleteMaterialized(clear);
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _openOfficialCopy(HCVSecureOriginalRecord record) async {
    final raw = record.referenceUrl?.trim() ?? '';
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) {
      setState(() => _message = _t('voOpenError'));
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _message = _t('voOpenError'));
    }
  }

  Future<void> _withdraw(HCVSecureOriginalRecord record) async {
    if (_busyId != null || !record.hasReference) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t('secureOriginalsWithdrawTitle')),
        content: Text(_t('secureOriginalsWithdrawBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_t('secureOriginalsWithdrawConfirm')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() {
      _busyId = record.hcvId;
      _message = _t('secureOriginalsWithdrawing');
    });

    try {
      await _publisher.withdrawReference(record);
      if (!mounted) return;
      setState(() => _message = _t('secureOriginalsWithdrawn'));
      await _reload();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      final pending = message.contains('REFERENCE_TAKEDOWN_PENDING') ||
          message.contains('REFERENCE_TAKEDOWN_PARTIAL');
      setState(
        () => _message = pending
            ? _t('secureOriginalsWithdrawPending')
            : '${_t('secureOriginalsWithdrawError')}: $error',
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String _photoMime(String path) =>
      path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.selectionMode
              ? _t('secureOriginalsSelectTitle')
              : _t('secureOriginalsTitle'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              widget.selectionMode
                  ? _t('secureOriginalsSelectIntro')
                  : _t('secureOriginalsIntro'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  _t('secureOriginalsEmpty'),
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final record in _records) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: FutureBuilder<File?>(
                              future: _previewFor(record),
                              builder: (context, snapshot) {
                                final file = snapshot.data;
                                if (file != null) {
                                  return Image.file(
                                    file,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  );
                                }
                                if (snapshot.connectionState !=
                                    ConnectionState.done) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                return ColoredBox(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: Center(
                                    child: Icon(
                                      record.mediaType == 'video'
                                          ? Icons.videocam_outlined
                                          : Icons.photo_outlined,
                                      size: 46,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          record.hcvId,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${record.mediaType == 'video' ? _t('video') : _t('photo')}'
                          ' · ${_recordDate(record)}',
                        ),
                        Text(
                          record.hasReference
                              ? _t('secureOriginalsReferencePublished')
                              : _t('secureOriginalsReferencePending'),
                        ),
                        const SizedBox(height: 10),
                        if (widget.selectionMode)
                          FilledButton.icon(
                            onPressed: () => _select(record),
                            icon: const Icon(Icons.check_circle_outline),
                            label: Text(_t('secureOriginalsSelect')),
                          )
                        else
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _busyId == null
                                    ? () => _view(record)
                                    : null,
                                icon: const Icon(Icons.play_circle_outline),
                                label: Text(_t('secureOriginalsView')),
                              ),
                              FilledButton.icon(
                                onPressed: _busyId == null
                                    ? () => _share(record)
                                    : null,
                                icon: const Icon(Icons.ios_share),
                                label: Text(_t('secureOriginalsShare')),
                              ),
                              if (record.hasReference)
                                OutlinedButton.icon(
                                  onPressed: _busyId == null
                                      ? () => _openOfficialCopy(record)
                                      : null,
                                  icon: const Icon(Icons.open_in_new),
                                  label:
                                      Text(_t('secureOriginalsOfficialCopy')),
                                ),
                              if (record.hasReference)
                                OutlinedButton.icon(
                                  onPressed: _busyId == null
                                      ? () => _withdraw(record)
                                      : null,
                                  icon: const Icon(Icons.link_off),
                                  label: Text(_t('secureOriginalsWithdraw')),
                                ),
                            ],
                          ),
                        if (_busyId == record.hcvId) ...[
                          const SizedBox(height: 10),
                          const LinearProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            if (_message != null) ...[
              const SizedBox(height: 10),
              Text(_message!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShareDecision {
  const _ShareDecision({required this.monetizationConsent});
  final bool monetizationConsent;
}

class _SecureOriginalViewerPage extends StatefulWidget {
  const _SecureOriginalViewerPage({
    required this.file,
    required this.record,
    required this.languageCode,
  });

  final File file;
  final HCVSecureOriginalRecord record;
  final String languageCode;

  @override
  State<_SecureOriginalViewerPage> createState() =>
      _SecureOriginalViewerPageState();
}

class _SecureOriginalViewerPageState extends State<_SecureOriginalViewerPage> {
  VideoPlayerController? _video;
  Future<void>? _initializeVideo;

  String _t(String key) => SigillumCopy.t(widget.languageCode, key);

  @override
  void initState() {
    super.initState();
    if (widget.record.mediaType == 'video') {
      _video = VideoPlayerController.file(widget.file);
      _initializeVideo = _video!.initialize().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t('secureOriginalsViewerTitle'))),
      body: Center(
        child: widget.record.mediaType == 'video'
            ? FutureBuilder<void>(
                future: _initializeVideo,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const CircularProgressIndicator();
                  }
                  final controller = _video!;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: controller.value.aspectRatio == 0
                            ? 16 / 9
                            : controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            controller.value.isPlaying
                                ? controller.pause()
                                : controller.play();
                          });
                        },
                        icon: Icon(
                          controller.value.isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle,
                          size: 48,
                        ),
                      ),
                    ],
                  );
                },
              )
            : InteractiveViewer(
                child: Image.file(widget.file, fit: BoxFit.contain),
              ),
      ),
    );
  }
}
