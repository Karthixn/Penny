import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'services/storage/secure_storage.dart';

final initialAuthTokenProvider = Provider<String?>((ref) => null);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final token = await SecureStorage.getAccessToken();
  runApp(
    ProviderScope(
      overrides: [
        initialAuthTokenProvider.overrideWithValue(token),
      ],
      child: const PennyApp(),
    ),
  );
}

class PennyApp extends ConsumerWidget {
  const PennyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Penny',
      theme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
