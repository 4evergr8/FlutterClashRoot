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
  final result = await Process.run("su", ["-c", "sh", scriptPath, "kill"]);
  return (result.stdout.toString() + result.stderr.toString()).trim();
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
  final result = await Process.run("su", ["-c", "sh", scriptPath, "start"]);
  return (result.stdout.toString() + result.stderr.toString()).trim();
}

Future<String> clashTest() async {
  final result = await Process.run("su", ["-c", "sh", scriptPath, "test"]);
  return (result.stdout.toString() + result.stderr.toString()).trim();
}

Future<String> clashCheck() async {
  final result = await Process.run("su", ["-c", "sh", scriptPath, "check"]);
  return (result.stdout.toString() + result.stderr.toString()).trim();
}
