import 'package:flutter/material.dart';

import 'presentation/app_dependencies.dart';
import 'presentation/chat_page.dart';

void main() {
  runApp(VoiceRecorderDemoApp(dependencies: AppDependencies()));
}

class VoiceRecorderDemoApp extends StatelessWidget {
  const VoiceRecorderDemoApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return AppDependenciesScope(
      dependencies: dependencies,
      child: MaterialApp(
        title: 'Voice Chat',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
        ),
        home: const ChatPage(),
      ),
    );
  }
}
