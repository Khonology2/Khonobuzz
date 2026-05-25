export 'env.dart';

import 'env.dart';

/// Back-compat alias — prefer [env.dart] and [sentryEnabled].
@Deprecated('Use env.dart (sentryDsn, sentryEnabled) instead')
class SentryConfig {
  static String get dsn => sentryDsn;
  static bool get enabled => sentryEnabled;
  static String get environment => sentryEnvironment;
  static double get tracesSampleRate => sentryTracesSampleRate;
  static String get release => sentryRelease;
}
