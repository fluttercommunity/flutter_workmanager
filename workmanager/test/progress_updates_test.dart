import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';
import 'package:workmanager_apple/workmanager_apple.dart';

const String _channelPrefix =
    'dev.flutter.pigeon.workmanager_platform_interface.WorkmanagerFlutterApi.';

/// Fake platform that records calls without touching real platform channels.
/// Extends [WorkmanagerApple] so Workmanager's platform auto-selection (which
/// runs on macOS/iOS/Android hosts) does not replace it.
class _FakeApplePlatform extends WorkmanagerApple {
  final reportedProgress = <Map<String, dynamic>>[];
  final progressListenerCalls = <bool>[];

  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    @Deprecated(
        'Use WorkmanagerDebug handlers instead. This parameter has no effect.')
    bool isInDebugMode = false,
  }) async {}

  @override
  Future<void> reportProgress(Map<String, dynamic> progress) async {
    reportedProgress.add(progress);
  }

  @override
  Future<void> setProgressListener(ProgressListener? listener) async {
    progressListenerCalls.add(listener != null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeApplePlatform platform;

  setUp(() {
    platform = _FakeApplePlatform();
    WorkmanagerPlatform.instance = platform;
  });

  Future<void> sendProgressUpdate(
    String uniqueName,
    Map<String?, Object?>? progress,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final codec = WorkmanagerFlutterApi.pigeonChannelCodec;
    ByteData? reply;
    await messenger.handlePlatformMessage(
      '${_channelPrefix}onProgressUpdate',
      codec.encodeMessage(<Object?>[uniqueName, progress]),
      (data) {
        reply = data;
      },
    );
    expect(reply, isNotNull);
    expect(codec.decodeMessage(reply) as List<Object?>?, isEmpty);
  }

  test('reportProgress delegates to the platform with the given map', () async {
    await Workmanager().reportProgress(<String, dynamic>{
      'progress': 0.5,
      'stage': 'uploading',
    });

    expect(platform.reportedProgress, [
      <String, dynamic>{'progress': 0.5, 'stage': 'uploading'},
    ]);
  });

  test('setProgressListener registers and unregisters the listener', () async {
    final updates = <(String, Map<String, dynamic>)>[];

    // initialize sets up the Flutter API receiver on the current isolate; the
    // progress listener is then invoked by native-side onProgressUpdate
    // messages without the dispatcher ever running.
    await Workmanager().initialize(() {});

    await Workmanager().setProgressListener(
        (uniqueName, progress) => updates.add((uniqueName, progress)));

    expect(platform.progressListenerCalls, [true]);

    await sendProgressUpdate(
      'dev.fluttercommunity.test.sync',
      <String?, Object?>{
        'progress': 0.25,
        'nested': {'x': 1}
      },
    );

    expect(updates, hasLength(1));
    expect(updates.single.$1, 'dev.fluttercommunity.test.sync');
    expect(updates.single.$2, <String, dynamic>{
      'progress': 0.25,
      'nested': <String, dynamic>{'x': 1},
    });

    // Unregistering stops delivery.
    await Workmanager().setProgressListener(null);
    expect(platform.progressListenerCalls, [true, false]);

    await sendProgressUpdate(
        'dev.fluttercommunity.test.sync', <String?, Object?>{'progress': 0.5});
    expect(updates, hasLength(1));
  });

  test('no listener registered means updates are acknowledged and dropped',
      () async {
    final updates = <(String, Map<String, dynamic>)>[];

    await Workmanager().initialize(() {});
    await Workmanager().setProgressListener(
        (uniqueName, progress) => updates.add((uniqueName, progress)));
    await Workmanager().setProgressListener(null);

    await sendProgressUpdate(
        'dev.fluttercommunity.test.sync', <String?, Object?>{'progress': 1.0});

    expect(updates, isEmpty);
  });
}
