import 'dart:convert';
import 'dart:io';

import '../../core/failure.dart';
import '../../core/logger.dart';

/// 上传结果。
class UploadResult {
  const UploadResult({required this.fileId, required this.url});

  final String fileId;
  final String url;
}

/// 分片上传器（纯 Dart 实现，不依赖三方库）。
///
/// 与后端约定的最小协议：
/// ```
/// POST {baseUrl}/init      body {name, size, chunkSize} -> {uploadId}
/// PUT  {baseUrl}/chunk     query {uploadId, index}  body 原始字节 -> 204
/// POST {baseUrl}/complete  body {uploadId, chunks}      -> {fileId, url}
/// ```
/// 断点续传：`init` 若返回 `uploadedChunks: [int]`，则跳过这些分片。
class ChunkedUploader {
  ChunkedUploader({
    required this.baseUrl,
    this.chunkSize = 1 << 20,
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  final String baseUrl;
  final int chunkSize;
  final HttpClient _client;

  Future<UploadResult> upload(
    File file, {
    required String fileName,
    void Function(double progress)? onProgress,
    Map<String, String>? headers,
  }) async {
    final int total = await file.length();
    if (total <= 0) {
      throw const NetworkFailure('文件为空，无法上传');
    }

    final Map<String, dynamic> initResult = await _requestJson(
      'POST',
      '/init',
      <String, dynamic>{
        'name': fileName,
        'size': total,
        'chunkSize': chunkSize,
      },
      headers,
    );
    final String uploadId = initResult['uploadId'] as String;
    final Set<int> uploaded = (initResult['uploadedChunks'] as List<dynamic>? ??
            <dynamic>[])
        .map((dynamic e) => e as int)
        .toSet();

    final int chunkCount = (total / chunkSize).ceil();
    final RandomAccessFile raf = await file.open();
    try {
      for (int index = 0; index < chunkCount; index++) {
        if (uploaded.contains(index)) {
          onProgress?.call((index + 1) / chunkCount);
          continue;
        }
        await raf.setPosition(index * chunkSize);
        final List<int> bytes = await raf.read(chunkSize);
        await _putChunk(uploadId, index, bytes, headers);
        onProgress?.call((index + 1) / chunkCount);
      }
    } finally {
      await raf.close();
    }

    final Map<String, dynamic> done = await _requestJson(
      'POST',
      '/complete',
      <String, dynamic>{'uploadId': uploadId, 'chunks': chunkCount},
      headers,
    );
    AppLog.i('ChunkedUploader', '上传完成 $fileName -> ${done['url']}');
    return UploadResult(
      fileId: done['fileId'] as String? ?? uploadId,
      url: done['url'] as String? ?? '',
    );
  }

  Future<void> _putChunk(
    String uploadId,
    int index,
    List<int> bytes,
    Map<String, String>? headers,
  ) async {
    final Uri uri = Uri.parse('$baseUrl/chunk')
        .replace(queryParameters: <String, String>{
      'uploadId': uploadId,
      'index': '$index',
    });
    final HttpClientRequest request = await _client.putUrl(uri);
    _applyHeaders(request, headers);
    request.headers.contentType = ContentType.binary;
    request.add(bytes);
    final HttpClientResponse response = await request.close();
    await response.drain<void>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NetworkFailure(
        '分片上传失败：index=$index',
        statusCode: response.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    String path,
    Map<String, dynamic> body,
    Map<String, String>? headers,
  ) async {
    final HttpClientRequest request =
        await _client.openUrl(method, Uri.parse('$baseUrl$path'));
    _applyHeaders(request, headers);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final HttpClientResponse response = await request.close();
    final String text = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw NetworkFailure(
        '上传接口失败：$path ${response.reasonPhrase}',
        statusCode: response.statusCode,
        cause: text,
      );
    }
    if (text.isEmpty) {
      return <String, dynamic>{};
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  void _applyHeaders(HttpClientRequest request, Map<String, String>? headers) {
    headers?.forEach((String key, String value) {
      request.headers.set(key, value);
    });
  }

  void close() => _client.close(force: true);
}
