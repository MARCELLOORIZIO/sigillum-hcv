class VerifiedOriginalsReference {
  const VerifiedOriginalsReference({
    required this.hcvId,
    required this.platform,
    required this.publicUrl,
    required this.originalContentSha256,
    required this.referenceSha256,
    required this.derivationType,
  });

  final String hcvId;
  final String platform;
  final Uri publicUrl;
  final String originalContentSha256;
  final String referenceSha256;
  final String derivationType;

  static final RegExp _hcvId = RegExp(r'^HCV-[A-F0-9]{16}$');
  static final RegExp _sha256 = RegExp(r'^[a-f0-9]{64}$');
  static final RegExp _youtubeId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  /// Parses a Registry locator only. It never authenticates a third-party
  /// social copy and never turns an HCV-ID/fingerprint into an integrity claim.
  static VerifiedOriginalsReference? fromRegistry(
    Map<String, dynamic> json, {
    required String requestedHcvId,
  }) {
    if (!_hcvId.hasMatch(requestedHcvId) ||
        json['hcvId'] != requestedHcvId ||
        json['availability'] != 'REFERENCE_AVAILABLE' ||
        json['certificateVerdict'] != 'CERTIFICATE_RECORD_VERIFIED' ||
        json['socialFileVerdict'] != 'NOT_VERIFIED' ||
        json['publicationStatus'] != 'PUBLISHED') {
      return null;
    }

    final original = json['originalContentSha256'];
    final reference = json['referenceSha256'];
    final derivationType = json['derivationType'];
    final platform = json['platform'];
    if (original is! String ||
        reference is! String ||
        derivationType is! String ||
        derivationType.isEmpty ||
        platform != 'youtube' ||
        !_sha256.hasMatch(original) ||
        !_sha256.hasMatch(reference)) {
      return null;
    }

    final rawUrl = json['publicUrl'];
    if (rawUrl is! String || rawUrl.length > 160) return null;
    final url = Uri.tryParse(rawUrl);
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'www.youtube.com' ||
        url.hasPort ||
        url.userInfo.isNotEmpty ||
        url.fragment.isNotEmpty ||
        url.path != '/watch' ||
        url.queryParametersAll.length != 1 ||
        url.queryParametersAll['v']?.length != 1 ||
        !_youtubeId.hasMatch(url.queryParameters['v'] ?? '')) {
      return null;
    }

    return VerifiedOriginalsReference(
      hcvId: requestedHcvId,
      platform: platform,
      publicUrl: Uri.https('www.youtube.com', '/watch', {
        'v': url.queryParameters['v']!,
      }),
      originalContentSha256: original,
      referenceSha256: reference,
      derivationType: derivationType,
    );
  }
}
