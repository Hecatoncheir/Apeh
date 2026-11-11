String rotationPageFixture(DateTime now, {bool images = false}) {
  int seconds(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;
  String card(String route, String map, String next, Duration untilChange) {
    final change = now.add(untilChange);
    final later = change.add(const Duration(minutes: 15));
    return '''
      <div class="curmap-overview-card" onclick="location.href = '/current-map/$route';">
        <h2>Заголовок режима</h2>
        <div class="container map-image">
          <h2>$map</h2>
          <div id="timer" data-start="${seconds(now.subtract(const Duration(minutes: 5)))}"
             data-end="${seconds(change)}"></div>
        </div>
        <div class="curmap-next-maps">
          <div class="curmap-next-map"><h4>$next</h4><p>
            <span data-tz="${seconds(change)}">время в другом поясе</span>
            <span data-tz="${seconds(later)}">время в другом поясе</span>
          </p></div>
          <div class="curmap-next-map"><h4>Следующая после неё</h4><p>
            <span data-tz="${seconds(later)}"></span>
            <span data-tz="${seconds(later.add(const Duration(minutes: 15)))}"></span>
          </p></div>
        </div>
      </div>
    ''';
  }

  return '''
    ${images ? '<style>.map-image { background-image: url("/assets/maps/map.png"); }</style>' : ''}
    ${card('battle_royale/ranked', 'Storm Point', 'E-District', const Duration(hours: 1))}
    ${card('battle_royale/pubs', 'Broken Moon', 'Storm Point', const Duration(minutes: 30))}
    ${card('mixtape/pubs', 'Monument - Gun Run', 'Thunderdome - TDM', const Duration(minutes: 10))}
    ${card('wildcard/pubs', 'Storm Point - Godzilla Attacks', 'Olympus - Wildcard', const Duration(days: 20, hours: 7))}
  ''';
}
