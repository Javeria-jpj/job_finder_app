/// Converts the HTML that job boards return into readable plain text.
///
/// Feeds are inconsistent: some send real markup (`<p>`), some send it
/// escaped (`&lt;p&gt;`), and some send escaped markup containing further
/// entities. Decoding therefore runs both before and after tag removal, and
/// repeats while new markup keeps appearing.
library;

const int _maxUnescapePasses = 3;

String htmlToPlainText(String? html, {required String fallback}) {
  if (html == null || html.trim().isEmpty) return fallback;

  var text = html;

  // Decode first: markup that arrived escaped becomes real markup, so the
  // tag-stripping below can actually remove it.
  for (var pass = 0; pass < _maxUnescapePasses; pass++) {
    final decoded = _decodeEntities(text);
    if (decoded == text) break;
    text = decoded;
  }

  text = _stripTags(text);

  // Decode again for entities that were nested inside the markup.
  text = _decodeEntities(text);

  text = text
      // Collapse the blank-line runs left behind by stripped block tags.
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  return text.isEmpty ? fallback : text;
}

String _stripTags(String html) {
  return html
      // Drop content that is never readable text.
      .replaceAll(
        RegExp(
          r'<(script|style)[^>]*>.*?</\1>',
          dotAll: true,
          caseSensitive: false,
        ),
        '',
      )
      // Block-level ends become line breaks.
      .replaceAll(
        RegExp(
          r'<br\s*/?>|</p>|</div>|</h[1-6]>|</tr>|</ul>|</ol>',
          caseSensitive: false,
        ),
        '\n',
      )
      // List items become bullets.
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n• ')
      .replaceAll(RegExp(r'</li>', caseSensitive: false), '')
      // Everything else that looks like a tag goes.
      .replaceAll(RegExp(r'<[^<>]+>'), '');
}

const Map<String, String> _namedEntities = {
  'nbsp': ' ',
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'hellip': '…',
  'mdash': '—',
  'ndash': '–',
  'rsquo': '’',
  'lsquo': '‘',
  'ldquo': '“',
  'rdquo': '”',
  'bull': '•',
  'middot': '·',
  'euro': '€',
  'pound': '£',
  'copy': '©',
  'reg': '®',
  'trade': '™',
  'deg': '°',
};

/// Handles named (`&amp;`), decimal (`&#39;`) and hex (`&#x27;`) entities.
String _decodeEntities(String input) {
  if (!input.contains('&')) return input;

  return input.replaceAllMapped(
    RegExp(r'&(#[xX]?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]{1,10});'),
    (match) {
      final body = match.group(1)!;

      if (body.startsWith('#')) {
        final isHex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
        final digits = isHex ? body.substring(2) : body.substring(1);
        final code = int.tryParse(digits, radix: isHex ? 16 : 10);
        // Reject values outside the valid Unicode range.
        if (code == null || code < 1 || code > 0x10FFFF) return match.group(0)!;
        return String.fromCharCode(code);
      }

      return _namedEntities[body.toLowerCase()] ?? match.group(0)!;
    },
  );
}
