import 'dart:developer' as developer;

/// App-wide logger that uses [developer.log] instead of [print].
void appLog(Object? message, {Object? error, StackTrace? stackTrace}) {
  developer.log(
    message.toString(),
    name: 'flashbill',
    error: error,
    stackTrace: stackTrace,
  );
}
