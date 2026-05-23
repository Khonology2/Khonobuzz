import 'package:flutter/foundation.dart';

/// Primary Sentry DSN — `--dart-define=FRONTEND_DSN=...` (legacy: SENTRY_DSN).
const String _frontendDsn = String.fromEnvironment(
  'FRONTEND_DSN',
  defaultValue: '',
);

/// Legacy dart-define name kept for backward compatibility.
const String _legacySentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue: '',
);

String get sentryDsn {
  if (_runtimeSentryDsn != null && _runtimeSentryDsn!.isNotEmpty) {
    return _runtimeSentryDsn!;
  }
  return compileTimeSentryDsn;
}

/// DSN from `--dart-define=FRONTEND_DSN` / `SENTRY_DSN` only (no runtime file).
String get compileTimeSentryDsn =>
    _frontendDsn.isNotEmpty ? _frontendDsn : _legacySentryDsn;

String? _runtimeSentryDsn;

/// Set after [resolveSentryDsn] loads `build/web/sentry-config.json` on web.
void setRuntimeSentryDsn(String dsn) {
  _runtimeSentryDsn = dsn.trim().isEmpty ? null : dsn.trim();
}

/// Optional override for Sentry environment label.
const String sentryEnvironmentOverride = String.fromEnvironment(
  'SENTRY_ENV',
  defaultValue: '',
);

/// True when a DSN is configured at build/run time.
bool get sentryEnabled => sentryDsn.isNotEmpty;

String get sentryEnvironment {
  if (sentryEnvironmentOverride.isNotEmpty) {
    return sentryEnvironmentOverride;
  }
  return kDebugMode ? 'development' : 'production';
}

const String _sentryTracesSampleRateRaw = String.fromEnvironment(
  'SENTRY_TRACES_SAMPLE_RATE',
  defaultValue: '0.1',
);
double get sentryTracesSampleRate =>
    double.tryParse(_sentryTracesSampleRateRaw) ?? 0.1;

/// Release string passed to Sentry — ties every error and replay
/// session to a specific build. Set via CI:
/// `--dart-define=SENTRY_RELEASE=khonobuzz-frontend@sha`
const String sentryRelease = String.fromEnvironment(
  'SENTRY_RELEASE',
  defaultValue: 'khonobuzz-frontend@1.0.0+1',
);

/// Session Replay — percentage of normal sessions recorded (0.0–1.0).
/// Override via `--dart-define=SENTRY_REPLAY_SESSION_RATE=0.1`
const String _sentryReplaySessionRateRaw = String.fromEnvironment(
  'SENTRY_REPLAY_SESSION_RATE',
  defaultValue: '0.1',
);
double get sentryReplaySessionRate =>
    double.tryParse(_sentryReplaySessionRateRaw) ?? 0.1;

/// Session Replay — percentage of error sessions recorded (0.0–1.0).
/// Keep at 1.0 so every crash has a full replay attached.
const String _sentryReplayOnErrorRateRaw = String.fromEnvironment(
  'SENTRY_REPLAY_ON_ERROR_RATE',
  defaultValue: '1.0',
);
double get sentryReplayOnErrorRate =>
    double.tryParse(_sentryReplayOnErrorRateRaw) ?? 1.0;
