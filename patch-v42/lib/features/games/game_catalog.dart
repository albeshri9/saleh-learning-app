import 'dart:math';

enum GameWorld { words, numbers, thinking }

enum PlayKind {
  choose,
  collect,
  order,
  memory,
  counter,
  distribute,
  value,
  sort,
  puzzle,
  mosaic,
  mirror,
  maze,
  pipes,
  bridge,
  robot
}

class GameSpec {
  const GameSpec(
      this.id, this.title, this.skill, this.world, this.kind, this.art);
  final String id, title, skill;
  final GameWorld world;
  final PlayKind kind;
  final int art;
  int get roundCount => kind == PlayKind.memory ? 4 : 3;
  int get level => const {
        'sentence',
        'letter_family',
        'place_value',
        'shop',
        'robot',
        'positions',
        'symmetry'
      }.contains(id)
          ? 3
          : const {
              'build_word',
              'missing_letter',
              'word_train',
              'word_workshop',
              'add',
              'subtract',
              'ten_frame',
              'share',
              'story_math',
              'tangram',
              'bridge',
              'connect_path'
            }.contains(id)
              ? 2
              : 1;
}

const gameCatalog = <GameSpec>[
  GameSpec('picture_word', 'الصورة وكلمتها', 'أربط الكلمة بالصورة',
      GameWorld.words, PlayKind.choose, 0),
  GameSpec('letter_basket', 'سلة الحرف', 'أميز الحرف الأول', GameWorld.words,
      PlayKind.collect, 1),
  GameSpec('build_word', 'ركّب الكلمة', 'أرتب حروف الكلمة', GameWorld.words,
      PlayKind.order, 8),
  GameSpec('missing_letter', 'الحرف المفقود', 'أكمل الحرف الناقص',
      GameWorld.words, PlayKind.choose, 3),
  GameSpec('listen_find', 'أسمع وأجد', 'أربط الصوت بالصورة', GameWorld.words,
      PlayKind.choose, 0),
  GameSpec('word_train', 'قطار الكلمات', 'أربط الصورة والاسم والحرف',
      GameWorld.words, PlayKind.order, 2),
  GameSpec('word_memory', 'ذاكرة الصورة والكلمة', 'أتذكر الصورة واسمها',
      GameWorld.words, PlayKind.memory, 7),
  GameSpec('letter_lens', 'عدسة الحروف', 'أجد الحرف داخل الكلمة',
      GameWorld.words, PlayKind.collect, 4),
  GameSpec('letter_family', 'عائلة الحرف', 'أميز أشكال الحرف', GameWorld.words,
      PlayKind.collect, 8),
  GameSpec('word_workshop', 'ورشة الكلمات', 'أصلح الحرف الخطأ', GameWorld.words,
      PlayKind.choose, 9),
  GameSpec('picture_market', 'سوق الصور', 'أختار اسم المنتج', GameWorld.words,
      PlayKind.choose, 5),
  GameSpec('sentence', 'ابنِ جملة', 'أرتب كلمات جملة', GameWorld.words,
      PlayKind.order, 1),
  GameSpec('feed_rabbit', 'أطعم الأرنب', 'أعد قطع الجزر', GameWorld.numbers,
      PlayKind.counter, 1),
  GameSpec('number_picture', 'الرقم وصورته', 'أربط الرقم بالكمية',
      GameWorld.numbers, PlayKind.choose, 4),
  GameSpec('number_train', 'قطار الأعداد', 'أرتب الأعداد', GameWorld.numbers,
      PlayKind.order, 10),
  GameSpec('compare', 'أيهما أكثر؟', 'أقارن الكميات', GameWorld.numbers,
      PlayKind.choose, 5),
  GameSpec('add', 'اجمع في السلة', 'أجمع مجموعتين', GameWorld.numbers,
      PlayKind.counter, 4),
  GameSpec('subtract', 'كم بقي؟', 'أطرح وأجد الباقي', GameWorld.numbers,
      PlayKind.counter, 4),
  GameSpec('ten_frame', 'أكمل الصندوق', 'أكمل العدد عشرة', GameWorld.numbers,
      PlayKind.counter, 6),
  GameSpec('share', 'وزّع بالتساوي', 'أوزع كميات متساوية', GameWorld.numbers,
      PlayKind.distribute, 4),
  GameSpec('place_value', 'ابنِ العدد', 'أتعرف على الآحاد والعشرات',
      GameWorld.numbers, PlayKind.value, 10),
  GameSpec('shop', 'متجر صالح', 'أكوّن المبلغ المطلوب', GameWorld.numbers,
      PlayKind.value, 5),
  GameSpec('measure', 'قِس الجسر', 'أقيس بوحدات متساوية', GameWorld.numbers,
      PlayKind.counter, 9),
  GameSpec('story_math', 'مسألة في صورة', 'أحل مسألة مصورة', GameWorld.numbers,
      PlayKind.choose, 2),
  GameSpec('pattern', 'أكمل النمط', 'أكتشف القاعدة', GameWorld.thinking,
      PlayKind.choose, 11),
  GameSpec('odd', 'من المختلف؟', 'ألاحظ الاختلاف', GameWorld.thinking,
      PlayKind.choose, 3),
  GameSpec('sort', 'صناديق الفرز', 'أصنف الأشكال', GameWorld.thinking,
      PlayKind.sort, 5),
  GameSpec('jigsaw', 'الصورة المقطعة', 'أجمع أجزاء الصورة', GameWorld.thinking,
      PlayKind.puzzle, 0),
  GameSpec('tangram', 'اصنع الشكل', 'أركب أشكالًا هندسية', GameWorld.thinking,
      PlayKind.mosaic, 9),
  GameSpec('symmetry', 'أكمل النصف', 'أبني صورة متناظرة', GameWorld.thinking,
      PlayKind.mirror, 11),
  GameSpec(
      'maze', 'طريق صالح', 'أخطط للطريق', GameWorld.thinking, PlayKind.maze, 9),
  GameSpec('connect_path', 'صِل الطريق', 'أدير قطع المسار', GameWorld.thinking,
      PlayKind.pipes, 10),
  GameSpec('bridge', 'ابنِ الجسر', 'أختار أطوالًا مناسبة', GameWorld.thinking,
      PlayKind.bridge, 9),
  GameSpec('sequence', 'ماذا يحدث أولًا؟', 'أرتب مراحل النمو',
      GameWorld.thinking, PlayKind.order, 11),
  GameSpec('robot', 'روبوت الخطوات', 'أخطط ثم أنفذ', GameWorld.thinking,
      PlayKind.robot, 10),
  GameSpec('positions', 'لغز المكان', 'أستنتج موضع كل عنصر', GameWorld.thinking,
      PlayKind.order, 1),
];

const worldTitles = ['حديقة الكلمات', 'ورشة الأعداد', 'جزيرة التفكير'];
const worldDescriptions = [
  'أسمع • أكتشف • أركّب',
  'أعدّ • أجمع • أقيس',
  'ألاحظ • أخطط • أبني'
];
String digits(int n) =>
    '$n'.split('').map((e) => '٠١٢٣٤٥٦٧٨٩'[int.parse(e)]).join();
const objectWords = [
  'أسد',
  'أرنب',
  'بطة',
  'ثعلب',
  'تفاح',
  'موز',
  'جزر',
  'سمك',
  'باب',
  'بيت',
  'روبوت',
  'شجرة'
];

/// Face values keep image identity separate from ordering and answer indices.
class GameItem {
  const GameItem(this.id,
      {this.text = '', this.art, this.amount, this.shape, this.tone = 0});
  final String id, text;
  final int? art, amount, shape;
  final int tone;
}

class GameRound {
  const GameRound(
      {required this.prompt,
      this.caption = '',
      this.hero,
      this.items = const [],
      this.answer = const [],
      this.target = 0,
      this.start = 0,
      this.a = 0,
      this.b = 0,
      this.audio,
      this.grid = const [],
      this.hint = ''});
  final String prompt, caption, hint;
  final int? hero;
  final List<GameItem> items;
  final List<String> answer;
  final int target, start, a, b;
  final String? audio;
  final List<int> grid;
}

GameItem word(int i, {bool image = false}) =>
    GameItem('w$i', text: image ? '' : objectWords[i], art: image ? i : null);
GameItem number(int n) => GameItem('n$n', text: digits(n));
GameItem shape(int n, {int tone = 0, String? id}) =>
    GameItem(id ?? 's$n', shape: n, tone: tone);

/// Three intentionally short authored rounds per game. Stable IDs are the
/// content contract; shuffled UI positions never determine correctness.
GameRound roundFor(GameSpec game, int round) {
  final r = round % 3;
  final animal = switch (game.id) {
    'picture_word' => [0, 7, 9][r],
    'build_word' => [8, 5, 7][r],
    'word_train' => [4, 6, 11][r],
    _ => [0, 2, 3][r]
  };
  final w = objectWords[animal];
  switch (game.id) {
    case 'picture_word':
      return GameRound(
          prompt: 'اختر اسم الصورة',
          hero: animal,
          items: [
            word(animal),
            ...[0, 2, 3, 7, 9].where((i) => i != animal).take(3).map(word)
          ],
          answer: ['w$animal'],
          hint: 'لاحظ أول حرف من اسم الصورة');
    case 'letter_basket':
      return GameRound(
          prompt: 'اجمع الصور التي تبدأ بـ «${['أ', 'ب', 'ت'][r]}»',
          caption: 'اضغط الصور المناسبة لتضعها في السلة',
          items: [
            for (final i in [0, 1, 2, 4, 8, 9]) word(i, image: true)
          ],
          answer: [
            ['w0', 'w1'],
            ['w2', 'w8', 'w9'],
            ['w4']
          ][r],
          hint: 'انطق اسم كل صورة ببطء');
    case 'build_word':
      return GameRound(
          prompt: 'ركّب اسم الصورة',
          hero: animal,
          caption: r == 0 ? w : 'اضغط الحروف بالترتيب',
          items: [
            for (var i = 0; i < w.length; i++) GameItem('c$i', text: w[i])
          ],
          answer: [for (var i = 0; i < w.length; i++) 'c$i'],
          hint: 'ابدأ من اليمين');
    case 'missing_letter':
      return GameRound(
          prompt: 'ما الحرف الناقص؟',
          hero: animal,
          caption: ['أ ــ د', 'ب ــ ة', 'ث ــ ل ب'][r],
          items: [
            for (final c in ['س', 'ع', 'ط', 'م']) GameItem(c, text: c)
          ],
          answer: [
            ['س', 'ط', 'ع'][r]
          ],
          hint: 'انطق الكلمة وحدد الصوت الناقص');
    case 'listen_find':
      return GameRound(
          prompt: 'اسمع ثم اختر الصورة',
          caption: 'اضغط زر الصوت لسماع الكلمة',
          audio: 'assets/audio/alif/explain_3.mp3',
          items: [
            for (final i in [0, 1, 2, 3]) word(i, image: true)
          ],
          answer: ['w0'],
          hint: 'الكلمة المسموعة تبدأ بالألف');
    case 'word_train':
      return GameRound(
          prompt: 'املأ القطار: الصورة، ثم اسمها، ثم أول حرف',
          hero: animal,
          items: [
            GameItem('picture', art: animal),
            GameItem('word', text: w),
            GameItem('letter', text: w[0])
          ],
          answer: ['picture', 'word', 'letter'],
          hint: 'الصورة في المحطة الأولى يمينًا');
    case 'word_memory':
      return GameRound(
          prompt: 'ابحث عن كل صورة واسمها',
          items: [
            for (final i in [0, 2, 4, 7, 9].take(2 + round.clamp(0, 3))) ...[
              GameItem('p$i', art: i),
              GameItem('t$i', text: objectWords[i])
            ]
          ],
          answer: const [],
          hint: 'تذكّر مكان الصورة ثم ابحث عن اسمها');
    case 'letter_lens':
      final letters = [
        ['ب', 'ا', 'ب'],
        ['أ', 'ر', 'ن', 'ب'],
        ['س', 'م', 'ك']
      ][r];
      final target = ['ب', 'ر', 'م'][r];
      return GameRound(
          prompt: 'ابحث عن «$target» في الكلمة',
          caption: ['باب', 'أرنب', 'سمك'][r],
          hero: [8, 1, 7][r],
          items: [
            for (var i = 0; i < letters.length; i++)
              GameItem('c$i', text: letters[i])
          ],
          answer: [
            for (var i = 0; i < letters.length; i++)
              if (letters[i] == target) 'c$i'
          ],
          hint: 'قد يظهر الحرف أكثر من مرة');
    case 'letter_family':
      final forms = [
        ['ب', 'بـ', 'ـبـ', 'ـب'],
        ['س', 'سـ', 'ـسـ', 'ـس'],
        ['م', 'مـ', 'ـمـ', 'ـم']
      ][r];
      return GameRound(
          prompt: 'اجمع أشكال حرف «${forms[0]}»',
          caption: 'الحرف نفسه في مواضع مختلفة',
          items: [
            for (var i = 0; i < 4; i++) GameItem('f$i', text: forms[i]),
            const GameItem('x', text: 'ن'),
            const GameItem('y', text: 'ثـ')
          ],
          answer: const ['f0', 'f1', 'f2', 'f3'],
          hint: 'لاحظ شكل الحرف والنقاط');
    case 'word_workshop':
      return GameRound(
          prompt: 'اختر الحرف الذي يصلح الكلمة',
          hero: [8, 7, 5][r],
          caption: ['تاب ← ــاب', 'نمك ← ــمك', 'لوز ← ــوز'][r],
          items: [
            for (final c in ['ب', 'س', 'م', 'ن']) GameItem(c, text: c)
          ],
          answer: [
            ['ب', 'س', 'م'][r]
          ],
          hint: 'نغير الحرف الأول فقط');
    case 'picture_market':
      return GameRound(
          prompt: 'اختر بطاقة اسم المنتج',
          hero: [4, 5, 6][r],
          caption: 'ضع الاسم المناسب بجانب البضاعة',
          items: [word(4), word(5), word(6), word(7)],
          answer: [
            'w${[4, 5, 6][r]}'
          ],
          hint: 'انظر إلى المنتج');
    case 'sentence':
      final sentence = [
        ['هذا', 'أرنب'],
        ['هذا', 'بيت'],
        ['هذه', 'شجرة']
      ][r];
      return GameRound(
          prompt: 'رتب جملة تصف الصورة',
          hero: [1, 9, 11][r],
          items: [
            for (var i = 0; i < sentence.length; i++)
              GameItem('c$i', text: sentence[i])
          ],
          answer: ['c0', 'c1'],
          hint: 'ابدأ باسم الإشارة: هذا أو هذه');
    case 'feed_rabbit':
      return GameRound(
          prompt: 'أعط الأرنب ${digits(r + 3)} جزرات',
          hero: 1,
          target: r + 3,
          a: 6,
          caption: 'اضغط الجزر لإضافته، واضغط المضاف لإرجاعه');
    case 'number_picture':
      return GameRound(
          prompt: 'اختر الكمية التي تمثل ${digits(r + 3)}',
          caption: digits(r + 3),
          items: [
            for (final n in [2, 3, 4, 5]) GameItem('n$n', amount: n, art: 4)
          ],
          answer: [
            'n${r + 3}'
          ]);
    case 'number_train':
      return GameRound(
          prompt: 'رتب عربات القطار من الأصغر إلى الأكبر',
          items: [for (var i = r + 1; i < r + 5; i++) number(i)],
          answer: [for (var i = r + 1; i < r + 5; i++) 'n$i'],
          hint: 'ابدأ بالعدد الأصغر في اليمين');
    case 'compare':
      return GameRound(
          prompt: r == 1
              ? 'أي السلتين أقل؟'
              : r == 2
                  ? 'هل الكميتان متساويتان؟'
                  : 'أي السلتين أكثر؟',
          items: r == 2
              ? const [
                  GameItem('yes', text: 'متساويتان'),
                  GameItem('no', text: 'مختلفتان')
                ]
              : [
                  GameItem('a', amount: 2 + r, art: 4),
                  const GameItem('b', amount: 5, art: 4)
                ],
          a: r == 2 ? 4 : 0,
          b: r == 2 ? 4 : 0,
          answer: [
            r == 0
                ? 'b'
                : r == 1
                    ? 'a'
                    : 'yes'
          ]);
    case 'add':
      return GameRound(
          prompt: 'اجمع ${digits(r + 2)} و ${digits(2)}',
          target: r + 4,
          start: r + 2,
          a: 4,
          caption: 'أضف تفاحتين إلى السلة ثم تحقق');
    case 'subtract':
      return GameRound(
          prompt: 'أخرج تفاحتين. كم بقي؟',
          target: r + 3,
          start: r + 5,
          a: 4,
          caption: 'اضغط على تفاحة لإخراجها من السلة');
    case 'ten_frame':
      return GameRound(
          prompt: 'أكمل الصندوق ليصبح عشرة',
          target: 10,
          start: r + 5,
          a: 4,
          caption: 'املأ الخانات الفارغة');
    case 'share':
      return GameRound(
          prompt: 'وزع ${digits((r + 2) * 3)} تفاحات بالتساوي',
          target: (r + 2) * 3,
          a: 3,
          b: r + 2,
          hero: 4,
          caption: 'اضغط طبقًا لتضع فيه تفاحة. اضغط مطولًا لاسترجاع واحدة');
    case 'place_value':
      return GameRound(
          prompt: 'ابنِ العدد ${digits(12 + r * 5)}',
          target: 12 + r * 5,
          a: 10,
          b: 1,
          caption: 'حزمة العشرة = عشر قطع');
    case 'shop':
      return GameRound(
          prompt: 'ادفع ${digits(4 + r * 3)} نقاط شراء',
          target: 4 + r * 3,
          a: 5,
          b: 1,
          hero: 5,
          caption: 'هذه قطع للعب وليست رصيد إنجازاتك');
    case 'measure':
      return GameRound(
          prompt: 'غطّ الجسر بوحدات متساوية',
          target: r + 3,
          a: 9,
          caption: 'ضع وحدة في كل جزء ثم عدّ الوحدات');
    case 'story_math':
      return GameRound(
          prompt:
              'في البركة ${digits(r + 2)} بطات، انضمت بطتان. كم أصبح العدد؟',
          a: r + 2,
          b: 2,
          hero: 2,
          items: [
            for (final n in [r + 3, r + 4, r + 5]) number(n)
          ],
          answer: [
            'n${r + 4}'
          ]);
    case 'pattern':
      return GameRound(
          prompt: 'ما الشكل التالي؟',
          grid: r == 0
              ? [0, 1, 0, 1]
              : r == 1
                  ? [0, 0, 2, 0, 0]
                  : [0, 1, 2, 0, 1],
          items: [shape(0), shape(1), shape(2)],
          answer: ['s${r == 0 ? 0 : 2}'],
          hint: 'ابحث عن مجموعة تتكرر');
    case 'odd':
      return GameRound(
          prompt: 'أي شكل يختلف عن البقية؟',
          items: [
            shape(r, id: 'a'),
            shape(r, id: 'b'),
            shape((r + 1) % 3, id: 'c'),
            shape(r, id: 'd')
          ],
          answer: ['c'],
          hint: 'قارن شكل الحواف');
    case 'sort':
      return GameRound(
          prompt: r == 1 ? 'صنّف حسب اللون' : 'صنّف حسب الشكل',
          target: 6,
          a: r == 1 ? 1 : 0,
          items: [
            for (var i = 0; i < 6; i++)
              shape(i % 2, tone: r == 1 ? i % 2 : (i ~/ 2) % 2, id: 'p$i')
          ]);
    case 'jigsaw':
      return GameRound(
          prompt: 'أعد تركيب الصورة',
          hero: [0, 9, 1][r],
          target: 4,
          caption: 'اختر قطعة ثم اضغط مكانها في اللوحة');
    case 'tangram':
      return const GameRound(
          prompt: 'ابنِ البيت من قطع الأشكال',
          hero: 9,
          target: 4,
          grid: [6, 7, 1, 1],
          caption: 'ضع كل قطعة فوق مكانها المطابق');
    case 'symmetry':
      return GameRound(
          prompt: 'أكمل النصف الآخر مثل المرآة',
          grid: [
            [1, 0, 1, 1, 0, 1],
            [0, 1, 1, 0, 1, 1],
            [1, 1, 0, 1, 1, 0]
          ][r],
          caption: 'اضغط الخانات في النصف الفارغ لتلوينها');
    case 'maze':
      return GameRound(
          prompt: 'أوصل صالح إلى البيت',
          grid: [
            [0, 1, 2, 6, 10, 11, 15],
            [0, 4, 8, 9, 10, 14, 15],
            [0, 1, 5, 9, 13, 14, 15]
          ][r],
          target: 15,
          caption: 'تحرك إلى مربع مجاور دون عبور الأشجار');
    case 'connect_path':
      return GameRound(
          prompt: 'أدر القطع ليصل الطريق بين البابين',
          grid: [r + 1, 2, r + 3, 1],
          target: 4,
          caption: 'اضغط القطعة لتدور ربع دورة');
    case 'bridge':
      return GameRound(
          prompt: 'ابنِ جسرًا بطول ${digits(r + 5)} وحدات',
          target: r + 5,
          caption: 'اختر قطعًا بطول ١ أو ٢ أو ٣ دون تجاوز الضفة');
    case 'sequence':
      return const GameRound(
          prompt: 'رتب مراحل نمو النبتة',
          items: [
            GameItem('seed', shape: 4),
            GameItem('sprout', shape: 5),
            GameItem('tree', art: 11)
          ],
          answer: ['seed', 'sprout', 'tree'],
          hint: 'البذرة أولًا ثم النبتة الصغيرة ثم الشجرة');
    case 'robot':
      return GameRound(
          prompt: 'خطط خطوات الروبوت ثم شغّله',
          target: [10, 14, 11][r],
          grid: const [0, 1, 2, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15],
          caption: 'الأوامر اتجاهات ثابتة: يمين، أسفل، يسار، أعلى');
    case 'positions':
      return GameRound(
          prompt: 'الأرنب في الوسط والأسد على يمينه',
          items: [
            word(0, image: true),
            word(1, image: true),
            word(2, image: true)
          ],
          answer: const ['w0', 'w1', 'w2'],
          hint: 'المواضع من اليمين: أسد، أرنب، بطة');
    default:
      throw StateError('Unknown game: ${game.id}');
  }
}

List<GameItem> shuffledItems(List<GameItem> items, Random random) {
  final result = [...items]..shuffle(random);
  if (result.length > 1 &&
      List.generate(result.length, (i) => result[i].id == items[i].id)
          .every((v) => v)) {
    result.add(result.removeAt(0));
  }
  return result;
}

/// Orthogonal adjacency is checked explicitly to reject row wrap-around.
bool adjacent(int a, int b, int columns) =>
    (a ~/ columns - b ~/ columns).abs() + (a % columns - b % columns).abs() ==
    1;
int robotStep(int cell, int command) {
  final x = cell % 4, y = cell ~/ 4;
  final nx = x + ([1, 0, -1, 0][command]), ny = y + ([0, 1, 0, -1][command]);
  return nx < 0 || nx >= 4 || ny < 0 || ny >= 4 ? -1 : ny * 4 + nx;
}
