import 'dart:io';

import 'package:clashroot/service/path.dart';

Future<String> stopClash() async {
  final result = await Process.run("su", ["-c", "sh", scriptPath, "kill"]);
  return (result.stdout.toString() + result.stderr.toString()).trim();
}



Future<String> testClash() async {
  final result = await Process.run("su", ["-c", "sh", scriptPath, "test"]);
  return (result.stdout.toString() + result.stderr.toString()).trim();
}

Future<String> checkClash() async {
  final result = await Process.run("su", ["-c", "sh", scriptPath, "check"]);
  return (result.stdout.toString() + result.stderr.toString()).trim();
}
