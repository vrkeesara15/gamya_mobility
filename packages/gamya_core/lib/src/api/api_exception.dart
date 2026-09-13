class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.details});
  final String message;
  final int? statusCode;
  final dynamic details;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNetwork => statusCode == null;

  @override
  String toString() => message;
}
