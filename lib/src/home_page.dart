import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'animal.dart';
import 'demo_data.dart';
import 'dependencies.dart';
import 'local_store.dart';
import 'network.dart';

const forest = Color(0xFF165C43);

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final search = TextEditingController();
  final keyInput = TextEditingController();
  final repository = getIt<AnimalRepository>();
  final session = getIt<ApiSession>();
  final store = getIt<LocalStore>();
  List<Animal> results = [];
  CancelToken? request;
  int tab = 0;
  int generation = 0;
  bool loading = false;
  bool searched = false;
  bool demo = false;
  bool saving = false;
  String? error;
  String submittedQuery = '';
  String region = 'Все';

  @override
  void dispose() {
    request?.cancel();
    search.dispose();
    keyInput.dispose();
    super.dispose();
  }

  void message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> runSearch([String? term]) async {
    final query = (term ?? search.text).trim();
    if (query.isEmpty) {
      message('Введите название, например fox');
      return;
    }
    FocusScope.of(context).unfocus();
    search.text = query;
    request?.cancel();
    request = CancelToken();
    final current = ++generation;
    setState(() {
      loading = true;
      error = null;
      searched = true;
      demo = false;
      submittedQuery = query;
      region = 'Все';
      results = [];
    });
    try {
      final animals = await repository.search(query, cancelToken: request);
      if (!mounted || current != generation) return;
      setState(() {
        results = animals;
        loading = false;
      });
      try {
        await store.remember(query);
      } catch (_) {
        if (mounted) message('История не сохранена на устройстве');
      }
      if (mounted) setState(() {});
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e) && mounted && current == generation) {
        setState(() {
          loading = false;
          error = 'Не удалось выполнить запрос.';
        });
      }
    } on ApiFailure catch (e) {
      if (mounted && current == generation) {
        setState(() {
          loading = false;
          error = e.message;
        });
      }
    }
  }

  void showDemo() {
    request?.cancel();
    ++generation;
    setState(() {
      demo = true;
      results = demoAnimals;
      searched = true;
      loading = false;
      error = null;
      tab = 0;
      region = 'Все';
      submittedQuery = 'fox';
      search.text = 'fox';
    });
  }

  Future<void> toggle(Animal animal) async {
    if (saving) return;
    saving = true;
    try {
      await store.toggle(animal);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) message('Не удалось сохранить избранное');
    } finally {
      saving = false;
    }
  }

  Future<void> openDetails(Animal animal) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnimalPage(animal: animal, store: store),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        children: [
          Icon(Icons.travel_explore, color: forest),
          SizedBox(width: 10),
          Text(
            'WILD ATLAS',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              fontSize: 20,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Доступ к API',
          onPressed: () => setState(() => tab = 2),
          icon: const Icon(Icons.key_outlined),
        ),
      ],
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: switch (tab) {
            0 => catalog(),
            1 => favorites(),
            _ => access(),
          },
        ),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (value) => setState(() => tab = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          label: 'Каталог',
        ),
        NavigationDestination(
          icon: Icon(Icons.bookmark_outline),
          label: 'Избранное',
        ),
        NavigationDestination(icon: Icon(Icons.tune), label: 'Доступ'),
      ],
    ),
  );

  Widget hero(String eyebrow, String title, String subtitle) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: forest,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: Color(0xFFC6DE96),
            letterSpacing: 2,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFFDAE7DF), height: 1.5),
        ),
      ],
    ),
  );

  Widget sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 12),
    child: Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
    ),
  );

  Widget catalog() {
    final regions = {
      'Все',
      ...results.expand((animal) => animal.locations),
    }.toList();
    final visible = results.where(
      (animal) => region == 'Все' || animal.locations.contains(region),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        hero(
          'ПОЛЕВОЙ СПРАВОЧНИК',
          'Откройте мир\nдикой природы',
          'Ищите виды, изучайте их особенности\nи собирайте свою коллекцию.',
        ),
        const SizedBox(height: 22),
        TextField(
          controller: search,
          textInputAction: TextInputAction.search,
          onSubmitted: runSearch,
          maxLength: 80,
          decoration: InputDecoration(
            labelText: 'Название на английском',
            hintText: 'Например, fox или tiger',
            counterText: '',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Найти',
              onPressed: () => runSearch(),
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: ['fox', 'tiger', 'dolphin', 'eagle']
              .map(
                (term) => ActionChip(
                  label: Text(term),
                  onPressed: () => runSearch(term),
                ),
              )
              .toList(),
        ),
        if (!searched) ...[
          sectionTitle('Начните исследование'),
          const Text(
            'API Ninjas ищет по английскому названию и возвращает до 10 видов. '
            'Описание из API также приходит на английском.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => setState(() => tab = 2),
            icon: const Icon(Icons.key),
            label: const Text('Настроить API-ключ'),
          ),
          TextButton(
            onPressed: showDemo,
            child: const Text('Посмотреть учебный пример'),
          ),
          if (store.history.isNotEmpty) ...[
            sectionTitle('Недавние запросы'),
            Wrap(
              spacing: 8,
              children: store.history
                  .map(
                    (term) => ActionChip(
                      avatar: const Icon(Icons.history, size: 16),
                      label: Text(term),
                      onPressed: () => runSearch(term),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
        if (loading) ...[
          const SizedBox(height: 24),
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          const Text('Получаем данные API Ninjas…'),
          TextButton(
            onPressed: () {
              request?.cancel();
              ++generation;
              setState(() {
                loading = false;
                searched = false;
              });
            },
            child: const Text('Отменить запрос'),
          ),
        ],
        if (error != null) ...[
          sectionTitle('Запрос не выполнен'),
          Text(error!),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            children: [
              FilledButton(
                onPressed: () => runSearch(submittedQuery),
                child: const Text('Повторить'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => tab = 2),
                child: const Text('Проверить ключ'),
              ),
            ],
          ),
        ],
        if (demo)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text(
              'ДЕМО • встроенные примеры, не ответ сервера',
              style: TextStyle(
                color: Color(0xFF85520C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        if (searched && !loading && error == null) ...[
          sectionTitle('Результаты · ${results.length}'),
          if (results.isEmpty)
            const Text('Ничего не найдено. Попробуйте другое название.'),
          if (results.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: region,
              key: ValueKey('$submittedQuery-$demo'),
              decoration: const InputDecoration(
                labelText: 'Регион среди найденных',
              ),
              isExpanded: true,
              items: regions
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => region = value ?? 'Все'),
            ),
            const SizedBox(height: 14),
            ...visible.map(card),
          ],
        ],
      ],
    );
  }

  Widget card(Animal animal) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => openDetails(animal),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBF0E0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.pets, color: forest),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        animal.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        animal.scientificName,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: store.contains(animal)
                      ? 'Убрать из избранного'
                      : 'В избранное',
                  onPressed: () => toggle(animal),
                  icon: Icon(
                    store.contains(animal)
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                    color: forest,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              animal.locations.join(' · '),
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              animal.characteristics['habitat'] ?? 'Среда обитания не указана',
            ),
            const SizedBox(height: 12),
            Text(
              animal.isDemo ? 'Учебный пример  →' : 'Подробнее о виде  →',
              style: const TextStyle(
                color: forest,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget favorites() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      hero(
        'ЛИЧНАЯ КОЛЛЕКЦИЯ',
        'Избранные виды',
        'Сохранённые карточки доступны без сети.\nВ коллекции: ${store.favorites.length}',
      ),
      const SizedBox(height: 20),
      if (store.favorites.isEmpty) ...[
        sectionTitle('Пока здесь пусто'),
        const Text(
          'Найдите животное и нажмите закладку на карточке. '
          'Избранное сохраняется после перезапуска приложения.',
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => tab = 0),
          child: const Text('Перейти в каталог'),
        ),
      ],
      ...store.favorites.map(card),
    ],
  );

  Widget access() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      hero(
        'ПОДКЛЮЧЕНИЕ',
        'Доступ к API',
        'Один ключ для запросов к API Ninjas.\nВаш ключ не публикуется в проекте.',
      ),
      sectionTitle('API Ninjas'),
      const SelectableText(
        '1. Зарегистрируйтесь на api-ninjas.com.\n'
        '2. Скопируйте ключ из личного кабинета.\n3. Вставьте ключ в поле ниже.',
      ),
      const SizedBox(height: 20),
      TextField(
        controller: keyInput,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          labelText: 'API-ключ',
          prefixIcon: Icon(Icons.key_outlined),
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: () {
          final token = keyInput.text.trim();
          if (token.isEmpty) {
            message('Сначала вставьте API-ключ');
            return;
          }
          request?.cancel();
          ++generation;
          session.token = token;
          keyInput.clear();
          FocusScope.of(context).unfocus();
          setState(() {
            loading = false;
            error = null;
            searched = false;
            demo = false;
            results = [];
          });
          message('Ключ добавлен на время текущего запуска');
        },
        child: const Text('Применить ключ'),
      ),
      const SizedBox(height: 8),
      Text(
        session.token.isEmpty
            ? 'Ключ ещё не добавлен'
            : 'Ключ добавлен · доступ проверяется запросом',
        style: const TextStyle(color: forest),
      ),
      if (session.token.isNotEmpty)
        TextButton(
          onPressed: () {
            request?.cancel();
            ++generation;
            setState(() {
              session.token = '';
              loading = false;
              searched = false;
              results = [];
              error = null;
            });
          },
          child: const Text('Удалить ключ из памяти'),
        ),
      sectionTitle('Безопасность'),
      const Text(
        'Ключ хранится только до закрытия приложения и автоматически добавляется '
        'в заголовок X-Api-Key. Заголовки и секрет не выводятся в журнал. '
        'После перезапуска ключ нужно ввести заново.',
      ),
      sectionTitle('Без ключа'),
      const Text(
        'Учебный режим показывает две встроенные карточки. '
        'Он не обращается к API и не заменяет проверку сетевых запросов.',
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: showDemo,
        child: const Text('Открыть демонстрацию'),
      ),
      const SizedBox(height: 16),
      const Text(
        'Практическая работа «Работа с сетью»\nDio · TokenInterceptor · pretty_dio_logger · get_it',
        style: TextStyle(fontSize: 12, color: Colors.black54),
      ),
    ],
  );
}

class AnimalPage extends StatefulWidget {
  const AnimalPage({super.key, required this.animal, required this.store});
  final Animal animal;
  final LocalStore store;
  @override
  State<AnimalPage> createState() => _AnimalPageState();
}

class _AnimalPageState extends State<AnimalPage> {
  bool saving = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.animal;
    return Scaffold(
      appBar: AppBar(title: const Text('Карточка вида')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: forest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.pets,
                        size: 70,
                        color: Color(0xFFC6DE96),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        a.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        a.scientificName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (a.isDemo)
                  const Text(
                    'ДЕМО • встроенный учебный пример',
                    style: TextStyle(
                      color: Color(0xFF85520C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          setState(() => saving = true);
                          try {
                            await widget.store.toggle(a);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Не удалось сохранить избранное',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => saving = false);
                          }
                        },
                  icon: Icon(
                    widget.store.contains(a)
                        ? Icons.bookmark
                        : Icons.bookmark_border,
                  ),
                  label: Text(
                    widget.store.contains(a)
                        ? 'Убрать из избранного'
                        : 'Сохранить в избранное',
                  ),
                ),
                block(
                  'Где обитает',
                  a.locations.isEmpty ? 'Не указано' : a.locations.join(', '),
                ),
                ...a.characteristics.entries.map(
                  (entry) => block(
                    labels[entry.key] ?? entry.key.replaceAll('_', ' '),
                    entry.value,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Классификация',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                ...a.taxonomy.entries.map(
                  (entry) => block(labels[entry.key] ?? entry.key, entry.value),
                ),
                const SizedBox(height: 16),
                Text(
                  a.isDemo
                      ? 'Источник: учебные данные приложения'
                      : 'Источник: API Ninjas · Animals API',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget block(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: forest, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        SelectableText(
          value.isEmpty ? 'Не указано' : value,
          style: const TextStyle(fontSize: 16, height: 1.4),
        ),
      ],
    ),
  );
}

const labels = {
  'diet': 'Питание',
  'habitat': 'Среда обитания',
  'lifespan': 'Продолжительность жизни',
  'weight': 'Масса',
  'height': 'Рост',
  'top_speed': 'Скорость',
  'skin_type': 'Покров',
  'slogan': 'Особенность',
  'prey': 'Добыча',
  'biggest_threat': 'Основная угроза',
  'kingdom': 'Царство',
  'phylum': 'Тип',
  'class': 'Класс',
  'order': 'Отряд',
  'family': 'Семейство',
  'genus': 'Род',
  'scientific_name': 'Научное название',
};
