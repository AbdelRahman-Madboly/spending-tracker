import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/online_features.dart';
import '../../domain/spending_repository.dart';

/// Thrown by [NetworkGate] when [feature] is not switched on: either the
/// master online switch or the feature's own switch is off.
class NetworkDisabled implements Exception {
  const NetworkDisabled(this.feature);

  final OnlineFeature feature;

  @override
  String toString() => 'NetworkDisabled: ${feature.name}';
}

/// A response as the callers read it: the status and the body as UTF-8.
/// A record rather than `http.Response`, so no file but this one ever
/// needs `package:http`.
typedef GateResponse = ({int statusCode, String body});

/// The one way out to the network (spec §9.2).
///
/// This is the only file allowed to import `package:http` or build a
/// client; a test scans `lib/` for any other. Every request names the
/// [OnlineFeature] it serves and is refused with [NetworkDisabled] unless
/// both the master switch and that feature's switch are on, which is
/// checked before a client is even built. Requests carry a timeout, and
/// nothing here logs a request body, a header or a key.
class NetworkGate {
  NetworkGate(
    this._repository, {
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 10),
  }) : _clientFactory = clientFactory ?? http.Client.new;

  final SpendingRepository _repository;
  final http.Client Function() _clientFactory;

  /// How long a request may take, the body included, unless the call
  /// gives its own.
  final Duration timeout;

  /// Sends [request] for [feature]. A client is built for this request and
  /// closed after it, so a timed-out request is abandoned with it.
  Future<http.Response> send(OnlineFeature feature, http.BaseRequest request,
      {Duration? timeout}) async {
    if (!await isOnlineFeatureOn(_repository, feature)) {
      throw NetworkDisabled(feature);
    }
    final client = _clientFactory();
    try {
      return await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout ?? this.timeout);
    } finally {
      client.close();
    }
  }

  /// A GET of [uri] for [feature], for callers that must not import
  /// `package:http` themselves.
  Future<GateResponse> get(OnlineFeature feature, Uri uri,
      {Map<String, String> headers = const {}, Duration? timeout}) async {
    final request = http.Request('GET', uri)..headers.addAll(headers);
    final response = await send(feature, request, timeout: timeout);
    return (
      statusCode: response.statusCode,
      body: utf8.decode(response.bodyBytes, allowMalformed: true),
    );
  }

  /// A POST of [body] (sent as UTF-8) to [uri] for [feature], for the same
  /// callers. The body is never logged: a smart request carries the user's
  /// notes, and its headers carry the key.
  Future<GateResponse> post(OnlineFeature feature, Uri uri,
      {Map<String, String> headers = const {},
      required String body,
      Duration? timeout}) async {
    final request = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..bodyBytes = utf8.encode(body);
    final response = await send(feature, request, timeout: timeout);
    return (
      statusCode: response.statusCode,
      body: utf8.decode(response.bodyBytes, allowMalformed: true),
    );
  }
}
