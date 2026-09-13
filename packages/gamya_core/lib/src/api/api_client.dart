import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'api_exception.dart';
import 'auth_store.dart';
import '../models/models.dart';

/// Thin typed wrapper over the Gamya REST API.
class ApiClient {
  ApiClient({required String baseUrl, required this.auth, this.onUnauthorized}) : _dio = Dio(BaseOptions(baseUrl: baseUrl, connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(seconds: 60), headers: {'accept': 'application/json'})) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) {
        final t = auth.token;
        if (t != null) o.headers['authorization'] = 'Bearer $t';
        h.next(o);
      },
      onError: (e, h) {
        if (e.response?.statusCode == 401 && auth.isLoggedIn) onUnauthorized?.call();
        h.next(e);
      },
    ));
  }

  final Dio _dio;
  final AuthStore auth;
  final void Function()? onUnauthorized;

  String get baseUrl => _dio.options.baseUrl;
  set baseUrl(String v) => _dio.options.baseUrl = v;

  /// Resolves relative upload URLs returned by the API against the API host.
  String resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    final host = Uri.parse(baseUrl);
    return '${host.scheme}://${host.host}${host.hasPort ? ':${host.port}' : ''}$url';
  }

  Future<Json> _unwrap(Future<Response<dynamic>> f) async {
    try {
      final r = await f;
      final d = r.data;
      if (d is Json) return d;
      return {'success': true, 'data': d};
    } on DioException catch (e) {
      final data = e.response?.data;
      String msg = e.message ?? 'Network error';
      dynamic details;
      if (data is Json) {
        msg = (data['message'] as String?) ?? msg;
        details = data['details'];
        final flat = details is Json ? details['fieldErrors'] : null;
        if (flat is Json && flat.isNotEmpty) {
          final first = flat.entries.first;
          final v = first.value;
          if (v is List && v.isNotEmpty) msg = '${first.key}: ${v.first}';
        }
      } else if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
        msg = 'Cannot reach the server. Check your connection.';
      }
      throw ApiException(msg, statusCode: e.response?.statusCode, details: details);
    }
  }

  Future<Json> get(String path, {Json? query}) async => _unwrap(_dio.get(path, queryParameters: _clean(query)));
  Future<Json> post(String path, {Object? body, Json? query}) async => _unwrap(_dio.post(path, data: body, queryParameters: _clean(query)));
  Future<Json> put(String path, {Object? body}) async => _unwrap(_dio.put(path, data: body));
  Future<Json> patch(String path, {Object? body}) async => _unwrap(_dio.patch(path, data: body));
  Future<Json> delete(String path) async => _unwrap(_dio.delete(path));

  Future<Json> upload(String path, {required Map<String, List<UploadFile>> files, Map<String, String>? fields}) async {
    final form = FormData();
    fields?.forEach((k, v) => form.fields.add(MapEntry(k, v)));
    files.forEach((field, list) {
      for (final f in list) {
        form.files.add(MapEntry(field, MultipartFile.fromBytes(f.bytes, filename: f.name, contentType: f.mediaType)));
      }
    });
    return _unwrap(_dio.post(path, data: form));
  }

  Future<String> getText(String path, {Json? query}) async {
    try {
      final r = await _dio.get<String>(path, queryParameters: _clean(query), options: Options(responseType: ResponseType.plain));
      return r.data ?? '';
    } on DioException catch (e) {
      throw ApiException(e.message ?? 'Download failed', statusCode: e.response?.statusCode);
    }
  }

  Json? _clean(Json? q) {
    if (q == null) return null;
    final out = <String, dynamic>{};
    q.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      out[k] = v;
    });
    return out;
  }

  // ─────────── convenience: paging ───────────
  Future<Paged<T>> paged<T>(String path, T Function(Json) parse, {Json? query}) async {
    final r = await get(path, query: query);
    return Paged.fromJson(r['data'] as Json, parse);
  }

  Json data(Json r) => (r['data'] as Json?) ?? const {};
  List<Json> list(Json r) => ((r['data'] as List?) ?? const []).cast<Json>();
}

class UploadFile {
  UploadFile({required this.name, required this.bytes, this.mediaType});
  final String name;
  final Uint8List bytes;
  final DioMediaType? mediaType;
}
