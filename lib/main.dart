import 'package:deepsage/services/storage_service.dart';
import 'package:flutter/material.dart';

import 'app.dart';

void main() => bootstrap();

Future<void> bootstrap() async {
  await StorageService.instance.init();
  runApp(const App());
}