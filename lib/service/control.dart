import 'dart:io';

import 'package:mihomoR/service/path.dart';

/// kill 分支
Future<String> stopMihomo() async {
  final result = await Process.run("su", ["-c", "sh $scriptPath kill"]);
  return result.stdout.toString().trim() + result.stderr.toString();
}

/// start 分支
Future<String> startMihomo() async {
  await Process.run("su", ["-c", "sh $scriptPath kill"]);

  final result = await Process.run("su", ["-c", "sh $scriptPath start"]);
  return result.stdout.toString().trim() + result.stderr.toString();
}

/// test 分支
Future<String> testMihomo() async {
  final result = await Process.run("su", ["-c", "sh $scriptPath test"]);
  return result.stdout.toString().trim() + result.stderr.toString();
}

/// check 分支
Future<String> checkMihomo() async {
  final result = await Process.run("su", ["-c", "sh $scriptPath check"]);
  return result.stdout.toString().trim() + result.stderr.toString();
}
