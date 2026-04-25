import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class MyTimerHandler extends TaskHandler {
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) {
    // TODO: implement onDestroy
    throw UnimplementedError();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // TODO: implement onRepeatEvent
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) {
    // TODO: implement onStart
    throw UnimplementedError();
  }

}
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTimerHandler());
}