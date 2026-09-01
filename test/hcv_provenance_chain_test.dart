import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sigillum_hcv/hcv_provenance_chain.dart';

String _hex(String char) => List<String>.filled(64, char).join();

Future<HCVProvenanceSignature> _testSigner(String data) async {
  return HCVProvenanceSignature(
    signature: sha256
        .convert(utf8.encode('LOCAL_DEV_SIGNATURE:$data'))
        .toString(),
    publicKey: const {
      'modulus': 'LOCAL_DEV_PUBLIC_KEY',
      'exponent': 'LOCAL_DEV',
    },
  );
}

void main() {
  test('canonical JSON is deterministic across map key order', () {
    final first = HCVProvenanceChain.canonicalJson({
      'z': 1,
      'a': {
        'y': true,
        'b': 2,
      },
    });
    final second = HCVProvenanceChain.canonicalJson({
      'a': {
        'b': 2,
        'y': true,
      },
      'z': 1,
    });

    expect(first, second);
    expect(first, '{"a":{"b":2,"y":true},"z":1}');
  });

  test('D1 appends signed events and verifies ordered parent chain', () async {
    final dir = await Directory.systemTemp.createTemp('hcv_provenance_ok_');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/provenance.jsonl');

    var clock = DateTime.utc(2026, 9, 1, 12);
    final nonces = <String>['nonce-1', 'nonce-2'];
    var nonceIndex = 0;
    final chain = HCVProvenanceChain(
      logFile: file,
      signer: _testSigner,
      now: () {
        final value = clock;
        clock = clock.add(const Duration(seconds: 1));
        return value;
      },
      nonceGenerator: () => nonces[nonceIndex++],
    );

    final first = await chain.appendEvent(
      eventType: 'CAPTURE_INPUT',
      inputHash: _hex('a'),
      deviceFingerprint: _hex('b'),
      sessionId: 'session-123',
      pipelineVersion: 'reality-display-v1',
      metadata: const {'kind': 'photo'},
    );
    final second = await chain.appendEvent(
      eventType: 'ANALYSIS_COMPLETE',
      inputHash: _hex('c'),
      deviceFingerprint: _hex('b'),
      sessionId: 'session-123',
      pipelineVersion: 'reality-display-v1',
      metadata: const {'decision': 'REALITY'},
    );

    expect(first['sequence'], 0);
    expect(first['parentEvent'], 'GENESIS');
    expect(second['sequence'], 1);
    expect(second['parentEvent'], first['eventHash']);
    expect(second['sessionId'], 'session-123');
    expect(second['pipelineVersion'], 'reality-display-v1');

    final verified = await chain.verify();
    expect(verified.valid, isTrue);
    expect(verified.code, 'VERIFIED');
    expect(verified.events, hasLength(2));
  });

  test('D1 detects payload tampering', () async {
    final setup = await _twoEventChain('tamper');
    addTearDown(setup.dir.delete);

    final lines = await setup.file.readAsLines();
    final first = jsonDecode(lines.first) as Map<String, dynamic>;
    first['metadata'] = {'kind': 'tampered'};
    lines[0] = jsonEncode(first);
    await setup.file.writeAsString('${lines.join('\n')}\n');

    final verified = await setup.chain.verify();
    expect(verified.valid, isFalse);
    expect(verified.code, 'TAMPER');
  });

  test('D1 rejects duplicate nonce replay', () async {
    final setup = await _twoEventChain('replay');
    addTearDown(setup.dir.delete);

    final lines = await setup.file.readAsLines();
    final first = jsonDecode(lines[0]) as Map<String, dynamic>;
    final second = jsonDecode(lines[1]) as Map<String, dynamic>;
    second['nonce'] = first['nonce'];
    lines[1] = jsonEncode(second);
    await setup.file.writeAsString('${lines.join('\n')}\n');

    final verified = await setup.chain.verify();
    expect(verified.valid, isFalse);
    expect(verified.code, 'REPLAY');
  });

  test('D1 rejects reordered append-only events', () async {
    final setup = await _twoEventChain('order');
    addTearDown(setup.dir.delete);

    final lines = await setup.file.readAsLines();
    await setup.file.writeAsString('${lines.reversed.join('\n')}\n');

    final verified = await setup.chain.verify();
    expect(verified.valid, isFalse);
    expect(verified.code, 'ORDER');
  });

  test('D1 rejects broken parent link', () async {
    final setup = await _twoEventChain('parent');
    addTearDown(setup.dir.delete);

    final lines = await setup.file.readAsLines();
    final second = jsonDecode(lines[1]) as Map<String, dynamic>;
    second['parentEvent'] = _hex('f');
    lines[1] = jsonEncode(second);
    await setup.file.writeAsString('${lines.join('\n')}\n');

    final verified = await setup.chain.verify();
    expect(verified.valid, isFalse);
    expect(verified.code, 'CHAIN');
  });

  test('D1 rejects signature tampering', () async {
    final setup = await _twoEventChain('signature');
    addTearDown(setup.dir.delete);

    final lines = await setup.file.readAsLines();
    final first = jsonDecode(lines[0]) as Map<String, dynamic>;
    first['signature'] = 'bad-signature';
    lines[0] = jsonEncode(first);
    await setup.file.writeAsString('${lines.join('\n')}\n');

    final verified = await setup.chain.verify();
    expect(verified.valid, isFalse);
    expect(verified.code, 'SIGNATURE');
  });

  test('D1 refuses to append after stored log corruption', () async {
    final setup = await _twoEventChain('append_guard');
    addTearDown(setup.dir.delete);

    await setup.file.writeAsString('{broken json}\n');

    expect(
      () => setup.chain.appendEvent(
        eventType: 'SHOULD_NOT_APPEND',
        inputHash: _hex('d'),
        deviceFingerprint: _hex('b'),
        sessionId: 'session-test',
        pipelineVersion: 'pipeline-v1',
      ),
      throwsA(isA<StateError>()),
    );
  });
}

class _ChainSetup {
  const _ChainSetup(this.dir, this.file, this.chain);

  final Directory dir;
  final File file;
  final HCVProvenanceChain chain;
}

Future<_ChainSetup> _twoEventChain(String suffix) async {
  final dir = await Directory.systemTemp.createTemp('hcv_provenance_$suffix');
  final file = File('${dir.path}/provenance.jsonl');
  var clock = DateTime.utc(2026, 9, 1, 12);
  var nonce = 0;
  final chain = HCVProvenanceChain(
    logFile: file,
    signer: _testSigner,
    now: () {
      final value = clock;
      clock = clock.add(const Duration(seconds: 1));
      return value;
    },
    nonceGenerator: () => 'nonce-${nonce++}',
  );

  await chain.appendEvent(
    eventType: 'FIRST',
    inputHash: _hex('a'),
    deviceFingerprint: _hex('b'),
    sessionId: 'session-test',
    pipelineVersion: 'pipeline-v1',
  );
  await chain.appendEvent(
    eventType: 'SECOND',
    inputHash: _hex('c'),
    deviceFingerprint: _hex('b'),
    sessionId: 'session-test',
    pipelineVersion: 'pipeline-v1',
  );

  return _ChainSetup(dir, file, chain);
}
