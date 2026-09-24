/// Accept only a canonical YouTube watch link from SIGILLUM Registry.
/// A link is a reference, never a cryptographic media-integrity verdict.
Uri? verifiedOriginalsYoutubeUri(Object? raw) {
  if (raw is! String || raw.length > 160) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'https' ||
      uri.host != 'www.youtube.com' || uri.hasPort ||
      uri.userInfo.isNotEmpty || uri.fragment.isNotEmpty ||
      uri.path != '/watch' || uri.queryParametersAll.length != 1 ||
      uri.queryParametersAll['v']?.length != 1) {
    return null;
  }
  final id = uri.queryParameters['v'];
  if (id == null || !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
    return null;
  }
  return Uri.https('www.youtube.com', '/watch', {'v': id});
}
