class HCVCaptureTimestamp {
  const HCVCaptureTimestamp._();

  static String format(DateTime value) {
    final local = value.toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final absoluteOffset = offset.abs();

    return '${_two(local.day)}/${_two(local.month)}/${local.year} '
        '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)} '
        'UTC$sign${_two(absoluteOffset.inHours)}:'
        '${_two(absoluteOffset.inMinutes.remainder(60))}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
