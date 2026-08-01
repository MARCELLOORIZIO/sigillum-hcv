import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sigillum_iphone/hcv_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing certificate remains as a terminal Registry failure', () async {
    SharedPreferences.setMockInitialValues({
      'hcv_registry_pending_uploads_v2': jsonEncode([
        {
          'hcvId': 'HCV-0123456789ABCDEF',
          'path': '/definitely/missing/certificate.hcv',
          'sha256': List.filled(64, 'a').join(),
          'queuedAt': '2026-07-23T00:00:00.000Z',
          'attempts': 0,
          'terminal': false,
        },
      ]),
    });

    const registry = HCVRegistryService();
    final report = await registry.retryPendingUploads();
    final pending = await registry.pendingUploads();

    expect(report.uploaded, 0);
    expect(report.pending, 1);
    expect(report.discarded, 1);
    expect(report.hasTerminalFailures, isTrue);
    expect(pending, hasLength(1));
    expect(pending.single['terminal'], isTrue);
    expect(pending.single['lastError'], contains('non disponibile'));
  });
}
