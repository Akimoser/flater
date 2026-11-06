import 'animal.dart';

/// Учебные примеры. Никогда не выдаются за ответ сервера.
final demoAnimals = [
  const Animal(
    name: 'Red Fox',
    isDemo: true,
    taxonomy: {
      'scientific_name': 'Vulpes vulpes',
      'class': 'Mammalia',
      'family': 'Canidae',
      'kingdom': 'Animalia',
    },
    locations: ['Europe', 'Asia', 'North America'],
    characteristics: {
      'diet': 'Omnivore',
      'habitat': 'Forests and grasslands',
      'lifespan': '2–5 years in the wild',
      'skin_type': 'Fur',
      'slogan': 'A versatile member of the dog family',
    },
  ),
  const Animal(
    name: 'Arctic Fox',
    isDemo: true,
    taxonomy: {
      'scientific_name': 'Vulpes lagopus',
      'class': 'Mammalia',
      'family': 'Canidae',
      'kingdom': 'Animalia',
    },
    locations: ['North America', 'Europe', 'Asia'],
    characteristics: {
      'diet': 'Omnivore',
      'habitat': 'Arctic tundra',
      'lifespan': '3–6 years in the wild',
      'skin_type': 'Fur',
      'slogan': 'Adapted to the cold of the Arctic',
    },
  ),
];
