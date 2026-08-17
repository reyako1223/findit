import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'findit_app.dart';
import 'src/rust/frb_generated.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FindItBootstrap());
}

class FindItBootstrap extends StatefulWidget {
  const FindItBootstrap({super.key});

  @override
  State<FindItBootstrap> createState() => _FindItBootstrapState();
}

class _FindItBootstrapState extends State<FindItBootstrap> {
  final controller = FindItController();
  Object? startupError;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final minimumSplash = Future<void>.delayed(
      const Duration(milliseconds: 1100),
    );
    try {
      await RustLib.init();
      await controller.initialize();
      await minimumSplash;
      if (mounted) setState(() => ready = true);
    } catch (error) {
      await minimumSplash;
      if (mounted) setState(() => startupError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FindIt',
      debugShowCheckedModeBanner: false,
      theme: buildFindItTheme(),
      home: startupError != null
          ? StartupErrorScreen(
              message: FindItController.friendlyError(startupError!),
              onRetry: () {
                setState(() => startupError = null);
                _start();
              },
            )
          : ready
          ? FindItApp(controller: controller)
          : const SplashScreen(),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              Color(0xFF0C8875),
              Color(0xFF36A188),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.manage_search_rounded,
                    size: 52,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'FindIt',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.8,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Smart Lost & Found Matcher',
                  style: TextStyle(
                    color: Color(0xFFD9F4ED),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 25,
                  height: 25,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StartupErrorScreen extends StatelessWidget {
  const StartupErrorScreen({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        minimum: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppColors.danger,
              ),
              const SizedBox(height: 20),
              Text(
                'FindIt could not start',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: const Text('TRY AGAIN')),
            ],
          ),
        ),
      ),
    );
  }
}
