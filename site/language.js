const apehLanguage = (() => {
  const english = {
  "Язык": "Language",
  "Автоматически": "Automatic",
  "Русский": "Russian",
  "Английский": "English",
  "Apeh — помощник для Apex Legends": "Apeh — Apex Legends companion",
  "Apeh — прототип приложения": "Apeh — app prototype",
  "Apeh, главная": "Apeh, home",
  "Apeh, на сайт": "Apeh, back to site",
  "Помощник для Apex Legends": "Apex Legends companion",
  "К высадке": "Ready to",
  "готов.": "drop.",
  "Карты и время смены, популярные легенды, оружие и сборки для следующего матча.": "Map rotations, popular legends, weapons, and loadouts for your next match.",
  "Скачать для Windows": "Download for Windows",
  "Открыть прототип": "Open prototype",
  "Тушевая гравюра горного острова с аванпостом": "Ink engraving of a mountainous island with an outpost",
  "Экраны прототипа": "Prototype screens",
  "Карты": "Maps",
  "Ротация и таймеры": "Rotations and timers",
  "Легенды": "Legends",
  "Выбор по рангам": "Pick rates by rank",
  "Оружие": "Weapons",
  "Сравнение и TTK": "Comparison and TTK",
  "Сборки": "Loadouts",
  "Пары и улучшения": "Pairs and upgrades",
  "Независимый проект для игроков Apex Legends": "An independent project for Apex Legends players",
  "История версий": "Release history",
  "Разделы приложения": "App navigation",
  "На сайт": "Back to site",
  "Демо-данные": "Demo data",
  "Часовой пояс": "Time zone",
  "Местное время": "Local time",
  "Москва · UTC+3": "Moscow · UTC+3",
  "Екатеринбург · UTC+5": "Yekaterinburg · UTC+5",
  "Новосибирск · UTC+7": "Novosibirsk · UTC+7",
  "Владивосток · UTC+10": "Vladivostok · UTC+10",
  "Напоминания": "Reminders",
  "Прототип Apeh": "Apeh prototype",
  "Закрыть": "Close",
  "Для работы интерактивного прототипа включите JavaScript.": "Enable JavaScript to use the interactive prototype.",
  "Ротация карт": "Map rotation",
  "Текущие и следующие карты": "Current and upcoming maps",
  "Обычный BR": "Regular BR",
  "Командный бой": "Team Deathmatch",
  "Контроль": "Control",
  "Сейчас": "Now",
  "До смены": "Time left",
  "Ход ротации": "Rotation progress",
  "Далее": "Next",
  "{mode}, расписание": "{mode} schedule",
  "Режимы": "Modes",
  "Предупреждать заранее": "Minutes before rotation",
  "{minutes} мин": "{minutes} min",
  "В прототипе напоминания появляются в открытой вкладке.": "In this prototype, reminders appear while the tab is open.",
  "Сохранить": "Save",
  "Напоминания сохранены": "Reminders saved",
  "Напоминания включены до закрытия вкладки": "Reminders are enabled until you close this tab",
  "{mode} · {map} через {minutes} мин": "{mode} · {map} in {minutes} min",
  "Популярность и динамика за 7 дней": "Pick rates and trends over 7 days",
  "Ранг": "Rank",
  "Частота выбора": "Pick rate",
  "6 дней назад": "6 days ago",
  "Сегодня": "Today",
  "п.п.": "pp",
  "Доля выбора по дням, в процентах": "Daily pick rate, in percent",
  "Мобильность": "Mobility",
  "Поддержка": "Support",
  "Штурм": "Assault",
  "Разведка": "Recon",
  "Все ранги": "All ranks",
  "Новичок": "Rookie",
  "Бронза": "Bronze",
  "Серебро": "Silver",
  "Золото": "Gold",
  "Платина": "Platinum",
  "Алмаз": "Diamond",
  "Мастер": "Master",
  "Хищник": "Predator",
  "Сравнение характеристик и времени до убийства": "Compare stats and time to kill",
  "Первое оружие": "First weapon",
  "Второе оружие": "Second weapon",
  "Броня цели": "Target armor",
  "Урон в корпус": "Body damage",
  "Выстрелов в минуту": "Rounds per minute",
  "Патронов в магазине": "Magazine size",
  "Урон в секунду": "Damage per second",
  "Характеристики": "Weapon stats",
  "Показатель": "Metric",
  "Время до убийства": "Time to kill",
  "Попадания в корпус": "Body hits",
  "Нужна перезарядка": "Reload required",
  "{value} с": "{value} s",
  "Без щита": "No shield",
  "Белый · 150 HP": "White · 150 HP",
  "Синий · 175 HP": "Blue · 175 HP",
  "Фиолетовый · 200 HP": "Purple · 200 HP",
  "Красный · 225 HP": "Red · 225 HP",
  "Пары оружия и улучшения легенд": "Weapon pairs and legend upgrades",
  "Пары оружия": "Weapon pairs",
  "Дистанция": "Range",
  "Улучшения": "Upgrades",
  "Легенда": "Legend",
  "Стиль игры": "Playstyle",
  "Ур. {level}": "Lv. {level}",
  "Ближняя": "Close",
  "Средняя": "Medium",
  "Дальняя": "Long",
  "Prowler держит давление очередями. EVA-8 удобен в упор.": "Prowler keeps pressure with bursts. EVA-8 excels at point-blank range.",
  "Peacekeeper для выстрелов из-за укрытия. Flatline помогает, когда цель отходит.": "Use Peacekeeper to peek from cover. Flatline helps when the target pulls back.",
  "R-301 для средней дистанции. Volt пригодится, если соперник сблизится.": "Use R-301 at midrange. Volt covers you when an opponent closes in.",
  "Hemlok для стрельбы очередями из-за укрытия. Alternator для ближнего боя.": "Use Hemlok for bursts from cover and Alternator for close fights.",
  "G7 Scout для повторных попаданий издалека. C.A.R. поможет при сближении.": "G7 Scout lands follow-up shots at range. C.A.R. covers close fights.",
  "Sentinel для одиночных выстрелов с позиции. Flatline прикрывает подходы.": "Use Sentinel for single shots from a position. Flatline covers approaches.",
  "Отход под огнём": "Retreat under fire",
  "Вход в фазу во время установки портала.": "Phase while placing a portal.",
  "Быстрый вход в фазу для отступления под огнём.": "Enter phase faster when retreating under fire.",
  "Разведка и дальний отход": "Scout and disengage",
  "Предупреждение о другом отряде поблизости.": "Get warned when another squad is nearby.",
  "Больше времени в фазе и двойной прыжок для дальнего отхода.": "Spend longer in phase and double jump to get farther away.",
  "Переходы отряда": "Squad rotations",
  "Консоли кольца помогают выбрать следующую позицию.": "Ring consoles help you pick the next position.",
  "Второй заряд зиплайна даёт отряду запасной маршрут.": "A second zipline charge gives your squad a backup route.",
  "Разведка и мобильность": "Recon and mobility",
  "Маяки разведки показывают, где находятся соперники.": "Survey beacons reveal opponents’ positions.",
  "Больше контроля в воздухе и быстрее восстановление после приземления.": "Get more control in the air and recover sooner after landing.",
  "Поддержка отряда": "Squad support",
  "Назначай D.O.C. союзнику с большей дистанции.": "Assign D.O.C. to a teammate from farther away.",
  "Щит D.O.C. прикрывает союзника во время оживления.": "D.O.C.’s shield protects your teammate during a revive.",
  "Мобильная поддержка": "Mobile support",
  "Более долгое и управляемое планирование.": "Glide longer and with more control.",
  "Купол готовится быстрее и чаще доступен в бою.": "Get your dome ready faster and use it more often in fights.",
  "Прорыв через портал": "Push through a portal",
  "Проверь следующую зону и выбери маршрут отряда.": "Check the next ring and choose your squad’s route.",
  "Скорость и управление оружием после выхода из портала.": "Gain speed and weapon handling after exiting a portal.",
  "Разведка перед переходом": "Scout before rotating",
  "Маяки разведки помогают выбрать обход.": "Survey beacons help you choose a safer route.",
  "Дольше видно противников у выхода из портала.": "Track opponents for longer near the portal exit."
};
  const key = 'apeh.language';
  const select = document.querySelector('#site-language');

  function savedChoice() {
    try {
      const stored = localStorage.getItem(key);
      if (['auto', 'ru', 'en'].includes(stored)) return stored;
    } catch {}
    return 'ru';
  }

  let choice = savedChoice();
  let locale;

  function translate(source, values = {}) {
    const text = locale === 'en' && Object.hasOwn(english, source) ? english[source] : source;
    return text.replace(/\{(\w+)\}/g, (match, name) => values[name] ?? match);
  }

  function apply() {
    locale = choice === 'auto'
      ? (navigator.language.toLowerCase().startsWith('ru') ? 'ru' : 'en')
      : choice;
    document.documentElement.lang = locale;
    select.value = choice;
    for (const element of document.querySelectorAll('[data-i18n]')) {
      element.textContent = translate(element.dataset.i18n);
    }
    for (const element of document.querySelectorAll('[data-i18n-aria]')) {
      element.setAttribute('aria-label', translate(element.dataset.i18nAria));
    }
    for (const element of document.querySelectorAll('[data-i18n-alt]')) {
      element.alt = translate(element.dataset.i18nAlt);
    }
    document.dispatchEvent(new Event('apeh:language'));
  }

  select.addEventListener('change', () => {
    choice = select.value;
    try { localStorage.setItem(key, choice); } catch {}
    apply();
  });
  window.addEventListener('languagechange', () => { if (choice === 'auto') apply(); });
  window.addEventListener('storage', event => {
    if (event.key === key || event.key === null) {
      choice = savedChoice();
      apply();
    }
  });
  apply();
  return { translate, get locale() { return locale; } };
})();
