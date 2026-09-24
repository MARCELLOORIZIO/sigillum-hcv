enum SigillumEdition {
  user,
  lab,
}

class SigillumBuildConfig {
  static const _edition = String.fromEnvironment(
    'SIGILLUM_EDITION',
    defaultValue: 'user',
  );

  static SigillumEdition get edition {
    return _edition.toLowerCase() == 'lab'
        ? SigillumEdition.lab
        : SigillumEdition.user;
  }

  static bool get isLab => edition == SigillumEdition.lab;

  static String get appTitle => isLab ? 'SIGILLUM Lab' : 'SIGILLUM';
}
