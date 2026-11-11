enum PatchSection { weapons, legends }

class PatchHighlight {
  const PatchHighlight(this.section, this.id, this.name, this.ru, this.en);

  final PatchSection section;
  final String id;
  final String name;
  final String ru;
  final String en;

  String description({required bool english}) => english ? en : ru;
}

class PatchHighlights {
  PatchHighlights._(this.title, this.source, List<PatchHighlight> changes)
    : changes = List.unmodifiable(changes);

  final String title;
  final Uri source;
  final List<PatchHighlight> changes;

  Map<String, Object?> toJson() => {
    'title': title,
    'source': source.toString(),
    'changes': [
      for (final change in changes)
        {
          'section': change.section.name,
          'id': change.id,
          'name': change.name,
          'ru': change.ru,
          'en': change.en,
        },
    ],
  };

  static PatchHighlights? parse(Object? value) {
    if (value == null) return null;
    if (value
        case {
          'title': final String title,
          'source': final String url,
          'changes': final List<Object?> rows,
        }
        when title.trim().isNotEmpty && rows.isNotEmpty) {
      final source = Uri.tryParse(url);
      if (source != null &&
          source.scheme == 'https' &&
          source.host == 'www.ea.com') {
        return PatchHighlights._(title, source, rows.map(_change).toList());
      }
    }
    throw const FormatException('Неверный формат сводки патча.');
  }

  static PatchHighlight _change(Object? row) {
    if (row
        case {
          'section': final String section,
          'id': final String id,
          'name': final String name,
          'ru': final String ru,
          'en': final String en,
        }
        when [id, name, ru, en].every((text) => text.trim().isNotEmpty)) {
      final kind = PatchSection.values
          .where((item) => item.name == section)
          .firstOrNull;
      if (kind != null) return PatchHighlight(kind, id, name, ru, en);
    }
    throw const FormatException('Неверный пункт сводки патча.');
  }
}
