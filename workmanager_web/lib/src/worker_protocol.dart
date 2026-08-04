// Copyright 2024 The Flutter Workmanager Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Wire contract between the page and the compiled Web Worker dispatcher
/// bundle.
///
/// Both sides encode/decode plain JSON-compatible maps. Keeping the contract
/// in one pure-Dart file lets it be unit-tested on the VM.
abstract final class WorkerProtocol {
  /// Message the worker bundle posts once `main()` has run and the message
  /// listener is attached.
  static const String typeReady = 'ready';

  /// Page -> worker: run a task.
  static const String typeExecuteTask = 'executeTask';

  /// Worker -> page: task finished (or failed).
  static const String typeResult = 'result';

  /// Page -> worker: a free-form message for the dispatcher's message
  /// handler (`WorkmanagerExecution.messageHandler`).
  static const String typeMessage = 'message';

  /// Worker -> page: a free-form message sent by the dispatcher via
  /// `WorkmanagerExecution.sendToPage`.
  static const String typeWorkerMessage = 'workerMessage';

  static const String fieldRequestId = 'requestId';
  static const String fieldPayload = 'payload';
  static const String fieldTaskName = 'taskName';
  static const String fieldInputData = 'inputData';
  static const String fieldResult = 'result';
  static const String fieldError = 'error';

  /// Builds an `executeTask` message.
  static Map<String, Object?> encodeExecuteTask({
    required int requestId,
    required String taskName,
    Object? inputData,
  }) {
    return <String, Object?>{
      'type': typeExecuteTask,
      fieldRequestId: requestId,
      fieldTaskName: taskName,
      fieldInputData: inputData,
    };
  }

  /// Parses an `executeTask` message. Returns `null` when [raw] is malformed.
  static ({int requestId, String taskName, Object? inputData})?
      decodeExecuteTask(Map<Object?, Object?> raw) {
    final type = raw['type'];
    if (type != typeExecuteTask) {
      return null;
    }
    final requestId = raw[fieldRequestId];
    final taskName = raw[fieldTaskName];
    if (requestId is! int || taskName is! String) {
      return null;
    }
    return (
      requestId: requestId,
      taskName: taskName,
      inputData: raw[fieldInputData],
    );
  }

  /// Builds a `result` message.
  static Map<String, Object?> encodeResult({
    required int requestId,
    Object? result,
    String? error,
  }) {
    return <String, Object?>{
      'type': typeResult,
      fieldRequestId: requestId,
      fieldResult: result,
      fieldError: error,
    };
  }

  /// Builds a page -> worker `message` message.
  static Map<String, Object?> encodeMessage(Object? payload) {
    return <String, Object?>{
      'type': typeMessage,
      fieldPayload: payload,
    };
  }

  /// Parses a page -> worker `message` message. Returns `null` when [raw] is
  /// not of that type.
  static Object? decodeMessage(Map<Object?, Object?> raw) {
    if (raw['type'] != typeMessage) {
      return null;
    }
    return raw[fieldPayload];
  }

  /// Builds a worker -> page `workerMessage` message.
  static Map<String, Object?> encodeWorkerMessage(Object? payload) {
    return <String, Object?>{
      'type': typeWorkerMessage,
      fieldPayload: payload,
    };
  }

  /// Parses a worker -> page `workerMessage` message. Returns `null` when
  /// [raw] is not of that type.
  static Object? decodeWorkerMessage(Map<Object?, Object?> raw) {
    if (raw['type'] != typeWorkerMessage) {
      return null;
    }
    return raw[fieldPayload];
  }

  /// Parses a `result` message. Returns `null` when [raw] is malformed.
  static ({int requestId, Object? result, String? error})? decodeResult(
      Map<Object?, Object?> raw) {
    final type = raw['type'];
    if (type != typeResult) {
      return null;
    }
    final requestId = raw[fieldRequestId];
    if (requestId is! int) {
      return null;
    }
    final error = raw[fieldError];
    return (
      requestId: requestId,
      result: raw[fieldResult],
      error: error is String ? error : null,
    );
  }
}
