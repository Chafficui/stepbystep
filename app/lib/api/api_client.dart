import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// HTTP-Fehler mit Statuscode und Server-Fehlermeldung.
class ApiException implements Exception {
  ApiException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => 'ApiException($status): $message';
}

/// 401 — Sitzung ungültig; UI führt zurück zum Join-Screen
/// (lokale Daten werden NICHT gelöscht).
class AuthException extends ApiException {
  AuthException(String message) : super(401, message);
}

/// Antwort der Join-Route.
class JoinResult {
  JoinResult({
    required this.token,
    required this.teamId,
    required this.teamName,
    required this.displayName,
  });

  factory JoinResult.fromJson(Map<String, dynamic> json) => JoinResult(
        token: json['token'] as String,
        teamId: json['team_id'] as String,
        teamName: json['team_name'] as String,
        displayName: json['display_name'] as String,
      );

  final String token;
  final String teamId;
  final String teamName;
  final String displayName;
}

/// Antwort von `GET /api/me`.
class MeResult {
  MeResult({
    required this.teamId,
    required this.teamName,
    required this.teamStatus,
    required this.displayName,
  });

  factory MeResult.fromJson(Map<String, dynamic> json) => MeResult(
        teamId: json['team_id'] as String,
        teamName: json['team_name'] as String,
        teamStatus: json['team_status'] as String,
        displayName: json['display_name'] as String,
      );

  final String teamId;
  final String teamName;
  final String teamStatus;
  final String displayName;
}

/// Antwort von `GET /api/my-rank`.
class RankResult {
  RankResult({this.rank, this.teamCount, this.computedAt});

  factory RankResult.fromJson(Map<String, dynamic> json) => RankResult(
        rank: (json['rank'] as num?)?.toInt(),
        teamCount: (json['team_count'] as num?)?.toInt(),
        computedAt: json['computed_at'] == null
            ? null
            : DateTime.parse(json['computed_at'] as String).toUtc(),
      );

  final int? rank;
  final int? teamCount;
  final DateTime? computedAt;
}

/// Dünner HTTP-Client für die Participant-API.
///
/// Loggt NIEMALS Tokens oder Authorization-Header.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? ApiConfig.base;

  final http.Client _client;
  final String baseUrl;

  /// Standard-Optionen inkl. Bearer-Header (wenn Token vorhanden).
  /// Ein zentraler Einstiegspunkt, damit kein Aufruf den Header vergisst.
  Map<String, String> options({String? token}) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body;
    Map<String, dynamic> json;
    try {
      json = jsonDecode(body.isEmpty ? '{}' : body) as Map<String, dynamic>;
    } on FormatException {
      json = const {};
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }
    final message = (json['error'] as String?) ?? 'Unbekanter Serverfehler';
    if (response.statusCode == 401) throw AuthException(message);
    throw ApiException(response.statusCode, message);
  }

  Future<Map<String, dynamic>> _get(
    String path,
    String? token,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response =
          await _client.get(uri, headers: options(token: token));
      return _decode(response);
    } on SocketException catch (e) {
      throw ApiException(0, 'Keine Verbindung zum Server (${e.message})');
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    String? token,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = options(token: token)
      ..['Content-Type'] = 'application/json';
    try {
      final response = await _client.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
      return _decode(response);
    } on SocketException catch (e) {
      throw ApiException(0, 'Keine Verbindung zum Server (${e.message})');
    }
  }

  /// `POST /api/join` — ohne Auth (Code + Name reichen).
  Future<JoinResult> join({
    required String code,
    required String displayName,
    required String deviceId,
  }) async {
    final json = await _postJson('/api/join', null, {
      'code': code,
      'display_name': displayName,
      'device_id': deviceId,
    });
    return JoinResult.fromJson(json);
  }

  /// `GET /api/event`
  Future<Map<String, dynamic>> getEvent(String? token) =>
      _get('/api/event', token);

  /// `GET /api/me`
  Future<MeResult> getMe(String token) async {
    return MeResult.fromJson(await _get('/api/me', token));
  }

  /// `GET /api/my-rank`
  Future<RankResult> getMyRank(String token) async {
    return RankResult.fromJson(await _get('/api/my-rank', token));
  }

  /// `POST /api/points/batch` — max. 200 Punkte pro Aufruf.
  Future<List<String>> postPointsBatch(
    String token,
    List<Map<String, dynamic>> points,
  ) async {
    assert(points.length <= 200, 'Batch darf max. 200 Punkte enthalten');
    final json = await _postJson('/api/points/batch', token, {
      'points': points,
    });
    final accepted = json['accepted'] as List<dynamic>? ?? const [];
    return accepted.cast<String>();
  }

  /// `POST /api/alerts` — idempotent (id entscheidet).
  Future<void> postAlert(
    String token, {
    required String id,
    required String type, // 'sos' | 'abort'
    required double lat,
    required double lng,
    required DateTime createdAt,
  }) async {
    await _postJson('/api/alerts', token, {
      'id': id,
      'type': type,
      'lat': lat,
      'lng': lng,
      'created_at': createdAt.toUtc().toIso8601String(),
    });
  }

  /// `POST /api/checkins` — multipart/form-data, idempotent.
  Future<void> postCheckin(
    String token, {
    required String id,
    required DateTime capturedAt,
    required String mediaType, // 'photo' | 'video'
    required String filePath,
  }) async {
    final uri = Uri.parse('$baseUrl/api/checkins');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(options(token: token))
      ..fields['id'] = id
      ..fields['captured_at'] = capturedAt.toUtc().toIso8601String()
      ..fields['media_type'] = mediaType
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    try {
      final response =
          await http.Response.fromStream(await _client.send(request));
      _decode(response);
    } on SocketException catch (e) {
      throw ApiException(0, 'Keine Verbindung zum Server (${e.message})');
    }
  }

  void close() => _client.close();
}
