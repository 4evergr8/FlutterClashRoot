import 'dart:io';

import 'package:clashroot/service/path.dart';
import 'package:quick_settings_with_flutter_plugins/quick_settings.dart';
import 'package:workmanager/workmanager.dart';

Future<String> clashKill() async {
  final result = await Process.run("su", ["-c", "sh", scriptPath, "kill"]);

  final code = result.exitCode;
  final output = result.stdout.toString();
  final error = result.stderr.toString();

  if (code != 0) {
    throw Exception("FAIL\n$output\n$error");
  }
  Workmanager().cancelAll();
  await QuickSettings.syncTile(
    Tile(
      label: "ClashRoot",
      tileStatus: TileStatus.inactive,
      drawableName: 'alarm_off',
      contentDescription: "Clash核心已停止",
    ),
  );
  return "OK\n$output";
}

Future<String> clashStart() async {
  final result = await Process.run("su", ["-c", "sh", scriptPath, "start"]);

  final code = result.exitCode;
  final output = result.stdout.toString();
  final error = result.stderr.toString();

  if (code != 0) {
    throw Exception("FAIL\n$output\n$error");
  }
  await QuickSettings.syncTile(
    Tile(
      label: "ClashRoot",
      tileStatus: TileStatus.active,
      drawableName: 'alarm_on',
      contentDescription: "Clash核心已启动",
    ),
  );
  return "OK\n$output";
}

Future<String> clashTest() async {
  final result = await Process.run("su", ["-c", "sh", scriptPath, "test"]);

  final code = result.exitCode;
  final output = result.stdout.toString();
  final error = result.stderr.toString();

  return "code=$code\n$output\n$error".trim();
}

Future<String> clashCheck() async {
  final result = await Process.run("su", ["-c", "sh", scriptPath, "check"]);

  final code = result.exitCode;
  final output = result.stdout.toString();
  final error = result.stderr.toString();

  return "code=$code\n$output\n$error".trim();
}
