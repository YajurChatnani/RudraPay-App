import 'package:flutter/foundation.dart';

Future<T> traceAwait<T>(String label, Future<T> future, {String prefix = '[ASYNC]'}) async {
  final start = DateTime.now();
  try {
    return await future;
  } finally {
    if (kDebugMode) {
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      debugPrint('$prefix $label took ${elapsed}ms');
    }
  }
}
