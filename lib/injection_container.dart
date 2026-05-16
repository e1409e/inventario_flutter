import 'package:get_it/get_it.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:libsql_dart/libsql_dart.dart';
import 'data/datasources/local_database.dart';
import 'data/datasources/remote_datasource.dart';
import 'data/repositories/inventory_repository_impl.dart';
import 'core/repositories/inventory_repository.dart';
import 'presentation/state/inventory_cubit.dart';

// sl = Service Locator
final sl = GetIt.instance;

Future<void> init() async {
  // --- INICIALIZACIÓN DE TURSO (NUBE) ---

  // Obtenemos las credenciales de tu archivo .env
  final tursoUrl = dotenv.env['TURSO_URL'] ?? '';
  final tursoToken = dotenv.env['TURSO_TOKEN'] ?? '';

  // Verificamos que las variables existan para no tener errores silenciosos
  if (tursoUrl.isEmpty || tursoToken.isEmpty) {
    throw Exception('Faltan las credenciales de Turso en el archivo .env');
  }

  // Inicializamos el cliente oficial de Turso usando su constructor directo
  final tursoClient = LibsqlClient(tursoUrl, authToken: tursoToken);
  await tursoClient.connect();

  // --- DATA SOURCES ---

  // Base de datos local (Drift - SQLite)
  sl.registerLazySingleton(() => LocalDatabase());

  // Fuente de datos remota (Turso - SQLite en la nube)
  sl.registerLazySingleton<RemoteDataSource>(
    () => TursoDataSource(tursoClient),
  );

  // --- REPOSITORIES ---

  // Registro de la implementación vinculada a la interfaz del Core
  sl.registerLazySingleton<InventoryRepository>(
    () => InventoryRepositoryImpl(
      localDb: sl(), // Busca automáticamente la instancia de LocalDatabase
      remoteDataSource:
          sl(), // Busca automáticamente la instancia de TursoDataSource
    ),
  );

  // --- CUBIT ---
  sl.registerFactory(() => InventoryCubit(repository: sl()));
}
