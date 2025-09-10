import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'services/vault_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // In production you may want to forward to a crash reporter.
  };

  await runZonedGuarded(() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(VaultStore.boxName);
    await Hive.openBox(VaultStore.prefsBoxName);
    runApp(const DataMaskingApp());
  }, (error, stack) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Uncaught error: $error\n$stack');
    }
    // In production you may want to forward to a crash reporter.
  });
}
