class HCVSoftwareAttestation {
  const HCVSoftwareAttestation._();

  static const String schema = 'SIGILLUM_SOFTWARE_ATTESTATION';
  static const int schemaVersion = 1;
  static const String bindingMethod =
      'COMPILE_TIME_BUILD_METADATA_IN_SIGNED_HCV_CERTIFICATE';

  static const String _runtimeGitCommit =
      String.fromEnvironment('GIT_COMMIT');
  static const String _runtimeEdition = String.fromEnvironment(
    'SIGILLUM_EDITION',
    defaultValue: 'unknown',
  );

  static Map<String, dynamic> current() {
    return fromValues(
      sourceCommit: _runtimeGitCommit,
      edition: _runtimeEdition,
    );
  }

  static Map<String, dynamic> fromValues({
    required String sourceCommit,
    required String edition,
  }) {
    final cleanCommit = sourceCommit.trim().toLowerCase();
    final cleanEdition = edition.trim();
    final algorithm = _commitAlgorithm(cleanCommit);
    final bound = algorithm != null;

    return <String, dynamic>{
      'type': schema,
      'version': schemaVersion,
      'status': bound ? 'BOUND' : 'UNBOUND',
      'bindingMethod': bindingMethod,
      if (bound) 'sourceCommit': cleanCommit,
      if (algorithm != null) 'sourceCommitAlgorithm': algorithm,
      if (cleanEdition.isNotEmpty) 'edition': cleanEdition,
    };
  }

  static bool isValid(Map<String, dynamic> value) {
    if (value['type'] != schema || value['version'] != schemaVersion) {
      return false;
    }
    if (value['bindingMethod'] != bindingMethod) return false;

    final status = value['status'];
    if (status != 'BOUND' && status != 'UNBOUND') return false;

    final rawEdition = value['edition'];
    if (rawEdition != null &&
        (rawEdition is! String || rawEdition.trim().isEmpty)) {
      return false;
    }

    if (status == 'UNBOUND') {
      return !value.containsKey('sourceCommit') &&
          !value.containsKey('sourceCommitAlgorithm');
    }

    final commit = value['sourceCommit'];
    final algorithm = value['sourceCommitAlgorithm'];
    if (commit is! String || algorithm is! String) return false;

    return _commitAlgorithm(commit) == algorithm;
  }

  static String? _commitAlgorithm(String commit) {
    if (RegExp(r'^[a-f0-9]{40}$').hasMatch(commit)) return 'GIT_SHA1';
    if (RegExp(r'^[a-f0-9]{64}$').hasMatch(commit)) return 'GIT_SHA256';
    return null;
  }
}
