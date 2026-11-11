const map = (name, image, variant = '') => ({ name, image, variant });
const stormPoint = map('Storm Point', 'Storm_Point');
const brokenMoon = map('Broken Moon', 'Broken_Moon');
const olympus = map('Olympus', 'Olympus');
const district = map('E-District', 'E-District');
const worldsEdge = map('World’s Edge', 'Worlds_Edge');

const rotations = [
  { id: 'ranked', label: 'Ranked', minutes: 96, slotMinutes: 120, maps: [stormPoint, brokenMoon, district] },
  { id: 'br', label: 'Обычный BR', minutes: 41, slotMinutes: 60, maps: [district, olympus, stormPoint] },
  { id: 'mixtape', label: 'Mixtape', minutes: 8, slotMinutes: 15, maps: [
    map('Skull Town', 'Arena_Skulltown', 'Командный бой'),
    map('Thunderdome', 'Thunderdome', 'Контроль'),
  ] },
  { id: 'wildcard', label: 'Wildcard', minutes: 22, slotMinutes: 30, maps: [worldsEdge, district, olympus] },
];

const legends = [
  { name: 'Pathfinder', role: 'Мобильность', history: [10.1, 10.6, 10.4, 11.2, 11.6, 11.4, 12.3] },
  { name: 'Wraith', role: 'Мобильность', history: [9.9, 9.7, 9.4, 9.8, 9.3, 9.6, 9.1] },
  { name: 'Lifeline', role: 'Поддержка', history: [7.2, 7.3, 7.6, 7.5, 7.6, 7.9, 8.2] },
  { name: 'Alter', role: 'Мобильность', history: [6.7, 6.4, 6.5, 6.2, 6.4, 6.7, 7.0] },
  { name: 'Bangalore', role: 'Штурм', history: [7.1, 6.9, 6.7, 6.8, 6.5, 6.4, 6.3] },
  { name: 'Bloodhound', role: 'Разведка', history: [5.1, 5.6, 5.2, 5.3, 5.6, 5.9, 5.8] },
];

const ranks = ['Все ранги', 'Новичок', 'Бронза', 'Серебро', 'Золото', 'Платина', 'Алмаз', 'Мастер', 'Хищник'];

const weapons = [
  { name: 'R-301', damage: 14, rpm: 810, magazine: 18 },
  { name: 'Flatline', damage: 18, rpm: 600, magazine: 20 },
  { name: 'Volt', damage: 15, rpm: 720, magazine: 19 },
  { name: 'Alternator', damage: 16, rpm: 600, magazine: 19 },
  { name: 'R-99', damage: 11, rpm: 1080, magazine: 17 },
  { name: 'C.A.R.', damage: 12, rpm: 930, magazine: 19 },
];
const armors = [
  { name: 'Без щита', health: 100 },
  { name: 'Белый · 150 HP', health: 150 },
  { name: 'Синий · 175 HP', health: 175 },
  { name: 'Фиолетовый · 200 HP', health: 200 },
  { name: 'Красный · 225 HP', health: 225 },
];

const builds = [
  { name: 'Ближняя', pairs: [
    ['Prowler', 'EVA-8', 'Prowler держит давление очередями. EVA-8 удобен в упор.'],
    ['Peacekeeper', 'Flatline', 'Peacekeeper для выстрелов из-за укрытия. Flatline помогает, когда цель отходит.'],
  ] },
  { name: 'Средняя', pairs: [
    ['R-301', 'Volt', 'R-301 для средней дистанции. Volt пригодится, если соперник сблизится.'],
    ['Hemlok', 'Alternator', 'Hemlok для стрельбы очередями из-за укрытия. Alternator для ближнего боя.'],
  ] },
  { name: 'Дальняя', pairs: [
    ['G7 Scout', 'C.A.R.', 'G7 Scout для повторных попаданий издалека. C.A.R. поможет при сближении.'],
    ['Sentinel', 'Flatline', 'Sentinel для одиночных выстрелов с позиции. Flatline прикрывает подходы.'],
  ] },
];
const guides = [
  { name: 'Wraith', styles: [
    ['Отход под огнём', ['Phase Dome', 'Вход в фазу во время установки портала.'], ['Fast Phase', 'Быстрый вход в фазу для отступления под огнём.']],
    ['Разведка и дальний отход', ['Sixth Sense', 'Предупреждение о другом отряде поблизости.'], ['Void Jumper', 'Больше времени в фазе и двойной прыжок для дальнего отхода.']],
  ] },
  { name: 'Pathfinder', styles: [
    ['Переходы отряда', ['Ringmaster', 'Консоли кольца помогают выбрать следующую позицию.'], ['Feeling Zippy', 'Второй заряд зиплайна даёт отряду запасной маршрут.']],
    ['Разведка и мобильность', ['Field Research', 'Маяки разведки показывают, где находятся соперники.'], ['Landing Gear', 'Больше контроля в воздухе и быстрее восстановление после приземления.']],
  ] },
  { name: 'Lifeline', styles: [
    ['Поддержка отряда', ['Enhanced Radio', 'Назначай D.O.C. союзнику с большей дистанции.'], ['Revive Shield', 'Щит D.O.C. прикрывает союзника во время оживления.']],
    ['Мобильная поддержка', ['Improved Flight', 'Более долгое и управляемое планирование.'], ['Ultimate Cooldown', 'Купол готовится быстрее и чаще доступен в бою.']],
  ] },
  { name: 'Alter', styles: [
    ['Прорыв через портал', ['Controller of Worlds', 'Проверь следующую зону и выбери маршрут отряда.'], ['Void Breacher', 'Скорость и управление оружием после выхода из портала.']],
    ['Разведка перед переходом', ['Eye to Another World', 'Маяки разведки помогают выбрать обход.'], ['Staring into the Void', 'Дольше видно противников у выхода из портала.']],
  ] },
];
