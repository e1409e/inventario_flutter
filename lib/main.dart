import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Eliminamos la importación de Supabase
import 'injection_container.dart' as di;
import 'presentation/state/inventory_cubit.dart';
import 'presentation/screen/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Cargar variables de entorno (Asegúrate de que en tu .env estén TURSO_URL y TURSO_TOKEN)
  await dotenv.load(fileName: ".env");

  // 2. Inicializar la Inyección de Dependencias (Aquí adentro se inicializa Turso)
  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Definimos el esquema de colores oscuro una sola vez para mantener orden
    final darkScheme = ColorScheme.fromSeed(
      seedColor: Colors.blueAccent,
      brightness: Brightness.dark,
    );

    return BlocProvider(
      create: (_) => di.sl<InventoryCubit>()..loadInventory(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Inventario AAA',

        // Configuración de Tema Oscuro
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: darkScheme,
          scaffoldBackgroundColor: const Color(0xFF121212), // Fondo profundo
          // Personalización de AppBars
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF121212),
            elevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          // Estilo global para los Cards (Dashboard)
          cardTheme: CardThemeData(
            color: const Color(0xFF1E1E1E), // Gris Slate para elevación
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.white10, width: 1),
            ),
          ),
        ),

        home: const DashboardScreen(),
      ),
    );
  }
}
