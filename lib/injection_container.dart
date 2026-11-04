import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:libsql_dart/libsql_dart.dart';
import 'core/repositories/inventory_repository.dart';
import 'data/datasources/local_database.dart';
import 'data/datasources/remote_datasource.dart';
import 'data/repositories/inventory_repository_impl.dart';
import 'presentation/state/inventory_cubit.dart';

/// Instancia global del localizador de servicios (Service Locator).
final sl = GetIt.instance;

/// Inicializa las conexiones de base de datos y registra las dependencias de la aplicación.
Future<void> init() async {
  final tursoUrl = dotenv.env['TURSO_URL'] ?? '';
  final tursoToken = dotenv.env['TURSO_TOKEN'] ?? '';

  if (tursoUrl.isEmpty || tursoToken.isEmpty) {
    throw Exception(
      'Configuración incompleta: Faltan las variables TURSO_URL o TURSO_TOKEN en el archivo .env',
    );
  }

  final tursoClient = LibsqlClient(tursoUrl, authToken: tursoToken);
  await tursoClient.connect();

  // Fuentes de datos (Data Sources)
  sl.registerLazySingleton(() => LocalDatabase());
  sl.registerLazySingleton<RemoteDataSource>(
    () => TursoDataSource(tursoClient),
  );

  // Repositorios
  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(localDb: sl(), remoteDataSource: sl()),
  );

  // Gestión de estado (Cubits)
  sl.registerFactory(() => InventoryCubit(repository: sl()));
}
