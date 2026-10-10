import '../model/map_models.dart';

const _fold = {
  'č': 'c',
  'ć': 'c',
  'š': 's',
  'ž': 'z',
  'đ': 'dj',
  'á': 'a',
  'à': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ñ': 'n',
  'ç': 'c',
  'ý': 'y',
};

/// Lowercases and folds diacritics ("Čačak" → "cacak", "Đorđe" → "djordje")
/// and collapses whitespace, so searches ignore case and accents.
String normalizeSearch(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    b.write(_fold[ch] ?? ch);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Filter by feature kind in the search UI.
enum SearchFilter { all, rooms, stands, pois }

bool _passes(Feature f, SearchFilter filter) => switch (filter) {
  SearchFilter.all => f.type != FeatureType.marker,
  SearchFilter.rooms => f.type == FeatureType.room,
  SearchFilter.stands => f.type == FeatureType.stand,
  SearchFilter.pois => f.type == FeatureType.poi,
};

/// Client-side search over the published features (no server, no LLM).
class FeatureSearch {
  /// [labelOf] returns extra searchable words for a feature, e.g. the
  /// localized type ("štand", "toalet").
  FeatureSearch(
    List<Feature> features, {
    required String Function(Feature) labelOf,
  }) : _entries = [
         for (final f in features)
           if (f.type != FeatureType.marker)
             (
               feature: f,
               name: normalizeSearch(f.name),
               text: normalizeSearch(
                 [
                   f.name,
                   f.company,
                   f.category,
                   f.description,
                   labelOf(f),
                 ].join(' '),
               ),
             ),
       ];

  final List<({Feature feature, String name, String text})> _entries;

  /// Categories of stands, sorted, for filter chips.
  List<String> get categories {
    final set = {
      for (final e in _entries)
        if (e.feature.category.isNotEmpty) e.feature.category,
    };
    return set.toList()
      ..sort((a, b) => normalizeSearch(a).compareTo(normalizeSearch(b)));
  }

  /// Every query word must appear in the feature's text. Results whose name
  /// starts with the query come first, then alphabetical.
  List<Feature> search(
    String query, {
    SearchFilter filter = SearchFilter.all,
    String? category,
  }) {
    final q = normalizeSearch(query);
    final words = q.isEmpty ? const <String>[] : q.split(' ');
    final hits =
        _entries.where((e) {
          if (!_passes(e.feature, filter)) return false;
          if (category != null && e.feature.category != category) return false;
          return words.every(e.text.contains);
        }).toList()..sort((a, b) {
          final pa = q.isNotEmpty && a.name.startsWith(q) ? 0 : 1;
          final pb = q.isNotEmpty && b.name.startsWith(q) ? 0 : 1;
          return pa != pb ? pa - pb : a.name.compareTo(b.name);
        });
    return [for (final e in hits) e.feature];
  }
}
