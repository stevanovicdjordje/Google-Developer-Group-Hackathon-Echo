import 'package:eho/data/demo_data.dart' as demo;
import 'package:eho/data/models.dart';
import 'package:eho/data/repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy devsummit ID resolves to the DevFest demo event', () async {
    final e = await DemoEventRepository().getEvent('devsummit');
    expect(e.id, demoEventId);
    expect(e.name, 'DevFest Belgrade 2026');
  });

  test(
    'Find recommendations: three, hand-written reasons, no speakers',
    () async {
      const me = Profile(interests: ['Mobile', 'AI / ML']);
      final matches = await DemoFindRepository().recommendations('devfest', me);
      expect([for (final m in matches) m.person.id], ['p1', 'p3', 'p9']);
      expect(matches.first.why, demo.fitLines['p1']);
      for (final m in matches) {
        expect(m.why, isNot(contains('looking for:')));
      }
    },
  );

  test('Find search: canned prompt includes the speaker', () async {
    final matches = await DemoFindRepository().search(
      'devfest',
      'On-device ML on Android',
    );
    expect(
      [for (final m in matches) m.person.name],
      ['Ana Petrović', 'Katarina Božić', 'Mara Ilić'],
    );
    expect(matches.last.person.headline, 'Speaker · ML Engineer, Lumen Labs');
    // "html" is not the "ml" keyword: falls back to profile matching.
    final other = await DemoFindRepository().search('devfest', 'html');
    expect(other, isEmpty);
  });

  test('meeting spot keeps time and floor across a save', () {
    const spot = MeetingSpot(
      personName: 'Ana Petrović',
      place: 'Info pult',
      time: '15:20',
      floor: 'Ground floor',
    );
    final back = MeetingSpot.fromJson(spot.toJson());
    expect(
      (back.place, back.time, back.floor),
      ('Info pult', '15:20', 'Ground floor'),
    );
    final old = MeetingSpot.fromJson({'personName': 'Ana', 'place': 'Sala A'});
    expect((old.time, old.floor), (null, null));
  });

  test('interest options come from the event repository', () {
    expect(DemoEventRepository().interestOptions, contains('AI / ML'));
  });
}
