import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'animal.dart';

class LocalStore {
  LocalStore(this.preferences) {
    history.addAll(preferences.getStringList('search_history') ?? []);
    for (final raw in preferences.getStringList('favorites') ?? <String>[]) {
      try {
        favorites.add(Animal.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        /* Пропускаем повреждённую локальную запись. */
      }
    }
  }
  final SharedPreferences preferences;
  final List<Animal> favorites = [];
  final List<String> history = [];
  bool contains(Animal animal) => favorites.any((item) => item.id == animal.id);
  Future<void> toggle(Animal animal) async {
    final next = [...favorites];
    if (contains(animal)) {
      next.removeWhere((item) => item.id == animal.id);
    } else {
      next.add(animal);
    }
    if (!await preferences.setStringList(
      'favorites',
      next.map((a) => jsonEncode(a.toJson())).toList(),
    )) {
      throw StateError('Не удалось сохранить избранное');
    }
    favorites
      ..clear()
      ..addAll(next);
  }

  Future<void> remember(String query) async {
    final next = [
      query,
      ...history.where((item) => item != query),
    ].take(8).toList();
    if (await preferences.setStringList('search_history', next)) {
      history
        ..clear()
        ..addAll(next);
    }
  }
}
