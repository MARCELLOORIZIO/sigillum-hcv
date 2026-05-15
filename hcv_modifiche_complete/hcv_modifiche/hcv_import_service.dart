enum HCVImportType {
  hcvpack,
  hcv,
  video,
  unsupported,
}

class HCVImportResult {
  final HCVImportType type;
  final String path;

  const HCVImportResult({
    required this.type,
    required this.path,
  });
}

class HCVImportService {
  HCVImportResult detect(String path) {
    final lower = path.toLowerCase();

    if (lower.endsWith('.hcvpack')) {
      return HCVImportResult(
        type: HCVImportType.hcvpack,
        path: path,
      );
    }

    if (lower.endsWith('.hcv')) {
      return HCVImportResult(
        type: HCVImportType.hcv,
        path: path,
      );
    }

    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.avi')) {
      return HCVImportResult(
        type: HCVImportType.video,
        path: path,
      );
    }

    return HCVImportResult(
      type: HCVImportType.unsupported,
      path: path,
    );
  }
}
