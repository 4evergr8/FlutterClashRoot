import 'dart:io';
import 'package:yaml_codec/yaml_codec.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

dynamic _convertYaml(dynamic node) {
  if (node is YamlMap) {
    return Map<String, dynamic>.fromEntries(node.entries.map((e) => MapEntry(e.key.toString(), _convertYaml(e.value))));
  } else if (node is YamlList) {
    return node.map(_convertYaml).toList();
  }
  return node;
}

/// 读取 YAML 文件为 Map，顶层必须是 Map，否则报错
Future<Map<String, dynamic>> readYamlAsMap(String sourcePath) async {
  final dir = await getApplicationDocumentsDirectory();
  final localPath = join(dir.path, basename(sourcePath));

  final result = await Process.run('su', ['-c', 'cp $sourcePath $localPath && chmod 777 $localPath']);
  if (result.exitCode != 0) throw Exception(result.stderr);

  final text = await File(localPath).readAsString();
  final obj = YamlCodec().decode(text);

  final converted = _convertYaml(obj);
  if (converted is! Map<String, dynamic>) {
    throw Exception('YAML 顶层不是 Map，无法处理: $sourcePath');
  }
  return converted;
}

/// 写 Map 回 YAML 文件
Future<void> writeYamlFromMap(Map<String, dynamic> data, String targetPath) async {
  final dir = await getApplicationDocumentsDirectory();
  final localPath = join(dir.path, basename(targetPath));

  final yamlText = YamlCodec().encode(data);
  await File(localPath).writeAsString(yamlText);

  final result = await Process.run('su', ['-c', 'cp $localPath $targetPath && chmod 777 $targetPath']);
  if (result.exitCode != 0) throw Exception(result.stderr);
}

/// 顶层覆盖 Map：patch 的值覆盖 base 的同名 key
Map<String, dynamic> overrideMap(Map<String, dynamic> base, Map<String, dynamic> override) {
  final result = Map<String, dynamic>.from(base); // 拷贝一份 base
  override.forEach((key, value) {
    result[key] = value; // 顶层覆盖
  });
  return result;
}

/// 下载 YAML 文件并保存到 /data/adb/mihomo
Future<Map<String, dynamic>> downloadYamlFile(String url, String ua, String id, int timeout) async {
  final dio = Dio();
  final dir = await getApplicationDocumentsDirectory();
  final filePath = '${dir.path}/$id.yaml';

  try {
    final response = await dio.download(url, filePath, options: Options(responseType: ResponseType.bytes, followRedirects: true, headers: {'User-Agent': ua}, connectTimeout: Duration(milliseconds: timeout), sendTimeout: Duration(milliseconds: timeout), receiveTimeout: Duration(milliseconds: timeout)));

    final headers = response.headers.map;
    String label = id;

    final cd = headers['content-disposition']?.first;
    if (cd != null) {
      final fileNameStar = RegExp(r"filename\*\s*=\s*([^;]+)").firstMatch(cd)?.group(1);
      if (fileNameStar != null) {
        final parts = fileNameStar.split("''");
        if (parts.length == 2) {
          try {
            label = Uri.decodeComponent(parts[1]);
          } catch (_) {}
        }
      }

      final fileName = RegExp(r'filename="?([^"]+)"?').firstMatch(cd)?.group(1);
      if (fileName != null && fileName.isNotEmpty) label = fileName;
    }

    int upload = 0, downloadBytes = 0, total = 0, expire = 0;

    final userInfoRaw = headers['subscription-userinfo']?.first;
    if (userInfoRaw != null && userInfoRaw.isNotEmpty) {
      final parts = userInfoRaw.split(';');

      for (final p in parts) {
        final kv = p.split('=');
        if (kv.length != 2) continue;
        final key = kv[0].trim();
        final value = int.tryParse(kv[1].trim()) ?? 0;

        switch (key) {
          case 'upload':
            upload = value;
            break;
          case 'download':
            downloadBytes = value;
            break;
          case 'total':
            total = value;
            break;
          case 'expire':
            expire = value;
            break;
        }
      }
    }

    final file = File(filePath);
    final text = await file.readAsString();

    dynamic obj;
    try {
      obj = const YamlCodec().decode(text);
    } catch (e) {
      throw Exception('YAML 解析失败: $e');
    }

    final converted = _convertYaml(obj);

    if (converted is! Map<String, dynamic>) {
      throw Exception('不是有效配置');
    }

    final result = await Process.run('su', ['-c', 'cp $filePath /data/adb/modules/mihomoR/config/$id.yaml']);

    if (result.exitCode != 0) {
      throw Exception('root 拷贝失败: ${result.stderr}');
    }

    return {'id': id, 'link': url, 'label': label, 'upload': upload, 'download': downloadBytes, 'total': total, 'expire': expire, 'update': DateTime.now().millisecondsSinceEpoch.toString()};
  } catch (e) {
    final f = File(filePath);
    if (await f.exists()) {
      await f.delete();
    }
    rethrow;
  }
}
