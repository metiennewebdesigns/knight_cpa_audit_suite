import 'dart:io' show File;
import 'package:open_filex/open_filex.dart';

Future<bool> localFileExists(String path) async => File(path).exists();

Future<void> openLocalFile(String path) async {
  await OpenFilex.open(path);
}