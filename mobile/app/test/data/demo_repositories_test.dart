import 'package:eho/data/models.dart';
import 'package:eho/data/repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy devsummit ID resolves to the DevFest demo event', () async {
    final e = await DemoEventRepository().getEvent('devsummit');
    expect(e.id, demoEventId);
    expect(e.name, 'DevFest Belgrade 2026');
  });

  test('Find fit lines keep acronyms and proper nouns intact', () async {
    const me = Profile(interests: ['Mobile', 'AI / ML', 'Backend', 'Cloud']);
    final matches = await DemoFindRepository().recommendations('devfest', me);
    final text = matches.map((m) => m.why).join('\n');
    expect(text, contains('on-device ML in production'));
    expect(text, contains('senior Go engineers'));
  });

  test('interest options come from the event repository', () {
    expect(DemoEventRepository().interestOptions, contains('AI / ML'));
  });
}
