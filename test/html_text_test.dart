import 'package:flutter_test/flutter_test.dart';
import 'package:job_finder_app/data/arbeitnow_repository.dart';
import 'package:job_finder_app/utils/html_text.dart';

String clean(String? html) => htmlToPlainText(html, fallback: 'none');

void main() {
  group('htmlToPlainText', () {
    test('strips ordinary markup', () {
      expect(clean('<p>Hello <strong>world</strong></p>'), 'Hello world');
    });

    test('strips escaped markup — the WPP Media case', () {
      // Exactly what the feed returned: markup arrives escaped, so decoding
      // has to happen before tags are removed, not after.
      const raw =
          '&lt;div class="content-intro"&gt;&lt;p&gt;&lt;strong&gt;'
          'About WPP Media&lt;/strong&gt;&lt;/p&gt;'
          '&lt;p&gt;WPP is the trusted growth partner.&lt;/p&gt;&lt;/div&gt;';

      final text = clean(raw);

      expect(text, contains('About WPP Media'));
      expect(text, contains('WPP is the trusted growth partner.'));
      expect(text, isNot(contains('<')));
      expect(text, isNot(contains('&lt;')));
      expect(text, isNot(contains('div class')));
    });

    test('decodes decimal and hex entities', () {
      expect(clean('WPP&#39;s unit'), "WPP's unit");
      expect(clean('WPP&#x27;s unit'), "WPP's unit");
      expect(clean('R&amp;D &euro;50k'), 'R&D €50k');
      expect(clean('caf&eacute; &hellip;'), contains('…'));
    });

    test('turns list items into bullets and breaks into newlines', () {
      final text = clean('<ul><li>First</li><li>Second</li></ul><br>Done');
      expect(text, contains('• First'));
      expect(text, contains('• Second'));
      expect(text.split('\n').length, greaterThan(2));
    });

    test('drops script and style blocks entirely', () {
      final text = clean(
        '<style>.a{color:red}</style><p>Visible</p>'
        '<script>alert("x")</script>',
      );
      expect(text, 'Visible');
    });

    test('collapses whitespace left by stripped markup', () {
      expect(clean('<p>A</p>\n\n\n\n<p>B</p>'), 'A\n\nB');
    });

    test('falls back when there is nothing readable', () {
      expect(clean(null), 'none');
      expect(clean(''), 'none');
      expect(clean('<div></div>'), 'none');
    });

    test('leaves a lone ampersand alone', () {
      expect(clean('Sales & Marketing'), 'Sales & Marketing');
    });
  });

  test('Arbeitnow mapping produces clean description text', () {
    final job = jobFromArbeitnowJson({
      'slug': 'x',
      'title': 'Senior Video Marketing Manager',
      'company_name': 'wppmedia',
      'location': 'Düsseldorf',
      'description':
          '&lt;p&gt;About WPP&#39;s media unit&lt;/p&gt;&lt;ul&gt;'
          '&lt;li&gt;Own strategy&lt;/li&gt;&lt;/ul&gt;',
    });

    expect(job!.description, isNot(contains('<')));
    expect(job.description, isNot(contains('&#')));
    expect(job.description, contains("About WPP's media unit"));
    expect(job.description, contains('• Own strategy'));
  });
}
