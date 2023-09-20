import 'dart:io';

import 'package:path_provider/path_provider.dart';

// TODO delete this file, it is not needed
///Helper to write events to a local file, because SharedPrefs doesn't sync datas between isolated
class LogHelper {
  static const String _backgroundTaskLogFileName = "iOSBackgroundTask.log";

  ///Write actual [iOSBackgroundTask] [DateTime] event
  static Future<void> LogBGTask({String data = ""}) async {
    try {
      var logFile = await _getOrCreateFile(_backgroundTaskLogFileName);
      if (logFile == null) {
        return;
      }

      var content = await ReadLogBGTask();
      var sink = logFile.openWrite();
      content +=
          'BackgroundTaskRefresh ran on ${DateTime.now()} - Data ${data}\n\n';
      sink.write(content);
      await sink.flush();
      await sink.close();
    } catch (e) {
      print(
          'Error on LogHelper.LogBGTask $_backgroundTaskLogFileName with exception $e');
    }
  }

  ///Read actual iOSBackgroundTask [DateTime] events as [String]
  static Future<String> ReadLogBGTask() async {
    var logFile = await _getOrCreateFile(_backgroundTaskLogFileName);
    if (logFile == null) {
      return ("Couldn't open $_backgroundTaskLogFileName");
    }
    try {
      return await logFile.readAsString();
    } catch (e) {
      return "Error:${e}";
    }
  }

  static Future<File?> _getOrCreateFile(String fileName) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;
    File file = File('$appDocPath/$fileName');
    try {
      if (await file.exists()) {
        return file;
      }
      return await file.create();
    } catch (e) {
      print('Error on LogHelper._getOrCreateFile $fileName with exception $e');
      return null;
    }
  }
}
