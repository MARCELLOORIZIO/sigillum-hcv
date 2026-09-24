class VerifiedOriginalsReference {
  const VerifiedOriginalsReference({
    required this.hcvId,
    required this.youtubeUrl,
    required this.originalSha256,
    required this.renditionSha256,
  });

  final String hcvId;
  final Uri youtubeUrl;
  final String originalSha256;
  final String renditionSha256;

  static final RegExp _hcvId = RegExp(r'^HCV-[A-F0-9]{16}$');
  static final RegExp _sha256 = RegExp(r'^[a-f0-9]{64}$');
  static final RegExp _youtubeId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  // This is a locator to a reference, NOT authentication of a social copy.
  static VerifiedOriginalsReference? fromRegistry(
    Map<String, dynamic> json, {
    required String requestedHcvId,
  }) {
    if (!_hcvId.hasMatch(requestedHcvId) ||
        json['hcvId'] != requestedHcvId ||
        json['availability'] != 'REFERENCE_AVAILABLE' ||
        json['certificateVerdict'] != 'CERTIFICATE_RECORD_VERIFIED' ||
        json['socialFileVerdict'] != 'NOT_VERIFIED') {
      return null;
    }
    final source = json['originalSha256'];
    final rendition = json['renditionSha256'];
    if (source is! String ||
        rendition is! String ||
        !_sha256.hasMatch(source) ||
        !_sha256.hasMatch(rendition)) {
      return null;
    }
    final rawUrl = json['youtubeUrl'];
    if (rawUrl is! String) return null;
    final url = Uri.tryParse(rawUrl);
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'www.youtube.com' ||
        url.path != '/watch' ||
        url.queryParameters.length != 1 ||
        !_youtubeId.hasMatch(url.queryParameters['v'] ?? '')) {
      return null;
    }
    return VerifiedOriginalsReference(
      hcvId: requestedHcvId,
      youtubeUrl: url,
      originalSha256: source,
      renditionSha256: rendition,
    );
  }
}
