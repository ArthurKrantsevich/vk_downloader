import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'services/vk_auth_service.dart';
import 'services/vk_oauth_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final authService = VkAuthService(config: defaultVkOAuthConfig);

  runApp(VkDownloaderApp(authService: authService));
}
