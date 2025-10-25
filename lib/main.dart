import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';


Future<void> _initDesktopWindow() async {
  await windowManager.ensureInitialized();
  final windowSizeMin = Size(700.0, 700.0);
  final windowOptions = WindowOptions(
    center: true,
    minimumSize: windowSizeMin,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(windowSizeMin);
    await windowManager.setFullScreen(false);
    await windowManager.show();
    await windowManager.focus();

    Future.delayed(Duration(milliseconds: 50), () async {
      await windowManager.setMinimumSize(windowSizeMin);
    });
  });
}
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initDesktopWindow();
  runApp(const VkDownloaderApp());
}
