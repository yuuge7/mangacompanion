import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'home_widget.dart';
import 'screens/home_screen.dart';
import 'storage.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await MangaStore.open();
  // The shelf paints its own system bars per theme; see HomeScreen.
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  final state = AppState(store, onSaved: () => unawaited(refreshHomeWidget()));

  // The home screen widget writes to the same store. Pick its changes up
  // as they happen, and on every return to the app in case one was missed.
  listenForWidgetChanges(() => unawaited(state.reloadFromDisk()));
  AppLifecycleListener(onResume: () => unawaited(state.reloadFromDisk()));

  runApp(MangaCompanionApp(state: state));
}

class MangaCompanionApp extends StatelessWidget {
  final AppState state;
  const MangaCompanionApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Manga Companion',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: HomeScreen(state: state),
    );
  }
}
