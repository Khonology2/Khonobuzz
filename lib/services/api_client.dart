import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/env.dart';

/// Central HTTP client with Sentry performance spans and error capture.
class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Wraps an HTTP call in a Sentry performance span and captures
  /// any exception. Falls back to calling [call] directly when
  /// Sentry is disabled so behaviour is identical without a DSN.
  Future<T> _traced<T>(
    String operation,
    String description,
    Future<T> Function() call,
  ) async {
    if (!sentryEnabled) return call();
    final transaction = Sentry.getSpan();
    final span = transaction?.startChild(
      operation,
      description: description,
    );
    try {
      final result = await call();
      span?.status = const SpanStatus.ok();
      await Sentry.addBreadcrumb(Breadcrumb(
        message: description,
        category: 'http',
        level: SentryLevel.info,
        type: 'http',
      ));
      return result;
    } catch (e, stack) {
      span?.status = const SpanStatus.internalError();
      span?.throwable = e;
      await Sentry.addBreadcrumb(Breadcrumb(
        message: '$description — FAILED',
        category: 'http',
        level: SentryLevel.error,
        type: 'http',
        data: {'error': e.toString()},
      ));
      await Sentry.captureException(e, stackTrace: stack);
      rethrow;
    } finally {
      await span?.finish();
    }
  }

  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) {
    return _traced('http.get', 'GET ${url.path}', () async {
      return _client.get(url, headers: headers);
    });
  }

  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _traced('http.post', 'POST ${url.path}', () async {
      return _client.post(url, headers: headers, body: body, encoding: encoding);
    });
  }

  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _traced('http.put', 'PUT ${url.path}', () async {
      return _client.put(url, headers: headers, body: body, encoding: encoding);
    });
  }

  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _traced('http.patch', 'PATCH ${url.path}', () async {
      return _client.patch(url, headers: headers, body: body, encoding: encoding);
    });
  }

  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) {
    return _traced('http.delete', 'DELETE ${url.path}', () async {
      return _client.delete(url, headers: headers, body: body, encoding: encoding);
    });
  }

  void close() => _client.close();
}

/// Shared singleton for services that opt into traced HTTP.
final apiClient = ApiClient();
