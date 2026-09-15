import 'package:flutter/foundation.dart';

typedef ExampleLogSink = void Function(String message);

class ExampleLogManager {
  ExampleLogManager._();

  static final ExampleLogManager instance = ExampleLogManager._();

  bool _enabled = !kReleaseMode;
  ExampleLogSink _sink = _debugPrintSink;
  int _requestSequence = 0;

  int nextRequestId() => ++_requestSequence;

  void configure({required bool enabled, required ExampleLogSink sink}) {
    _enabled = enabled;
    _sink = sink;
  }

  void restoreDefaults() {
    _enabled = !kReleaseMode;
    _sink = _debugPrintSink;
    _requestSequence = 0;
  }

  void info(
    String event, {
    required String source,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    _write(level: 'INFO', event: event, source: source, fields: fields);
  }

  void error(
    String event, {
    required String source,
    Map<String, Object?> fields = const <String, Object?>{},
  }) {
    _write(level: 'ERROR', event: event, source: source, fields: fields);
  }

  void _write({
    required String level,
    required String event,
    required String source,
    required Map<String, Object?> fields,
  }) {
    if (!_enabled) return;

    final sortedFields = fields.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    final parts = <String>[
      '[mini_builder_example]',
      'timestamp=${DateTime.now().toUtc().toIso8601String()}',
      'level=$level',
      'event=${_sanitize(event)}',
      'source=${_sanitize(source)}',
      for (final field in sortedFields)
        '${_sanitize(field.key)}=${_sanitize(field.value)}',
    ];

    _sink(parts.join(' '));
  }

  static String _sanitize(Object? value) {
    return (value?.toString() ?? 'null').replaceAll(RegExp(r'[\s=]+'), '_');
  }

  static void _debugPrintSink(String message) {
    debugPrint(message);
  }
}
