import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_store.dart';
import 'network.dart';

final getIt = GetIt.instance;
Future<void> configureDependencies() async {
  final preferences = await SharedPreferences.getInstance();
  getIt.registerSingleton<ApiSession>(ApiSession());
  getIt.registerSingleton<LocalStore>(LocalStore(preferences));
  getIt.registerLazySingleton<Dio>(
    () => createDio(getIt<ApiSession>()),
    dispose: (dio) => dio.close(force: true),
  );
  getIt.registerLazySingleton<AnimalRepository>(
    () => AnimalRepository(getIt<Dio>()),
  );
}
