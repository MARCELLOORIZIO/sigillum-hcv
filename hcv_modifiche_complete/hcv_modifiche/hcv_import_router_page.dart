import 'package:flutter/material.dart';

import 'hcv_import_service.dart';
import 'hcvpack_player_page.dart';
import 'verify_page.dart';
import 'video_verify_page.dart';

class HCVImportRouterPage extends StatelessWidget {
  final String path;

  const HCVImportRouterPage({
    super.key,
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    final result = HCVImportService().detect(path);

    switch (result.type) {
      case HCVImportType.hcvpack:
        return HCVPackPlayerPage(initialPath: path);

      case HCVImportType.hcv:
        return VerifyPage(initialPath: path);

      case HCVImportType.video:
        return VideoVerifyPage(initialVideoPath: path);

      case HCVImportType.unsupported:
        return Scaffold(
          appBar: AppBar(
            title: const Text("HCV Import"),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "Formato non supportato:\n$path",
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
    }
  }
}
