class HCVBuildInfo {
  static const commit = String.fromEnvironment(
    'GIT_COMMIT',
    defaultValue: 'UNKNOWN',
  );
  static const branch = String.fromEnvironment(
    'GIT_BRANCH',
    defaultValue: 'UNKNOWN',
  );
  static const builtAt = String.fromEnvironment(
    'BUILD_TIME_UTC',
    defaultValue: 'UNKNOWN',
  );
  static const edition = String.fromEnvironment(
    'SIGILLUM_EDITION',
    defaultValue: 'unknown',
  );

  static String get shortCommit {
    if (commit == 'UNKNOWN' || commit.length <= 8) return commit;
    return commit.substring(0, 8);
  }

  static Map<String, dynamic> toJson() => {
        'commit': commit,
        'branch': branch,
        'builtAt': builtAt,
        'edition': edition,
      };
}
