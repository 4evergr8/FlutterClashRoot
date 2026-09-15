import 'dart:io';

import 'package:clashroot/service/path.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_codec/yaml_codec.dart';

Map<String, dynamic> overrideMap(Map<String, dynamic> base, Map<String, dynamic> override) {
  final result = Map<String, dynamic>.from(base); // 拷贝一份 base
  override.forEach((key, value) {
    result[key] = value; // 顶层覆盖
  });
  return result;
}

dynamic _convertYaml(dynamic node) {
  // 1. YamlMap → 强制 Map<String, dynamic>
  if (node is YamlMap) {
    final map = <String, dynamic>{};
    node.forEach((key, value) {
      map[key.toString()] = _convertYaml(value);
    });
    return map;
  }

  // 2. YamlList → List<dynamic>
  if (node is YamlList) {
    return node.map((e) => _convertYaml(e)).toList();
  }

  // 3. 普通 Map（关键修复点：防止 _Map<dynamic, dynamic> 漏网）
  if (node is Map) {
    final map = <String, dynamic>{};
    node.forEach((key, value) {
      map[key.toString()] = _convertYaml(value);
    });
    return map;
  }

  // 4. 普通 List（防止 yaml_codec 返回的 List<dynamic>）
  if (node is List) {
    return node.map((e) => _convertYaml(e)).toList();
  }

  return node;
}

/// 读取 YAML 文件为 Map<String, dynamic>
Future<Map<String, dynamic>> yamlRead(String sourcePath) async {
  final dir = await getApplicationDocumentsDirectory();
  final localPath = join(dir.path, basename(sourcePath));

  final result = await Process.run('su', ['-c', 'cp $sourcePath $localPath && chmod 777 $localPath']);

  if (result.exitCode != 0) {
    throw Exception(result.stderr);
  }

  final text = await File(localPath).readAsString();

  final obj = YamlCodec().decode(text);

  final converted = _convertYaml(obj);

  if (converted is! Map<String, dynamic>) {
    throw Exception('YAML 顶层不是 Map，无法处理: $sourcePath');
  }

  return converted;
}

/// 写 Map 回 YAML 文件
Future<void> yamlWrite(Map<String, dynamic> data, String targetPath) async {
  final dir = await getApplicationDocumentsDirectory();
  final localPath = join(dir.path, basename(targetPath));

  final yamlText = YamlCodec().encode(data);
  await File(localPath).writeAsString(yamlText);

  final result = await Process.run('su', ['-c', 'cp $localPath $targetPath && chmod 777 $targetPath']);
  if (result.exitCode != 0) throw Exception(result.stderr);
}

/// 批量读取订阅配置文件的修改时间（毫秒）
///
/// 文件不存在或读取失败的条目记为 0。
/// 由于 /data/adb 对 App 不可见，必须借助 su 执行 stat；
/// 为避免每个订阅启动一次 su 进程，这里按批合并成一次调用。
Future<Map<String, int>> fileModifiedMs(List<String> ids) async {
  final result = <String, int>{for (final id in ids) id: 0};
  if (ids.isEmpty) return result;

  const int batchSize = 30;

  for (var start = 0; start < ids.length; start += batchSize) {
    final batch = ids.skip(start).take(batchSize).toList();
    final paths = batch.map((id) => "'$mainPath/config/$id.yaml'").join(' ');

    // 个别文件缺失时 stat 返回非 0，但其余结果仍然有效，故只看 stdout
    final r = await Process.run('su', ['-c', 'stat -c "%n %Y" $paths']);

    for (final line in r.stdout.toString().split('\n')) {
      final text = line.trim();
      if (text.isEmpty) continue;

      final split = text.lastIndexOf(' ');
      if (split <= 0) continue;

      final seconds = int.tryParse(text.substring(split + 1).trim());
      if (seconds == null) continue;

      final name = basename(text.substring(0, split).trim());
      final id = name.endsWith('.yaml') ? name.substring(0, name.length - 5) : name;

      result[id] = seconds * 1000;
    }
  }

  return result;
}

Future<Map<String, dynamic>> yamlDownload(String url, String ua, String id, int timeout) async {
  final dio = Dio();
  final dir = await getApplicationDocumentsDirectory();
  final filePath = '${dir.path}/$id.yaml';

  try {
    final response = await dio.download(
      url,
      filePath,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        headers: {'User-Agent': ua},
        connectTimeout: Duration(milliseconds: timeout),
        sendTimeout: Duration(milliseconds: timeout),
        receiveTimeout: Duration(milliseconds: timeout),
      ),
    );

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
      throw Exception(text);
    }

    final result = await Process.run('su', ['-c', 'cp $filePath $mainPath/config/$id.yaml']);

    if (result.exitCode != 0) {
      throw Exception('root 拷贝失败: ${result.stderr}');
    }

    return {
      'id': id,
      'link': url,
      'label': label,
      'upload': upload,
      'download': downloadBytes,
      'total': total,
      'expire': expire,
    };
  } catch (e) {
    final f = File(filePath);
    if (await f.exists()) {
      await f.delete();
    }
    rethrow;
  }
}
