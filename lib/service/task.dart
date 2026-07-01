import 'dart:io';

import 'package:clashroot/service/path.dart';
import 'package:clashroot/service/yaml.dart';
import 'package:workmanager/workmanager.dart';

const String taskId = "sub_update";
const String taskName = "订阅更新";


@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Process.run("su", ["-c", "sh", scriptPath, "loop"]);
    return Future.value(true);
  });
}


// 注册函数（main 调用这个）
Future<void> registerWorkManagerTask() async {
  final settings = await yamlRead(dataPath);
  final raw = settings['interval'];

  final int? interval = int.tryParse(raw?.toString() ?? '');

  if (interval == null || interval == 0) {
    Workmanager().cancelAll();
    return;
  }
  Workmanager().registerPeriodicTask(
    taskId,
    taskName,
    frequency: Duration(minutes: interval),
  );
}
