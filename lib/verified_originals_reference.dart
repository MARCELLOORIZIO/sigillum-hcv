class VerifiedOriginalsReference {
  const VerifiedOriginalsReference({
    required this.hcvId,
    required this.platform,
    required this.originalContentSha256,
    required this.referenceSha256,
    required this.derivationType,
    this.publicUrl,
    this.referenceAccess,
  });

  final String hcvId;
  final String platform;
  final Uri? publicUrl;
  final String? referenceAccess;
  final String originalContentSha256;
  final String referenceSha256;
  final String derivationType;

  bool get isPrivateR2 =>
      platform == 'r2' && referenceAccess == 'SHORT_LIVED_AUTHORIZATION';

  static final RegExp _hcvId = RegExp(r'^HCV-[A-F0-9]{16}$');
  static final RegExp _sha256 = RegExp(r'^[a-f0-9]{64}$');

  /// Free discovery never carries a provider locator. A positive result only
  /// means that SIGILLUM has an active certified reference for this HCV-ID.
  static bool isAvailable(
    Map<String, dynamic> json, {
    required String requestedHcvId,
  }) {
    final platform = json['platform']?.toString();
    final providerSupported = platform == 'r2';
    return _hcvId.hasMatch(requestedHcvId) &&
        json['hcvId'] == requestedHcvId &&
        json['availability'] == 'REFERENCE_AVAILABLE' &&
        json['certificateVerdict'] == 'CERTIFICATE_RECORD_VERIFIED' &&
        json['socialFileVerdict'] == 'NOT_VERIFIED' &&
        json['publicationStatus'] == 'PUBLISHED' &&
        json['viewAccess'] == 'SUBSCRIPTION_REQUIRED' &&
        providerSupported &&
        !json.containsKey('publicUrl') &&
        !json.containsKey('platformPostId');
  }

  /// Parses only the paid /view response. It never authenticates a third-party
  /// social copy and never turns an HCV-ID/fingerprint into an integrity claim.
  static VerifiedOriginalsReference? fromRegistry(
    Map<String, dynamic> json, {
    required String requestedHcvId,
  }) {
    if (!_hcvId.hasMatch(requestedHcvId) ||
        json['hcvId'] != requestedHcvId ||
        json['availability'] != 'REFERENCE_AVAILABLE' ||
        json['access'] != 'ENTITLED' ||
        json['certificateVerdict'] != 'CERTIFICATE_RECORD_VERIFIED' ||
        json['socialFileVerdict'] != 'NOT_VERIFIED' ||
        json['publicationStatus'] != 'PUBLISHED') {
      return null;
    }

    final original = json['originalContentSha256'];
    final reference = json['referenceSha256'];
    final derivationType = json['derivationType'];
    final platform = json['platform']?.toString();

    if (original is! String ||
        reference is! String ||
        derivationType is! String ||
        derivationType.isEmpty ||
        !_sha256.hasMatch(original) ||
        !_sha256.hasMatch(reference)) {
      return null;
    }

    if (platform == 'r2') {
      if (json['referenceAccess'] != 'SHORT_LIVED_AUTHORIZATION' ||
          json.containsKey('publicUrl') ||
          json.containsKey('platformPostId')) {
        return null;
      }
      return VerifiedOriginalsReference(
        hcvId: requestedHcvId,
        platform: 'r2',
        referenceAccess: 'SHORT_LIVED_AUTHORIZATION',
        originalContentSha256: original,
        referenceSha256: reference,
        derivationType: derivationType,
      );
    }

    return null;
  }
}
