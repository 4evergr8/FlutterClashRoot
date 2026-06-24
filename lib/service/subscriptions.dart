import 'dart:convert';
import 'dart:io';

import 'package:clashroot/service/path.dart';
import 'package:clashroot/widget.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_codec/yaml_codec.dart';

dynamic _convertYaml(dynamic node) {
  if (node is YamlMap) {
    return Map<String, dynamic>.fromEntries(
      node.entries.map((e) => MapEntry(e.key.toString(), _convertYaml(e.value))),
    );
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

Future<Map<String, dynamic>> downloadYamlFile(String url, String ua, String id, int timeout) async {
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
      throw Exception('不是有效配置');
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
      'update': DateTime.now().millisecondsSinceEpoch.toString(),
    };
  } catch (e) {
    final f = File(filePath);
    if (await f.exists()) {
      await f.delete();
    }
    rethrow;
  }
}

String sha256Prefix(String input) {
  // 1. 转成字节
  final bytes = utf8.encode(input);

  // 2. 计算 SHA256
  final digest = sha256.convert(bytes);

  // 3. 转成十六进制字符串
  final hex = digest.toString();

  // 4. 返回前 length 个字符
  return hex.substring(0, 8);
}

String canonicalUrl(String input) {
  var uri = Uri.parse(input.trim());

  // 1. 统一 scheme + host 小写
  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();

  // 2. path 统一：空 → /
  String path = uri.path.isEmpty ? '/' : uri.path;

  // 3. 去掉末尾多余 /
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }

  // 4. query 不变（保留原语义）
  final query = uri.query;

  return Uri(scheme: scheme, host: host, path: path, query: query.isEmpty ? null : query).toString();
}

String formatTimeAgo(String timestampMsStr) {
  final pastMs = int.tryParse(timestampMsStr);
  if (pastMs == null) return '时间格式错误';
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  int seconds = (nowMs - pastMs) ~/ 1000;

  if (seconds <= 0) return '刚刚';

  const int secsPerMin = 60;
  const int secsPerHour = secsPerMin * 60;
  const int secsPerDay = secsPerHour * 24;
  const int secsPerMonth = secsPerDay * 30;
  const int secsPerYear = secsPerDay * 365;

  final years = seconds ~/ secsPerYear;
  seconds %= secsPerYear;
  final months = seconds ~/ secsPerMonth;
  seconds %= secsPerMonth;
  final days = seconds ~/ secsPerDay;
  seconds %= secsPerDay;
  final hours = seconds ~/ secsPerHour;
  seconds %= secsPerHour;
  final minutes = seconds ~/ secsPerMin;

  final List<String> parts = [];
  if (years > 0) parts.add('$years年');
  if (months > 0) parts.add('$months个月');
  if (days > 0) parts.add('$days天');
  if (hours > 0) parts.add('$hours小时');
  if (minutes > 0) parts.add('$minutes分');

  if (parts.isEmpty) return '刚刚';
  return '${parts.join()}前';
}

String formatSize(int bytes) {
  const mb = 1024 * 1024;
  const gb = mb * 1024;
  const tb = gb * 1024;

  final valueMB = bytes / mb;

  if (valueMB < 1024) {
    return '${valueMB.toStringAsFixed(1)}M';
  }

  final valueGB = bytes / gb;
  if (valueGB < 1024) {
    return '${valueGB.toStringAsFixed(1)}G';
  }

  final valueTB = bytes / tb;
  return '${valueTB.toStringAsFixed(1)}T';
}

Future<List<Map<String, dynamic>>> subscriptionsLoad([List<Map<String, dynamic>>? input]) async {
  List<Map<String, dynamic>> list;

  // 1. 有输入就直接用输入
  if (input != null) {
    list = input.map((e) => Map<String, dynamic>.from(e)).toList();
  } else {
    // 2. 没输入就从文件加载
    final data = await readYamlAsMap(subscriptionsPath);
    final raw = (data['subscriptions'] as List?) ?? [];
    list = List<Map<String, dynamic>>.from(raw);
  }

  // 3. 排序（统一逻辑）
  list.sort((a, b) {
    final aFav = a['favorite'] == true ? 0 : 1;
    final bFav = b['favorite'] == true ? 0 : 1;

    if (aFav != bFav) return aFav - bFav;

    final al = (a['label'] ?? '').toString();
    final bl = (b['label'] ?? '').toString();
    return al.compareTo(bl);
  });

  return list;
}

Future<void> subscriptionsSwitch(String id) async {
  final settings = await readYamlAsMap(settingsPath);
  final port = settings['port'];
  final base = await readYamlAsMap("$mainPath/config/$id.yaml");
  final override = await readYamlAsMap(overridePath);
  final yaml = overrideMap(base, override);
  await writeYamlFromMap(yaml, configPath);
  final dio = Dio();
  final params = {'force': 'true'};
  final data = {"path": configPath};
  await dio.put(
    'http://127.0.0.1:$port/configs',
    queryParameters: params,
    data: data,
    options: Options(headers: {'Content-Type': 'application/json'}),
  );
  await dio.delete(
    'http://127.0.0.1:$port/connections',
    options: Options(headers: {'Content-Type': 'application/json'}),
  );
}

Future<List<Map<String, dynamic>>> subscriptionsRefresh(List<Map<String, dynamic>> input) async {
  final settings = await readYamlAsMap(settingsPath);

  final ua = settings['ua'];
  final timeout = settings['timeout'];

  final Map<String, Map<String, dynamic>> resultMap = {for (var s in input) s['id']: Map<String, dynamic>.from(s)};

  final futures =
      input.map((sub) async {
        final id = sub['id'];
        try {
          final downloadResult = await downloadYamlFile(sub['link'], ua, id, timeout);
          return {'id': id, 'data': downloadResult};
        } catch (e) {
          showSnackBarGlobal("error", '${sub['label'] ?? id} 失败: $e');
          return null;
        }
      }).toList();

  final results = await Future.wait(futures);

  for (var r in results) {
    if (r == null) continue;

    final id = r['id'];
    final data = r['data'] as Map<String, dynamic>?;

    if (data == null) continue;

    final old = resultMap[id] ?? {};

    resultMap[id] = {
      ...old,

      // 只允许这些字段被刷新覆盖
      'expire': data['expire'] ?? old['expire'],
      'update': data['update'] ?? old['update'],
      'upload': data['upload'] ?? old['upload'],
      'download': data['download'] ?? old['download'],
      'total': data['total'] ?? old['total'],
    };
  }

  final newList = resultMap.values.toList();
  return newList;
}

Future<List<Map<String, dynamic>>> subscriptionsAdd(List<Map<String, dynamic>> subscriptions, String input) async {
  final settings = await readYamlAsMap(settingsPath);
  final ua = settings['ua'];
  final timeout = settings['timeout'];
  final list = subscriptions;

  final existingIds = list.map((e) => e['id']).toSet();

  final inputLinks = input.split('\n').map((e) => canonicalUrl(e)).where((e) => e.isNotEmpty).toList();

  final seen = <String>{};
  final links = <String>[];
  for (var l in inputLinks) {
    if (!seen.contains(l)) {
      seen.add(l);
      links.add(l);
    }
  }

  final newLinks = <String>[];

  for (var link in links) {
    final id = sha256Prefix(link);
    if (existingIds.contains(id)) {
    } else {
      newLinks.add(link);
    }
  }

  final futures =
      newLinks.map((link) async {
        try {
          return await downloadYamlFile(canonicalUrl(link), ua, sha256Prefix(link), timeout);
        } catch (e) {
          showSnackBarGlobal("error", '$link 添加失败: $e');
          return null;
        }
      }).toList();

  final results = await Future.wait(futures);

  for (var r in results) {
    if (r != null) {
      list.add(r);
    }
  }
  return list;
}
