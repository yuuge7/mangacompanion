import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';
import 'storage.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await MangaStore.open();
  // The shelf paints its own system bars per theme; see HomeScreen.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(MangaCompanionApp(state: AppState(store)));
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
      themeMode: ThemeMode.system,
      home: HomeScreen(state: state),
    );
  }
}
