import 'dart:convert';
import 'dart:io';

import 'package:clashroot/service/path.dart';
import 'package:quick_settings_with_flutter_plugins/quick_settings.dart';

Future<String> clashKill() async {
  await QuickSettings.syncTile(
    Tile(
      label: "ClashRoot",
      tileStatus: TileStatus.inactive,
      drawableName: 'alarm_off',
      contentDescription: "Clash核心已停止",
    ),
  );
  final process = await Process.start("su", ["-c", "sh", scriptPath, "kill"]);
  final results = await Future.wait([
    process.stdout.transform(utf8.decoder).join(),
    process.stderr.transform(utf8.decoder).join(),
  ]);
  final total = "${results[0]}\n${results[1]}";
  await process.exitCode;
  return total;
}

Future<String> clashStart() async {
  await QuickSettings.syncTile(
    Tile(
      label: "ClashRoot",
      tileStatus: TileStatus.active,
      drawableName: 'alarm_on',
      contentDescription: "Clash核心已启动",
    ),
  );
  final process = await Process.start("su", ["-c", "sh", scriptPath, "start"]);
  final results = await Future.wait([
    process.stdout.transform(utf8.decoder).join(),
    process.stderr.transform(utf8.decoder).join(),
  ]);
  final total = "${results[0]}\n${results[1]}";
  await process.exitCode;
  return total;
}

Future<String> clashTest() async {
  final result = await Process.run("su", ["-c", "sh", scriptPath, "test"]);
  return (result.stdout.toString() + result.stderr.toString()).trim();
}

Future<String> clashCheck() async {
  final result = await Process.run("su", ["-c", "sh", scriptPath, "check"]);
  return (result.stdout.toString() + result.stderr.toString()).trim();
}
