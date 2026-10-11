/// Hardcoded demo content (one fake conference). All names are fictional.
///
/// Stage names match the rooms in the venue-map seed (`backend/maps/cmd/seed`),
/// so "Show on map" can find them.
library;

import 'echo_models.dart';
import 'models.dart';

const demoEventName = 'DevFest Belgrade 2026';
const demoEventDates = 'Oct 11–12, 2026';
const demoEventVenue = 'Sava Centar, Belgrade';

const pastEvent = EventSummary(
  id: 'ai-meetup-ns-2026',
  name: 'AI Meetup Novi Sad',
  dates: 'Sep 18, 2026',
  venue: 'Startit Centar, Novi Sad',
  isPast: true,
);

const stages = ['Glavna sala', 'Sala A', 'Sala B'];

const _mara = Speaker(id: 'sp1', name: 'Mara Ilić', title: 'ML Engineer, Lumen Labs');
const _petar = Speaker(id: 'sp2', name: 'Petar Vuković', title: 'CTO, Orbita');
const _jana = Speaker(id: 'sp3', name: 'Jana Kostić', title: 'Product Designer, Kvadrat');
const _luka = Speaker(id: 'sp4', name: 'Luka Marković', title: 'Staff Engineer, Nebo Cloud');
const _sara = Speaker(id: 'sp5', name: 'Sara Đorđević', title: 'Founder, Talas AI');
const _nikola = Speaker(id: 'sp6', name: 'Nikola Pavlović', title: 'Android GDE');

const speakers = [_mara, _petar, _jana, _luka, _sara, _nikola];

const keynoteId = 's1';

const sessions = [
  Session(
    id: 's0',
    title: 'Registration & coffee',
    stage: 'Glavna sala',
    start: '09:00',
    end: '09:45',
    speakers: [],
    isBreak: true,
  ),
  Session(
    id: keynoteId,
    title: 'On-device AI: when the model lives in your pocket',
    stage: 'Glavna sala',
    start: '10:00',
    end: '10:45',
    speakers: [_mara],
    track: 'AI',
    isLive: true,
    description:
        'What changes in product design, cost and privacy when inference '
        'moves from the cloud to the phone.',
  ),
  Session(
    id: 's2',
    title: 'Scaling event-driven backends on a startup budget',
    stage: 'Sala A',
    start: '11:00',
    end: '11:40',
    speakers: [_luka],
    track: 'Backend',
    description: 'Queues, idempotency and the boring tricks that keep costs flat.',
  ),
  Session(
    id: 's3',
    title: 'Designing for crowded rooms',
    stage: 'Sala B',
    start: '11:00',
    end: '12:30',
    speakers: [_jana],
    track: 'Design',
    description: 'Hands-on workshop: one-handed UX for people standing in a hallway.',
  ),
  Session(
    id: 's4',
    title: 'Lunch',
    stage: 'Glavna sala',
    start: '12:30',
    end: '13:30',
    speakers: [],
    isBreak: true,
  ),
  Session(
    id: 's5',
    title: 'Compose, Flutter, or both? A pragmatic take',
    stage: 'Sala A',
    start: '13:30',
    end: '14:10',
    speakers: [_nikola],
    track: 'Mobile',
    description: 'Lessons from shipping the same app twice.',
  ),
  Session(
    id: 's6',
    title: 'From prototype to paying customers with LLMs',
    stage: 'Glavna sala',
    start: '14:30',
    end: '15:15',
    speakers: [_sara, _petar],
    track: 'AI',
    description: 'Panel: pricing, evaluation and what customers actually pay for.',
  ),
];

/// Pre-recorded keynote transcript, replayed as if live (see docs/MVP.md).
const keynoteTranscript = [
  TranscriptLine(atSeconds: 0, text: 'Good morning everyone, thanks for coming so early.', translated: 'Dobro jutro svima, hvala što ste došli ovako rano.'),
  TranscriptLine(atSeconds: 4, text: 'Today I want to talk about what happens when the model lives on your phone.', translated: 'Danas želim da pričam o tome šta se dešava kada model živi na vašem telefonu.'),
  TranscriptLine(atSeconds: 9, text: 'Three years ago every AI feature meant a round trip to a data center.', translated: 'Pre tri godine svaka AI funkcija značila je odlazak do data centra i nazad.'),
  TranscriptLine(atSeconds: 14, text: 'That round trip costs money on every request, and it costs latency.', translated: 'Taj put košta novac pri svakom zahtevu, i košta kašnjenje.'),
  TranscriptLine(atSeconds: 19, text: 'Small models running locally flip that cost model completely.', translated: 'Mali modeli koji rade lokalno potpuno okreću taj model troškova.'),
  TranscriptLine(atSeconds: 24, text: 'Your marginal cost per user drops close to zero.', translated: 'Vaš granični trošak po korisniku pada skoro na nulu.'),
  TranscriptLine(atSeconds: 29, text: 'The second big change is privacy: the data never leaves the device.', translated: 'Druga velika promena je privatnost: podaci nikada ne napuštaju uređaj.'),
  TranscriptLine(atSeconds: 34, text: 'For health or finance apps, that alone can unblock a product.', translated: 'Za zdravstvene ili finansijske aplikacije, samo to može da odblokira proizvod.'),
  TranscriptLine(atSeconds: 39, text: 'But there are trade-offs. Battery is the first one people forget.', translated: 'Ali postoje kompromisi. Baterija je prvi koji ljudi zaborave.'),
  TranscriptLine(atSeconds: 44, text: 'We measured a twelve percent battery hit for continuous transcription.', translated: 'Izmerili smo pad baterije od dvanaest procenata za neprekidnu transkripciju.'),
  TranscriptLine(atSeconds: 50, text: 'The fix was batching: process audio in chunks, not every frame.', translated: 'Rešenje je bilo grupisanje: obrađujte zvuk u delovima, ne svaki okvir.'),
  TranscriptLine(atSeconds: 55, text: 'The second trade-off is model size. You cannot ship forty gigabytes.', translated: 'Drugi kompromis je veličina modela. Ne možete isporučiti četrdeset gigabajta.'),
  TranscriptLine(atSeconds: 60, text: 'Quantization gets you to around one or two gigabytes with small quality loss.', translated: 'Kvantizacija vas dovodi do jednog ili dva gigabajta uz mali gubitak kvaliteta.'),
  TranscriptLine(atSeconds: 66, text: 'And the third: you need a fallback to the cloud for the hard questions.', translated: 'I treći: potreban vam je rezervni put ka oblaku za teška pitanja.'),
  TranscriptLine(atSeconds: 71, text: 'We call that a hybrid router. Easy questions local, hard ones remote.', translated: 'To zovemo hibridni ruter. Laka pitanja lokalno, teška na serveru.'),
  TranscriptLine(atSeconds: 77, text: 'In our app the router keeps eighty percent of requests on the device.', translated: 'U našoj aplikaciji ruter zadržava osamdeset procenata zahteva na uređaju.'),
  TranscriptLine(atSeconds: 83, text: 'So my advice: start hybrid, measure, and move work down to the device over time.', translated: 'Moj savet: počnite hibridno, merite, i vremenom prebacujte posao na uređaj.'),
  TranscriptLine(atSeconds: 90, text: 'Thank you. I think we have a few minutes for questions.', translated: 'Hvala vam. Mislim da imamo nekoliko minuta za pitanja.'),
];

const keynoteCatchUp =
    'Mara argues that running models on the phone cuts per-user cost to almost '
    'zero and keeps data private. Trade-offs so far: battery (fixed with '
    'batching) and model size (fixed with quantization).';

const keynoteSummary = '''On-device AI: when the model lives in your pocket — Mara Ilić

Key points
• Running small models locally flips the cost model: marginal cost per user drops close to zero.
• Privacy is the second win: data never leaves the device, which can unblock health and finance products.

Trade-offs and fixes
• Battery: continuous transcription cost 12% battery. Fix: process audio in batches.
• Size: large models can't ship. Fix: quantization to ~1–2 GB with small quality loss.
• Hard questions: use a "hybrid router" — easy requests local, hard ones in the cloud. In their app, 80% stay on device.

Takeaway
Start hybrid, measure, and move work to the device over time.''';

/// The structured summary (`TalkSummary`, Echo 0.3.0); trade-off times are
/// the transcript lines above where each problem is stated.
const keynoteTalkSummary = TalkSummary(
  takeaway: 'Start hybrid, measure, and move work to the device over time.',
  keyPoints: [
    'Running small models locally flips the cost model: marginal cost per user drops close to zero.',
    'Privacy is the second win: data never leaves the device, which can unblock health and finance products.',
  ],
  tradeoffs: [
    EchoTradeoff(topic: 'Battery', issue: '12% hit for continuous transcription', fix: 'process audio in batches', atSeconds: 44),
    EchoTradeoff(topic: 'Model size', issue: 'You can\'t ship forty gigabytes', fix: 'quantization to ~1–2 GB with small quality loss', atSeconds: 55),
    EchoTradeoff(topic: 'Hard questions', issue: 'The small model can\'t answer everything', fix: 'hybrid router: easy requests local, hard ones in the cloud; 80% stay on device', atSeconds: 66),
  ],
);

/// Serbian versions (Echo with translate on asks for `language=sr`).
const keynoteCatchUpSr =
    'Mara tvrdi da pokretanje modela na telefonu spušta trošak po korisniku '
    'skoro na nulu i čuva privatnost podataka. Kompromisi do sada: baterija '
    '(rešena grupisanjem) i veličina modela (rešena kvantizacijom).';

const keynoteSummaryTextSr = '''On-device AI: when the model lives in your pocket — Mara Ilić

Ključne tačke
• Mali modeli koji rade lokalno okreću model troškova: granični trošak po korisniku pada skoro na nulu.
• Privatnost je druga dobit: podaci nikada ne napuštaju uređaj, što može da odblokira zdravstvene i finansijske proizvode.

Kompromisi i rešenja
• Baterija: neprekidna transkripcija trošila je 12% baterije. Rešenje: obrada zvuka u delovima.
• Veličina: veliki modeli ne mogu da se isporuče. Rešenje: kvantizacija na ~1–2 GB uz mali gubitak kvaliteta.
• Teška pitanja: „hibridni ruter" — laki zahtevi lokalno, teški u oblaku. U njihovoj aplikaciji 80% ostaje na uređaju.

Zaključak
Počnite hibridno, merite, i vremenom prebacujte posao na uređaj.''';

const keynoteTalkSummarySr = TalkSummary(
  takeaway: 'Počnite hibridno, merite, i vremenom prebacujte posao na uređaj.',
  keyPoints: [
    'Mali modeli koji rade lokalno okreću model troškova: granični trošak po korisniku pada skoro na nulu.',
    'Privatnost je druga dobit: podaci nikada ne napuštaju uređaj, što može da odblokira zdravstvene i finansijske proizvode.',
  ],
  tradeoffs: [
    EchoTradeoff(topic: 'Baterija', issue: 'pad od 12% za neprekidnu transkripciju', fix: 'obrada zvuka u delovima', atSeconds: 44),
    EchoTradeoff(topic: 'Veličina modela', issue: 'ne možete isporučiti četrdeset gigabajta', fix: 'kvantizacija na ~1–2 GB uz mali gubitak kvaliteta', atSeconds: 55),
    EchoTradeoff(topic: 'Teška pitanja', issue: 'mali model ne može da odgovori na sve', fix: 'hibridni ruter: laki zahtevi lokalno, teški u oblaku; 80% ostaje na uređaju', atSeconds: 66),
  ],
);

/// Canned "Ask the talk" answers for the demo, matched by keyword.
const keynoteAnswers = <String, String>{
  'battery':
      'Mara said continuous transcription cost about 12% battery. Their fix was batching: processing audio in chunks instead of every frame.',
  'size':
      'She said you can\'t ship huge models; quantization brings them to roughly 1–2 GB with a small quality loss.',
  'router':
      'A "hybrid router" sends easy questions to the on-device model and hard ones to the cloud. In their app about 80% of requests stay on the device.',
  'cost':
      'Running the model locally makes the marginal cost per user drop close to zero, because there is no cloud round trip per request.',
  'privacy':
      'With on-device inference the data never leaves the phone, which Mara said can unblock health or finance apps.',
};

const keynoteDefaultAnswer =
    'Based on the talk so far: Mara\'s main point is that on-device models cut cost and protect privacy, '
    'with battery and model size as the main trade-offs, handled by batching and quantization.';

/// Serbian word stems that select the same canned answer (by English key).
const keynoteAnswerKeywordsSr = <String, String>{
  'battery': 'bater',
  'size': 'veličin',
  'router': 'ruter',
  'cost': 'troš',
  'privacy': 'privatn',
};

/// [keynoteAnswers] in Serbian, by the same keys.
const keynoteAnswersSr = <String, String>{
  'battery':
      'Mara je rekla da je neprekidna transkripcija trošila oko 12% baterije. Rešenje je bilo grupisanje: zvuk se obrađuje u delovima umesto svakog okvira posebno. Mara to pominje na 00:50.',
  'size':
      'Rekla je da ogromni modeli ne mogu da se isporuče; kvantizacija ih spušta na oko 1–2 GB uz mali gubitak kvaliteta.',
  'router':
      '„Hibridni ruter" šalje laka pitanja modelu na uređaju, a teška u oblak. U njihovoj aplikaciji oko 80% zahteva ostaje na uređaju.',
  'cost':
      'Kada model radi lokalno, granični trošak po korisniku pada skoro na nulu, jer nema odlaska u oblak za svaki zahtev.',
  'privacy':
      'Kada model radi na uređaju, podaci nikada ne napuštaju telefon, što po Marinim rečima može da odblokira zdravstvene ili finansijske aplikacije.',
};

const keynoteDefaultAnswerSr =
    'Na osnovu dosadašnjeg predavanja: Marina glavna poenta je da modeli na uređaju smanjuju trošak i čuvaju privatnost, '
    'a glavni kompromisi su baterija i veličina modela, rešeni grupisanjem i kvantizacijom.';

/// (id, text, votes, mergedCount, mine, voted). Like the design: the second
/// one is the user's own and already voted for.
const keynoteQuestions = [
  ('q1', 'Which model did you use for the hybrid router?', 14, 3, false, false),
  ('q2', 'How do you update on-device models without app releases?', 9, 0, true, true),
  ('q3', 'Does quantization hurt Serbian language quality?', 6, 0, false, false),
  ('q4', 'What battery hit do you see on older phones?', 4, 0, false, false),
  ('q5', 'How do you test the small model against the cloud one?', 3, 1, false, false),
  ('q6', 'What happens to a hard question when the phone is offline?', 3, 0, false, false),
  ('q7', 'Do you run inference on the GPU or the NPU?', 2, 0, false, false),
  ('q8', 'How big is the app download with the model inside?', 2, 0, false, false),
  ('q9', 'Did users notice any quality drop after quantization?', 2, 0, false, false),
  ('q10', 'Which phones are too old to run the model at all?', 2, 0, false, false),
  ('q11', 'Any tips for testing on-device models in CI?', 2, 0, false, false),
  ('q12', 'Would you do it on-device again for a brand new app?', 2, 0, false, false),
];

/// A demo question mentioning this is merged into the first one, like the
/// server's AI grouping (Echo 0.3.0).
const keynoteMergeKeyword = 'router';

const interestOptions = [
  'AI / ML',
  'Mobile',
  'Backend',
  'Design',
  'Startups',
  'Cloud',
  'Product',
  'Data',
  'Security',
  'Hiring',
];

const people = [
  Person(id: 'p1', name: 'Ana Petrović', headline: 'Android dev at Fintio', interests: ['Mobile', 'AI / ML'], lookingFor: 'People who shipped on-device ML in production'),
  Person(id: 'p2', name: 'Milan Jovanović', headline: 'Founder, ParkIt', interests: ['Startups', 'Mobile'], lookingFor: 'A technical co-founder'),
  Person(id: 'p3', name: 'Teodora Nikolić', headline: 'ML researcher, Univ. of Belgrade', interests: ['AI / ML', 'Data'], lookingFor: 'Industry partners for speech models'),
  Person(id: 'p4', name: 'Stefan Lazić', headline: 'Backend lead at Nebo Cloud', interests: ['Backend', 'Cloud'], lookingFor: 'Senior Go engineers'),
  Person(id: 'p5', name: 'Ivana Milić', headline: 'Product manager, Kvadrat', interests: ['Product', 'Design'], lookingFor: 'Designers interested in AI products'),
  Person(id: 'p6', name: 'Dušan Ristić', headline: 'iOS & Flutter freelancer', interests: ['Mobile', 'Design'], lookingFor: 'Interesting side projects'),
  Person(id: 'p7', name: 'Jelena Stanković', headline: 'Data engineer, Orbita', interests: ['Data', 'Cloud'], lookingFor: 'People running LLMs on a budget'),
  Person(id: 'p8', name: 'Marko Simić', headline: 'Security engineer', interests: ['Security', 'Backend'], lookingFor: 'Talks on AI security'),
  Person(id: 'p9', name: 'Nina Popović', headline: 'Designer at Talas AI', interests: ['Design', 'AI / ML'], lookingFor: 'Mobile devs to prototype with'),
  Person(id: 'p10', name: 'Vuk Tomić', headline: 'CTO, Mreža', interests: ['Startups', 'Backend', 'Hiring'], lookingFor: 'Mobile engineers to hire'),
  Person(id: 'p11', name: 'Katarina Božić', headline: 'Speech tech PhD student', interests: ['AI / ML', 'Data'], lookingFor: 'Teams building transcription'),
  Person(id: 'p12', name: 'Aleksa Kovačević', headline: 'Junior Android dev', interests: ['Mobile'], lookingFor: 'A mentor in mobile AI'),
  // The keynote speaker, findable like the attendees (search only).
  Person(id: 'p13', name: 'Mara Ilić', headline: 'Speaker · ML Engineer, Lumen Labs', interests: ['AI / ML', 'Mobile'], lookingFor: 'Questions about on-device AI after the keynote'),
];

/// People who are speakers: they show up in search results, not in
/// "Recommended for you".
const speakerPersonIds = {'p13'};

/// Hand-written "why you should meet" lines, as the AI would write them
/// (`Match.why` in `contracts/find`).
const fitLines = <String, String>{
  'p1': 'You both care about mobile and AI. Ana is looking for people who shipped on-device ML, which is exactly your project.',
  'p2': 'Building a parking app and looking for a technical co-founder. Worth a coffee if you have ever thought about starting something.',
  'p3': "Works on speech models and wants industry partners. Good fit if you're building transcription.",
  'p4': 'Leads the backend team at Nebo Cloud and is hiring senior Go engineers.',
  'p5': 'Runs product at Kvadrat and wants designers who are curious about AI products.',
  'p6': 'Builds iOS and Flutter apps for clients and is always up for an interesting side project.',
  'p7': 'Runs data pipelines at Orbita and wants to swap notes on running LLMs on a budget.',
  'p8': 'Works on security and wants to hear how teams keep their AI features safe.',
  'p9': 'Looking for mobile devs to prototype AI features with.',
  'p10': "Hiring mobile engineers for Mreža. Good to know if you're open to a move.",
  'p11': 'Researches speech tech and wants to meet teams building transcription.',
  'p12': 'Junior Android dev looking for a mentor in mobile AI. You could help a lot.',
  'p13': "Gave today's keynote on on-device AI. Open to questions after 15:00.",
};

/// Tie-break order for "Recommended for you" (people with the same number of
/// shared interests): the design shows Ana, Teodora, Nina first.
const recommendationOrder = ['p1', 'p3', 'p9', 'p11', 'p12', 'p2', 'p6', 'p7', 'p10', 'p4', 'p5', 'p8'];

/// Canned AI search results: a prompt containing any of the keywords gets
/// these people, in this order, with this copy. Other prompts fall back to
/// keyword matching with [fitLines].
const demoSearches = <(List<String>, List<(String, String)>)>[
  (
    ['on-device', 'android', 'ml', 'model'],
    [
      ('p1', 'Shipped a quantized on-device model in a banking app last year. Looking to compare notes with others who did the same.'),
      ('p11', 'Runs small speech models on phones for her research. Wants to meet teams building transcription.'),
      ('p13', "Gave today's keynote on on-device AI. Open to questions after 15:00."),
    ],
  ),
  (
    ['co-founder', 'cofounder', 'founder', 'startup'],
    [
      ('p2', 'Building ParkIt and looking for a technical co-founder. He has paying pilots and needs someone to own the app.'),
      ('p10', 'Started Mreža two years ago and is happy to talk about finding a co-founder, and about hiring.'),
    ],
  ),
  (
    ['design', 'designer', 'ux'],
    [
      ('p9', 'Designs AI features at Talas AI and wants mobile devs to prototype them with.'),
      ('p5', 'Product manager at Kvadrat, looking for designers who are curious about AI products.'),
      ('p6', 'Freelances in iOS and Flutter with a strong eye for design. Open to side projects.'),
    ],
  ),
  (
    ['hire', 'hiring', 'job', 'recruit'],
    [
      ('p10', 'Hiring mobile engineers for Mreža right now.'),
      ('p4', 'Hiring senior Go engineers for the backend team at Nebo Cloud.'),
    ],
  ),
];

/// Floor the demo places are on when the venue map isn't loaded (the seeded
/// map has a single ground floor).
const demoFloorName = 'Ground floor';

/// Meeting time agreed in [demoMessages].
const demoMeetingTime = '15:20';

/// Hardcoded conversation for the mock Messages screen (see docs/MVP.md).
const demoMessages = [
  (false, 'Hi! Saw your request. I\'d love to compare notes on on-device ML.'),
  (true, 'Great! I\'m building a hybrid router like the one from the keynote.'),
  (false, 'Nice. I\'m free after the panel, around 15:20?'),
];
