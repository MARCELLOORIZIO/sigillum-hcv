enum HCVCaptureLifecycle {
  idle,
  preparingVideo,
  recording,
  finalizingVideo,
  processingVideo,
  capturingPhoto,
  processingPhoto,
}

extension HCVCaptureLifecyclePolicy on HCVCaptureLifecycle {
  bool get interactionLocked => this != HCVCaptureLifecycle.idle;

  bool get captureButtonEnabled =>
      this == HCVCaptureLifecycle.idle || this == HCVCaptureLifecycle.recording;

  bool get captureSettingsMutable => this == HCVCaptureLifecycle.idle;

  bool get canStopRecording => this == HCVCaptureLifecycle.recording;
}
