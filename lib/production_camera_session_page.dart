import 'dart:async';

import 'package:flutter/material.dart';

import 'hcv_live_signals.dart';
import 'production_camera_page.dart';

class ProductionCameraSessionPage extends StatefulWidget {
  const ProductionCameraSessionPage({
    super.key,
    this.initialPhotoMode = false,
  });

  final bool initialPhotoMode;

  @override
  State<ProductionCameraSessionPage> createState() =>
      _ProductionCameraSessionPageState();
}

class _ProductionCameraSessionPageState
    extends State<ProductionCameraSessionPage> {
  @override
  void dispose() {
    unawaited(HCVLiveSignals.cancelAll());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProductionCameraPage(
      initialPhotoMode: widget.initialPhotoMode,
    );
  }
}
