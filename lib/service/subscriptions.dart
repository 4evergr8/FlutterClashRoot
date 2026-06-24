import 'dart:convert';

import 'package:clashroot/service/path.dart';
import 'package:clashroot/service/yaml.dart';
import 'package:clashroot/widget.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

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
    final data = await yamlRead(subscriptionsPath);
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
  final settings = await yamlRead(settingsPath);
  final port = settings['port'];
  final base = await yamlRead("$mainPath/config/$id.yaml");
  final override = await yamlRead(overridePath);
  final yaml = overrideMap(base, override);
  await yamlWrite(yaml, configPath);
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
  final settings = await yamlRead(settingsPath);

  final ua = settings['ua'];
  final timeout = settings['timeout'];

  final Map<String, Map<String, dynamic>> resultMap = {for (var s in input) s['id']: Map<String, dynamic>.from(s)};

  final futures =
      input.map((sub) async {
        final id = sub['id'];
        try {
          final downloadResult = await yamlDownload(sub['link'], ua, id, timeout);
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
  final settings = await yamlRead(settingsPath);
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
          return await yamlDownload(canonicalUrl(link), ua, sha256Prefix(link), timeout);
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
