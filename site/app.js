const screen = document.querySelector('#screen');
const mapTools = document.querySelector('#map-tools');
const zoneSelect = document.querySelector('#timezone');
const remindersButton = document.querySelector('#open-reminders');
const dialog = document.querySelector('#details');
const dialogTitle = document.querySelector('#dialog-title');
const dialogContent = document.querySelector('#dialog-content');
const toast = document.querySelector('#toast');

const minute = 60_000;
const formatNumber = new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 2 });
const formatDecimal = new Intl.NumberFormat('ru-RU', { minimumFractionDigits: 1, maximumFractionDigits: 1 });
const storageKey = 'apeh.prototype.preferences';
const preferences = readPreferences();
zoneSelect.value = preferences.zone;
let clock = createClock();
const started = Date.now();
let activeTab;
let shownSlots = [];
let toastTimer;
const notified = new Set();

const selections = { rank: 0, legend: 0, first: 0, second: 1, armor: 3, distance: 1, guide: 0, style: 0 };
const tabs = {
  maps: { title: 'Ротация карт', render: renderMaps },
  legends: { title: 'Легенды', render: renderLegends },
  weapons: { title: 'Оружие', render: renderWeapons },
  builds: { title: 'Сборки', render: renderBuilds },
};

function readPreferences() {
  let saved;
  try {
    saved = JSON.parse(localStorage.getItem(storageKey));
  } catch {
    saved = null;
  }
  const zone = Array.from(zoneSelect.options).some(option => option.value === saved?.zone) ? saved.zone : 'local';
  const modes = Array.isArray(saved?.modes) ? rotations.filter(mode => saved.modes.includes(mode.id)).map(mode => mode.id) : [];
  const lead = [1, 5, 10, 15, 30].includes(saved?.lead) ? saved.lead : 5;
  return { zone, modes, lead };
}

function savePreferences() {
  try {
    localStorage.setItem(storageKey, JSON.stringify(preferences));
    return true;
  } catch {
    return false;
  }
}

function createClock() {
  return new Intl.DateTimeFormat('ru-RU', {
    hour: '2-digit',
    minute: '2-digit',
    timeZone: preferences.zone === 'local' ? undefined : preferences.zone,
  });
}

function icon(name) {
  return `<svg class="icon" aria-hidden="true"><use href="assets/icons.svg#${name}"/></svg>`;
}

function heading(title, description, control = '') {
  return `<header class="screen-head"><div><h1 id="screen-title">${title}</h1><p>${description}</p></div>${control}</header>`;
}

function selectField(id, label, options, selected, values = options.map((_, index) => index)) {
  const markup = options.map((name, index) =>
    `<option value="${values[index]}" ${values[index] === selected ? 'selected' : ''}>${name}</option>`,
  ).join('');
  return `<label class="field" for="${id}">${label}<select id="${id}">${markup}</select></label>`;
}

function bindSelect(id, update) {
  document.getElementById(id).addEventListener('change', event => {
    selections[id] = Number(event.target.value);
    update();
  });
}

function showTab() {
  const hash = location.hash.slice(1);
  activeTab = Object.hasOwn(tabs, hash) ? hash : 'maps';
  const tab = tabs[activeTab];
  document.title = `${tab.title} — Apeh`;
  mapTools.hidden = activeTab !== 'maps';
  for (const link of document.querySelectorAll('[data-tab]')) {
    if (link.dataset.tab === activeTab) link.setAttribute('aria-current', 'page');
    else link.removeAttribute('aria-current');
  }
  tab.render();
}

function getSlot(mode, now) {
  const firstEnd = started + mode.minutes * minute;
  const duration = mode.slotMinutes * minute;
  const index = now < firstEnd ? 0 : 1 + Math.floor((now - firstEnd) / duration);
  const end = firstEnd + index * duration;
  return {
    current: mode.maps[index % mode.maps.length],
    next: mode.maps[(index + 1) % mode.maps.length],
    start: end - duration,
    end,
  };
}

function countdown(milliseconds) {
  const seconds = Math.max(0, Math.ceil(milliseconds / 1000));
  return [Math.floor(seconds / 3600), Math.floor(seconds / 60) % 60, seconds % 60]
    .map(value => String(value).padStart(2, '0')).join(':');
}

function dateTime(timestamp) {
  return `<time datetime="${new Date(timestamp).toISOString()}">${clock.format(timestamp)}</time>`;
}

function renderMaps() {
  const now = Date.now();
  shownSlots = rotations.map(mode => getSlot(mode, now));
  const cards = rotations.map((mode, index) => {
    const slot = shownSlots[index];
    const variant = slot.current.variant ? `Сейчас · ${slot.current.variant}` : 'Сейчас';
    return `<article class="map-card">
      <div class="map-current">
        <img class="map-image" src="https://apexlegendsstatus.com/assets/maps/${slot.current.image}.png" alt="">
        <span class="mode">${icon(mode.id)} ${mode.label}</span>
        <div class="map-info">
          <div><small>${variant}</small><h2>${slot.current.name}</h2></div>
          <div class="countdown"><small>До смены</small><span data-countdown>${countdown(slot.end - now)}</span></div>
          <progress class="map-progress" value="${now - slot.start}" max="${slot.end - slot.start}" aria-label="Ход ротации"></progress>
        </div>
      </div>
      <button type="button" class="map-next" data-schedule="${index}" aria-label="${mode.label}, расписание">
        <span class="map-next-label">Далее</span><strong>${slot.next.name}</strong>${dateTime(slot.end)}${icon('chevron')}
      </button>
    </article>`;
  }).join('');
  screen.innerHTML = heading('Ротация карт', 'Текущие и следующие карты') + `<div class="map-grid">${cards}</div>`;
}

function tick() {
  const now = Date.now();
  const slots = rotations.map(mode => getSlot(mode, now));
  if (activeTab === 'maps') updateMapTimers(slots, now);
  rotations.forEach((mode, index) => {
    const slot = slots[index];
    const remaining = slot.end - now;
    const key = `${mode.id}:${slot.end}:${preferences.lead}`;
    if (preferences.modes.includes(mode.id) && remaining <= preferences.lead * minute && !notified.has(key)) {
      notified.add(key);
      showToast(`${mode.label} · ${slot.next.name} через ${Math.ceil(remaining / minute)} мин`);
    }
  });
}

function updateMapTimers(slots, now) {
  if (slots.some((slot, index) => slot.end !== shownSlots[index].end)) renderMaps();
  const counters = screen.querySelectorAll('[data-countdown]');
  const progressBars = screen.querySelectorAll('progress');
  slots.forEach((slot, index) => {
    counters[index].textContent = countdown(slot.end - now);
    progressBars[index].value = now - slot.start;
  });
}

function showSchedule(index) {
  const mode = rotations[index];
  const slot = getSlot(mode, Date.now());
  const entry = (label, mapSlot, start, end) =>
    `<div><dt>${label}${mapSlot.variant ? ` · ${mapSlot.variant}` : ''}</dt><dd><strong>${mapSlot.name}</strong>${dateTime(start)} – ${dateTime(end)}</dd></div>`;
  openDialog(mode.label, `<dl class="schedule">${entry('Сейчас', slot.current, slot.start, slot.end)}
    ${entry('Далее', slot.next, slot.end, slot.end + mode.slotMinutes * minute)}</dl>`);
}

function showReminders() {
  const modeOptions = rotations.map(mode => `<label><input type="checkbox" name="mode" value="${mode.id}"
    ${preferences.modes.includes(mode.id) ? 'checked' : ''}>${mode.label}</label>`).join('');
  const leads = [1, 5, 10, 15, 30];
  openDialog('Напоминания', `<form class="reminder-form" id="reminder-form">
    <fieldset><legend>Режимы</legend>${modeOptions}</fieldset>
    ${selectField('lead', 'Предупреждать заранее', leads.map(value => `${value} мин`), preferences.lead, leads)}
    <p class="form-note">В прототипе напоминания появляются в открытой вкладке.</p>
    <button class="button primary" type="submit">Сохранить</button>
  </form>`);
  document.querySelector('#reminder-form').addEventListener('submit', event => {
    event.preventDefault();
    preferences.modes = new FormData(event.currentTarget).getAll('mode');
    preferences.lead = Number(document.querySelector('#lead').value);
    updateReminderButton();
    dialog.close();
    showToast(savePreferences() ? 'Напоминания сохранены' : 'Напоминания включены до закрытия вкладки');
  });
}

function updateReminderButton() {
  remindersButton.dataset.enabled = String(preferences.modes.length > 0);
}

function openDialog(title, content) {
  dialogTitle.textContent = title;
  dialogContent.innerHTML = content;
  dialog.showModal();
}

function showToast(message) {
  clearTimeout(toastTimer);
  toast.textContent = message;
  toast.hidden = false;
  toastTimer = setTimeout(() => { toast.hidden = true; }, 5500);
}

function legendStats(legend, index) {
  const offset = selections.rank ? ((index * 7 + selections.rank * 3) % 17 - 8) * .22 : 0;
  const history = legend.history.map((value, day) => value + offset + ((day % 3) - 1) * selections.rank * .025);
  return { ...legend, index, history, latest: history.at(-1), change: history.at(-1) - history[0] };
}

function renderLegends() {
  screen.innerHTML = heading('Легенды', 'Популярность и динамика за 7 дней', selectField('rank', 'Ранг', ranks, selections.rank)) +
    `<div class="panel-grid">
      <article class="panel"><div class="panel-head"><h2>Частота выбора</h2>${icon('legends')}</div><div class="legend-list" id="legend-list"></div></article>
      <article class="panel" id="legend-history"></article>
    </div>`;
  updateLegends();
  bindSelect('rank', updateLegends);
}

function updateLegends(focus = false) {
  const stats = legends.map(legendStats);
  const current = stats[selections.legend];
  const list = document.querySelector('#legend-list');
  list.innerHTML = stats.sort((a, b) => b.latest - a.latest).map(item => `<button class="legend-row"
    type="button" data-legend="${item.index}" aria-pressed="${item.index === selections.legend}">
    <span class="legend-tile" aria-hidden="true">${item.name[0]}</span><strong>${item.name}</strong>
    <span class="mono">${formatDecimal.format(item.latest)} %</span>${trend(item.change)}
  </button>`).join('');
  document.querySelector('#legend-history').innerHTML = `<h2>${current.name}</h2><p>${current.role}</p>
    <strong class="chart-value">${formatDecimal.format(current.latest)} %</strong>${trend(current.change)}
    ${trendChart(current.history)}<div class="chart-labels"><span>6 дней назад</span><span>Сегодня</span></div>`;
  if (focus) list.querySelector(`[data-legend="${selections.legend}"]`).focus();
}

function trend(value) {
  const up = value >= 0;
  return `<span class="mono ${up ? 'trend-up' : 'trend-down'}">${up ? '+' : '−'}${formatDecimal.format(Math.abs(value))} п.п.</span>`;
}

function trendChart(history) {
  const minimum = Math.min(...history) - .3;
  const spread = Math.max(...history) - minimum + .3;
  const points = history.map((value, index) => [12 + 52 * index, 133 - 112 * (value - minimum) / spread]);
  const line = points.map(pair => pair.join(',')).join(' ');
  const label = history.map(value => formatDecimal.format(value)).join('; ');
  return `<svg class="chart" viewBox="0 0 336 148" role="img" aria-label="Доля выбора по дням, в процентах: ${label}">
    <path d="M12 32h312M12 72h312M12 112h312M12 140h312" stroke="#d8d4c5"/>
    <polygon points="12,140 ${line} 324,140" fill="#edf4aa"/>
    <polyline points="${line}" fill="none" stroke="#292c18" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/>
    ${points.map(([x, y]) => `<circle cx="${x}" cy="${y}" r="3.5" fill="#edfc55" stroke="#292c18" stroke-width="1.5"/>`).join('')}
  </svg>`;
}

function renderWeapons() {
  const names = weapons.map(weapon => weapon.name);
  screen.innerHTML = heading('Оружие', 'Сравнение характеристик и времени до убийства') +
    `<div class="control-row">
      ${selectField('first', 'Первое оружие', names, selections.first)}
      ${selectField('second', 'Второе оружие', names, selections.second)}
      ${selectField('armor', 'Броня цели', armors.map(armor => armor.name), selections.armor)}
    </div><div class="panel-grid" id="comparison"></div>`;
  for (const id of ['first', 'second', 'armor']) bindSelect(id, updateWeapons);
  updateWeapons();
}

function updateWeapons() {
  const first = weapons[selections.first];
  const second = weapons[selections.second];
  const armor = armors[selections.armor];
  const rows = [
    ['Урон в корпус', first.damage, second.damage],
    ['Выстрелов в минуту', first.rpm, second.rpm],
    ['Патронов в магазине', first.magazine, second.magazine],
    ['Урон в секунду', first.damage * first.rpm / 60, second.damage * second.rpm / 60],
  ];
  const row = ([label, left, right]) => `<tr><th scope="row">${label}</th>
    <td class="${left > right ? 'metric-best' : ''}">${formatNumber.format(left)}</td>
    <td class="${right > left ? 'metric-best' : ''}">${formatNumber.format(right)}</td></tr>`;
  document.querySelector('#comparison').innerHTML = `<article class="panel"><h2>Характеристики</h2>
    <table class="metric-table"><thead><tr><th scope="col">Показатель</th><th scope="col">${first.name}</th><th scope="col">${second.name}</th></tr></thead>
    <tbody>${rows.map(row).join('')}</tbody></table></article>
    <article class="panel"><h2>Время до убийства</h2><p>Попадания в корпус · ${armor.health} HP</p>
      <div class="ttk-values">${[first, second].map(weapon => ttkRow(weapon, armor.health)).join('')}</div>
    </article>`;
}

function ttkRow(weapon, health) {
  const shots = Math.ceil(health / weapon.damage);
  const seconds = (shots - 1) * 60 / weapon.rpm;
  const value = shots > weapon.magazine ? 'Нужна перезарядка' : `${formatNumber.format(seconds)} с`;
  return `<p><span>${weapon.name}</span><strong>${value}</strong></p>`;
}

function renderBuilds() {
  screen.innerHTML = heading('Сборки', 'Пары оружия и улучшения легенд') + `<div class="panel-grid">
    <article class="panel"><div class="panel-head"><h2>Пары оружия</h2>${icon('weapons')}</div>
      ${selectField('distance', 'Дистанция', builds.map(build => build.name), selections.distance)}
      <div class="pair-list" id="pairs"></div>
    </article>
    <article class="panel"><div class="panel-head"><h2>Улучшения</h2>${icon('builds')}</div>
      ${selectField('guide', 'Легенда', guides.map(guide => guide.name), selections.guide)}
      <div id="guide-styles"></div><div id="upgrades"></div>
    </article></div>`;
  bindSelect('distance', updatePairs);
  bindSelect('guide', () => {
    selections.style = 0;
    updateGuideStyles();
  });
  updatePairs();
  updateGuideStyles();
}

function updatePairs() {
  document.querySelector('#pairs').innerHTML = builds[selections.distance].pairs.map(([first, second, reason]) =>
    `<div class="upgrade"><h3 class="pair"><strong>${first}</strong>${icon('builds')}<strong>${second}</strong></h3><p>${reason}</p></div>`,
  ).join('');
}

function updateGuideStyles() {
  const styles = guides[selections.guide].styles;
  document.querySelector('#guide-styles').innerHTML = selectField('style', 'Стиль игры', styles.map(([name]) => name), selections.style);
  bindSelect('style', updateUpgrades);
  updateUpgrades();
}

function updateUpgrades() {
  const [, ...levels] = guides[selections.guide].styles[selections.style];
  document.querySelector('#upgrades').innerHTML = levels.map(([name, reason], index) =>
    `<section class="upgrade"><h3><span>Ур. ${index + 2}</span> ${name}</h3><p>${reason}</p></section>`,
  ).join('');
}

screen.addEventListener('click', event => {
  const schedule = event.target.closest('[data-schedule]');
  if (schedule) showSchedule(Number(schedule.dataset.schedule));
  const legend = event.target.closest('[data-legend]');
  if (legend) {
    selections.legend = Number(legend.dataset.legend);
    updateLegends(true);
  }
});
screen.addEventListener('error', event => {
  const image = event.target;
  if (image.matches('.map-image') && !image.dataset.fallback) {
    image.dataset.fallback = 'true';
    image.src = 'assets/frontier.webp';
  }
}, true);
zoneSelect.addEventListener('change', () => {
  preferences.zone = zoneSelect.value;
  clock = createClock();
  savePreferences();
  const nextTimes = screen.querySelectorAll('.map-next time');
  shownSlots.forEach((slot, index) => { nextTimes[index].textContent = clock.format(slot.end); });
});
remindersButton.addEventListener('click', showReminders);
window.addEventListener('hashchange', showTab);
updateReminderButton();
showTab();
setInterval(tick, 1000);
