final _blockTags = RegExp(r'<br\s*/?>|</p>|</li>', caseSensitive: false);
final _listItemTag = RegExp(r'<li[^>]*>', caseSensitive: false);
final _anyTag = RegExp(r'<[^>]*>');
final _blankLines = RegExp(r'\n{3,}');

const _entities = {
  '&amp;': '&',
  '&quot;': '"',
  '&#39;': "'",
  '&apos;': "'",
  '&lt;': '<',
  '&gt;': '>',
  '&nbsp;': ' ',
};

/// Google Books descriptions come back as raw HTML (`<br>`, `<p>`, `<li>`,
/// entities) with no plaintext alternative — this renders them readable.
String stripHtml(String input) {
  var text = input.replaceAll(_blockTags, '\n');
  text = text.replaceAllMapped(_listItemTag, (_) => '• ');
  text = text.replaceAll(_anyTag, '');
  for (final entry in _entities.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  text = text.replaceAll(_blankLines, '\n\n');
  return text.trim();
}
