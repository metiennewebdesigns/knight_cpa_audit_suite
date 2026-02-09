import 'dart:io' show Directory;
import 'package:path_provider/path_provider.dart';

Future<String?> getDocumentsPath() async {
  final Directory dir = await getApplicationDocumentsDirectory();
  return dir.path;
}