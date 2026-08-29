import 'dart:convert';

import 'package:http/http.dart' as http;

import 'bootstrap_manifest.dart';

/// 从公民网读取非权威 bootnode 建议；链状态真源始终是 P2P finalized storage。
final class BootstrapClient {
  BootstrapClient({
    String? baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 6),
  }) : baseUrl = _normalizeBaseUrl(baseUrl ?? defaultBaseUrl),
       _http = httpClient;

  static const environmentDefine = 'CITIZEN_SDK_BOOTSTRAP_URL';
  static const productionBaseUrl = 'https://www.crcfrcn.com/api';
  static const _configuredBaseUrl = String.fromEnvironment(environmentDefine);

  static String get defaultBaseUrl => _configuredBaseUrl.trim().isEmpty
      ? productionBaseUrl
      : _configuredBaseUrl;

  final String baseUrl;
  final http.Client? _http;
  final Duration timeout;

  Future<BootstrapManifest> fetch() async {
    final client = _http ?? http.Client();
    try {
      final response = await client
          .get(
            Uri.parse('$baseUrl/chain/citizensdk/bootstrap'),
            headers: const <String, String>{'accept': 'application/json'},
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw BootstrapManifestException(
          '公民链启动清单读取失败：HTTP ${response.statusCode}',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const BootstrapManifestException('公民链启动清单不是 JSON 对象');
      }
      return BootstrapManifest.fromJson(decoded);
    } finally {
      if (_http == null) client.close();
    }
  }

  /// 只关闭调用方显式注入的 HTTP client；默认 client 每次 fetch 自动释放。
  void close() => _http?.close();

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError.value(value, 'baseUrl', '必须是完整 URL');
    }
    final localHttp =
        uri.scheme == 'http' &&
        (uri.host == '127.0.0.1' ||
            uri.host == 'localhost' ||
            uri.host == '::1');
    if (uri.scheme != 'https' && !localHttp) {
      throw ArgumentError.value(value, 'baseUrl', '只允许 HTTPS 或本机调试 HTTP');
    }
    return trimmed;
  }
}
