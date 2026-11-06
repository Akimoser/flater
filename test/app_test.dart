import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flater/main.dart';
import 'package:flater/src/dependencies.dart';
import 'package:flater/src/demo_data.dart';
import 'package:flater/src/local_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();
  });
  tearDown(() async {
    await getIt.reset();
  });
  test('favorites and history survive store reconstruction', () async {
    final store = getIt<LocalStore>();
    await store.toggle(demoAnimals.first);
    await store.remember('fox');
    await store.remember('tiger');
    await store.remember('fox');
    final restored = LocalStore(await SharedPreferences.getInstance());
    expect(restored.contains(demoAnimals.first), isTrue);
    expect(restored.favorites.single.isDemo, isTrue);
    expect(restored.history, ['fox', 'tiger']);
    await restored.toggle(demoAnimals.first);
    expect(restored.favorites, isEmpty);
  });
  testWidgets('small display, demo, details and favorites', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const FlaterApp());
    await tester.pumpAndSettle();
    final demo = find.text('Посмотреть учебный пример');
    await tester.scrollUntilVisible(
      demo,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(demo);
    await tester.pumpAndSettle();
    final fox = find.text('Red Fox');
    await tester.scrollUntilVisible(
      fox,
      180,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(fox);
    await tester.pumpAndSettle();
    expect(find.text('Карточка вида'), findsOneWidget);
    await tester.tap(find.text('Сохранить в избранное'));
    await tester.pumpAndSettle();
    expect(find.text('Убрать из избранного'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Избранное'));
    await tester.pumpAndSettle();
    expect(find.text('Red Fox'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing key produces useful error', (tester) async {
    await tester.pumpWidget(const FlaterApp());
    await tester.tap(find.text('tiger'));
    await tester.pumpAndSettle();
    expect(find.text('Добавьте API-ключ в разделе «Доступ».'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
