import 'dart:io';
import 'package:mihomoR/service/path.dart';
import 'package:mihomoR/service/subscriptions.dart';

Future<void> stopMihomo() async {
  await Process.run("sh", [scriptPath, "kill"]);
}

Future<void> startMihomo() async {
  await Process.run("sh", [scriptPath, "kill"]);
  await Process.start("sh", [scriptPath, "start"]);
}

Future<void> testMihomo() async {
  await Process.run("sh", [scriptPath, "test"]);
}

Future<void> checkMihomo() async {
  await Process.run("sh", [scriptPath, "check"]);
}