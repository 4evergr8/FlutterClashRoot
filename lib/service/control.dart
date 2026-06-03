import 'dart:io';

import 'package:mihomoR/service/path.dart' show scriptPath;


/// kill 分支
Future<String> stopMihomo() async {
  final result = await Process.run("sh", [scriptPath, "kill"]);
  return result.stdout.toString().trim() + result.stderr.toString();
}

/// start 分支
Future<String> startMihomo() async {
  await Process.run("sh", [scriptPath, "kill"]);
  final result = await Process.run("sh", [scriptPath, "start"]);
  return result.stdout.toString().trim() + result.stderr.toString();
}

/// test 分支
Future<String> testMihomo() async {
  final result = await Process.run("sh", [scriptPath, "test"]);
  return result.stdout.toString().trim() + result.stderr.toString();
}

/// check 分支
Future<String> checkMihomo() async {
  final result = await Process.run("sh", [scriptPath, "check"]);
  return result.stdout.toString().trim() + result.stderr.toString();
}