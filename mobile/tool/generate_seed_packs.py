"""Regenerates the bundled offline question packs with bulk dummy content.

    python tool/generate_seed_packs.py   (run from mobile/)

Hand-written questions already in the packs (English ids < 1000, Khmer ids
< 90100) are kept as-is; everything else is rebuilt from the templates below,
so running this again is idempotent. Answers are computed, not typed, so
every generated question is correct by construction.

Bump SEED_REVISION whenever the output changes: the app re-imports a bundled
pack on devices whose stored revision is older (unless that language's
content has since come from the server).
"""

import json
import random
from pathlib import Path

SEED_REVISION = 2
ASSETS = Path(__file__).resolve().parent.parent / "assets"

# Category ids per language, in the same order as the packs.
CATS = {
    "en": {"animals": 1, "colors": 2, "numbers": 3, "shapes": 4, "nature": 5},
    "km": {"animals": 9001, "colors": 9002, "numbers": 9003, "shapes": 9004, "nature": 9005},
}
FIRST_GENERATED_ID = {"en": 1001, "km": 90101}
KEEP_BELOW_ID = {"en": 1000, "km": 90100}

KM_DIGITS = str.maketrans("0123456789", "០១២៣៤៥៦៧៨៩")


def num(n, lang):
    return str(n).translate(KM_DIGITS) if lang == "km" else str(n)


# --------------------------------------------------------------------------
# Vocabulary: (emoji, english, khmer)
# --------------------------------------------------------------------------

ANIMALS = [
    ("🐶", "Dog", "ឆ្កែ"), ("🐱", "Cat", "ឆ្មា"), ("🐮", "Cow", "គោ"),
    ("🐷", "Pig", "ជ្រូក"), ("🐔", "Chicken", "មាន់"), ("🦆", "Duck", "ទា"),
    ("🐴", "Horse", "សេះ"), ("🐘", "Elephant", "ដំរី"), ("🦁", "Lion", "តោ"),
    ("🐯", "Tiger", "ខ្លា"), ("🐵", "Monkey", "ស្វា"), ("🐰", "Rabbit", "ទន្សាយ"),
    ("🐟", "Fish", "ត្រី"), ("🐸", "Frog", "កង្កែប"), ("🐍", "Snake", "ពស់"),
    ("🐦", "Bird", "បក្សី"), ("🦋", "Butterfly", "មេអំបៅ"), ("🐝", "Bee", "ឃ្មុំ"),
    ("🕷️", "Spider", "ពីងពាង"), ("🐜", "Ant", "ស្រមោច"), ("🐢", "Turtle", "អណ្តើក"),
    ("🐊", "Crocodile", "ក្រពើ"), ("🐻", "Bear", "ខ្លាឃ្មុំ"), ("🐭", "Mouse", "កណ្តុរ"),
    ("🐑", "Sheep", "ចៀម"), ("🐐", "Goat", "ពពែ"), ("🐼", "Panda", "ខ្លាឃ្មុំផេនដា"),
    ("🦒", "Giraffe", "ហ្ស៊ីរ៉ាហ្វ"), ("🦓", "Zebra", "សេះបង្កង់"), ("🐧", "Penguin", "ភេនឃ្វីន"),
    ("🐫", "Camel", "អូដ្ឋ"), ("🦉", "Owl", "ទីទុយ"), ("🐳", "Whale", "ត្រីបាឡែន"),
    ("🐃", "Buffalo", "ក្របី"), ("🦀", "Crab", "ក្តាម"), ("🦐", "Shrimp", "បង្គា"),
]
ANIMAL = {a[1]: a for a in ANIMALS}

LEGS = {
    "Dog": 4, "Cat": 4, "Cow": 4, "Horse": 4, "Elephant": 4, "Frog": 4, "Rabbit": 4,
    "Chicken": 2, "Duck": 2, "Bird": 2, "Penguin": 2, "Owl": 2,
    "Spider": 8, "Ant": 6, "Bee": 6, "Butterfly": 6, "Crab": 10,
    "Fish": 0, "Snake": 0, "Whale": 0,
}

HABITATS = [("Sea", "សមុទ្រ"), ("Forest", "ព្រៃ"), ("Farm", "កសិដ្ឋាន"),
            ("Desert", "វាលខ្សាច់"), ("Icy land", "តំបន់ទឹកកក")]
LIVES_IN = {
    "Fish": "Sea", "Whale": "Sea", "Crab": "Sea", "Shrimp": "Sea",
    "Monkey": "Forest", "Tiger": "Forest", "Bear": "Forest", "Owl": "Forest",
    "Cow": "Farm", "Pig": "Farm", "Chicken": "Farm", "Sheep": "Farm", "Goat": "Farm",
    "Camel": "Desert", "Penguin": "Icy land",
}

SOUNDS = {  # English only: Khmer onomatopoeia needs a native writer.
    "Dog": "Woof", "Cat": "Meow", "Cow": "Moo", "Duck": "Quack", "Sheep": "Baa",
    "Pig": "Oink", "Horse": "Neigh", "Lion": "Roar", "Snake": "Hiss",
    "Bee": "Buzz", "Owl": "Hoot", "Frog": "Ribbit", "Chicken": "Cluck",
}

COLORS = {
    "red": ("Red", "ពណ៌ក្រហម"), "yellow": ("Yellow", "ពណ៌លឿង"),
    "green": ("Green", "ពណ៌បៃតង"), "blue": ("Blue", "ពណ៌ខៀវ"),
    "orange": ("Orange", "ពណ៌ទឹកក្រូច"), "purple": ("Purple", "ពណ៌ស្វាយ"),
    "pink": ("Pink", "ពណ៌ផ្កាឈូក"), "brown": ("Brown", "ពណ៌ត្នោត"),
    "black": ("Black", "ពណ៌ខ្មៅ"), "white": ("White", "ពណ៌ស"),
    "grey": ("Grey", "ពណ៌ប្រផេះ"),
}

COLORED_THINGS = [  # (emoji, english, khmer, color)
    ("🍎", "apple", "ផ្លែប៉ោម", "red"), ("🍌", "banana", "ចេក", "yellow"),
    ("🥦", "broccoli", "ផ្កាខាត់ណាខៀវ", "green"), ("🍇", "bunch of grapes", "ទំពាំងបាយជូ", "purple"),
    ("🍊", "orange", "ផ្លែក្រូច", "orange"), ("🐸", "frog", "កង្កែប", "green"),
    ("🐷", "pig", "ជ្រូក", "pink"), ("🌻", "sunflower", "ផ្កាឈូករ័ត្ន", "yellow"),
    ("🍫", "chocolate bar", "សូកូឡា", "brown"), ("🍓", "strawberry", "ស្ត្របឺរី", "red"),
    ("🥕", "carrot", "ការ៉ុត", "orange"), ("🐘", "elephant", "ដំរី", "grey"),
    ("🍆", "eggplant", "ត្រប់", "purple"), ("🌽", "corn", "ពោត", "yellow"),
    ("🥒", "cucumber", "ត្រសក់", "green"), ("🐻", "bear", "ខ្លាឃ្មុំ", "brown"),
    ("❄️", "snowflake", "ព្រិល", "white"), ("🍋", "lemon", "ក្រូចឆ្មា", "yellow"),
    ("🍅", "tomato", "ប៉េងប៉ោះ", "red"), ("🐳", "whale", "ត្រីបាឡែន", "blue"),
    ("🥥", "coconut", "ដូង", "brown"), ("🌹", "rose", "ផ្កាកុលាប", "red"),
    ("🐥", "chick", "កូនមាន់", "yellow"), ("☁️", "cloud", "ពពក", "white"),
    ("🐭", "mouse", "កណ្តុរ", "grey"), ("🌶️", "chili", "ម្ទេស", "red"),
    ("🥬", "lettuce", "ស្ពៃ", "green"), ("🦩", "flamingo", "សត្វហ្វ្លាមីងហ្គោ", "pink"),
    ("🫐", "blueberry", "ប៊្លូបឺរី", "blue"),
]

COLOR_MIXES = [("red", "yellow", "orange"), ("blue", "yellow", "green"),
               ("red", "blue", "purple"), ("red", "white", "pink"),
               ("black", "white", "grey")]

SHAPES = {
    "triangle": ("Triangle", "ត្រីកោណ"), "square": ("Square", "ការ៉េ"),
    "rectangle": ("Rectangle", "ចតុកោណកែង"), "circle": ("Circle", "រង្វង់"),
    "pentagon": ("Pentagon", "បញ្ចកោណ"), "hexagon": ("Hexagon", "ឆកោណ"),
    "octagon": ("Octagon", "អដ្ឋកោណ"), "star": ("Star", "ផ្កាយ"),
    "heart": ("Heart", "បេះដូង"), "oval": ("Oval", "រាងពងក្រពើ"),
    "diamond": ("Diamond", "រាងពេជ្រ"),
}
SIDES = {"triangle": 3, "square": 4, "rectangle": 4, "pentagon": 5,
         "hexagon": 6, "octagon": 8}
SHAPE_EMOJI = [("🔺", "triangle"), ("🟥", "square"), ("🟦", "square"),
               ("🔵", "circle"), ("🟢", "circle"), ("⭐", "star"),
               ("❤️", "heart"), ("🔷", "diamond"), ("🛑", "octagon")]
SHAPED_THINGS = [  # (emoji, english, khmer, shape)
    ("🏀", "ball", "បាល់", "circle"), ("🍕", "slice of pizza", "ភីហ្សាមួយចំណិត", "triangle"),
    ("🚪", "door", "ទ្វារ", "rectangle"), ("🪙", "coin", "កាក់", "circle"),
    ("🕒", "clock", "នាឡិកា", "circle"), ("📕", "book", "សៀវភៅ", "rectangle"),
    ("🛑", "stop sign", "ផ្លាកសញ្ញាឈប់", "octagon"), ("🥚", "egg", "ពង", "oval"),
    ("🪁", "kite", "ខ្លែង", "diamond"), ("⛺", "tent", "តង់", "triangle"),
    ("📱", "phone", "ទូរស័ព្ទ", "rectangle"), ("🍽️", "plate", "ចាន", "circle"),
    ("🧀", "cheese wedge", "ឈីសមួយចំណិត", "triangle"), ("🍪", "cookie", "នំខូគី", "circle"),
]

FRUITS = [("🍎", "Apple", "ផ្លែប៉ោម"), ("🍌", "Banana", "ចេក"), ("🍇", "Grapes", "ទំពាំងបាយជូ"),
          ("🍊", "Orange", "ផ្លែក្រូច"), ("🍓", "Strawberry", "ស្ត្របឺរី"),
          ("🍍", "Pineapple", "ម្នាស់"), ("🥭", "Mango", "ផ្លែស្វាយ"),
          ("🍉", "Watermelon", "ឪឡឹក"), ("🍒", "Cherry", "ឆឺរី"), ("🥥", "Coconut", "ដូង")]
VEGETABLES = [("🥕", "Carrot", "ការ៉ុត"), ("🥦", "Broccoli", "ផ្កាខាត់ណាខៀវ"),
              ("🌽", "Corn", "ពោត"), ("🥒", "Cucumber", "ត្រសក់"), ("🍆", "Eggplant", "ត្រប់"),
              ("🥬", "Lettuce", "ស្ពៃ"), ("🧅", "Onion", "ខ្ទឹមបារាំង"),
              ("🥔", "Potato", "ដំឡូងបារាំង"), ("🧄", "Garlic", "ខ្ទឹមស"), ("🌶️", "Chili", "ម្ទេស")]

WEATHER = [("☀️", "Sunny", "មានពន្លឺថ្ងៃ"), ("🌧️", "Rainy", "ភ្លៀង"),
           ("❄️", "Snowy", "ព្រិលធ្លាក់"), ("💨", "Windy", "ខ្យល់បក់ខ្លាំង"),
           ("☁️", "Cloudy", "មានពពក"), ("⛈️", "Stormy", "មានព្យុះ")]

NATURE_FACTS = {  # (prompt, correct, distractors...)
    "en": [
        ("What do bees make?", "Honey", "Milk", "Bread", "Juice"),
        ("What do cows give us to drink?", "Milk", "Honey", "Tea", "Soda"),
        ("What do chickens lay?", "Eggs", "Apples", "Rocks", "Shells"),
        ("When can we see the stars?", "At night", "At noon", "In the morning", "Never"),
        ("What is ice made of?", "Water", "Sand", "Milk", "Paper"),
        ("What does a caterpillar turn into?", "Butterfly", "Bee", "Bird", "Frog"),
        ("What does a tadpole grow into?", "Frog", "Fish", "Snake", "Duck"),
        ("What grows from a seed?", "A plant", "A rock", "A cloud", "A shell"),
        ("What do plants need to grow?", "Sun and water", "Toys", "Candy", "Shoes"),
        ("What shines in the sky at night?", "The Moon", "The Sun", "A rainbow", "A cloud"),
        ("What can we see after rain when the sun comes out?", "A rainbow", "Snow", "Stars", "The Moon"),
        ("What do birds build to lay eggs in?", "A nest", "A boat", "A car", "A house"),
        ("Which season has the most rain in Cambodia?", "Rainy season", "Dry season", "Winter", "Hot season"),
        ("What falls from trees in the autumn?", "Leaves", "Rocks", "Fish", "Shoes"),
        ("Where does rain come from?", "Clouds", "Trees", "Mountains", "Houses"),
        ("What do fish use to breathe?", "Gills", "Noses", "Ears", "Feet"),
    ],
    "km": [
        ("តើឃ្មុំធ្វើអ្វី?", "ទឹកឃ្មុំ", "ទឹកដោះគោ", "នំប៉័ង", "ទឹកផ្លែឈើ"),
        ("តើគោផ្តល់អ្វីឲ្យយើងផឹក?", "ទឹកដោះគោ", "ទឹកឃ្មុំ", "តែ", "ទឹកក្រូច"),
        ("តើមេមាន់ពងអ្វី?", "ពង", "ផ្លែប៉ោម", "ថ្ម", "សំបកខ្យង"),
        ("តើយើងឃើញផ្កាយនៅពេលណា?", "ពេលយប់", "ពេលថ្ងៃត្រង់", "ពេលព្រឹក", "មិនដែលឃើញ"),
        ("តើទឹកកកធ្វើពីអ្វី?", "ទឹក", "ខ្សាច់", "ទឹកដោះគោ", "ក្រដាស"),
        ("តើដង្កូវក្លាយជាអ្វី?", "មេអំបៅ", "ឃ្មុំ", "បក្សី", "កង្កែប"),
        ("តើកូនកង្កែប (ក្អុក) ធំឡើងក្លាយជាអ្វី?", "កង្កែប", "ត្រី", "ពស់", "ទា"),
        ("តើអ្វីដុះចេញពីគ្រាប់ពូជ?", "រុក្ខជាតិ", "ថ្ម", "ពពក", "សំបកខ្យង"),
        ("តើរុក្ខជាតិត្រូវការអ្វីដើម្បីលូតលាស់?", "ពន្លឺថ្ងៃ និងទឹក", "ប្រដាប់ក្មេងលេង", "ស្ករគ្រាប់", "ស្បែកជើង"),
        ("តើអ្វីភ្លឺនៅលើមេឃពេលយប់?", "ព្រះច័ន្ទ", "ព្រះអាទិត្យ", "ឥន្ទធនូ", "ពពក"),
        ("ក្រោយភ្លៀង ពេលថ្ងៃចេញ តើយើងអាចឃើញអ្វី?", "ឥន្ទធនូ", "ព្រិល", "ផ្កាយ", "ព្រះច័ន្ទ"),
        ("តើបក្សីធ្វើអ្វីដើម្បីពងកូន?", "សំបុក", "ទូក", "ឡាន", "ផ្ទះ"),
        ("តើស្លឹកឈើជ្រុះពីណា?", "ដើមឈើ", "ពពក", "ភ្នំ", "សមុទ្រ"),
        ("តើត្រីដកដង្ហើមដោយប្រើអ្វី?", "ស្រកី", "ច្រមុះ", "ត្រចៀក", "ជើង"),
        ("តើព្រះអាទិត្យរះនៅពេលណា?", "ពេលព្រឹក", "ពេលយប់", "ពេលកណ្តាលអធ្រាត្រ", "មិនដែលរះ"),
        ("តើយើងប្រើអ្វីដើម្បីមើលឃើញ?", "ភ្នែក", "ត្រចៀក", "ដៃ", "ជើង"),
    ],
}

# --------------------------------------------------------------------------
# Question building
# --------------------------------------------------------------------------


class Builder:
    def __init__(self, lang, rng):
        self.lang = lang
        self.rng = rng
        self.items = []
        self.seen = set()

    def add(self, cat, prompt, correct, distractors, difficulty="easy", age="4-6"):
        distractors = [d for d in dict.fromkeys(distractors) if d != correct][:3]
        assert len(distractors) == 3, (prompt, correct, distractors)
        # Same prompt is fine ("Which of these is red?") as long as the
        # answer differs; only drop exact repeats.
        key = (prompt, correct)
        if key in self.seen:
            return
        self.seen.add(key)
        choices = distractors + [correct]
        self.rng.shuffle(choices)
        self.items.append({
            "category": cat, "prompt": prompt, "choices": choices,
            "correct_index": choices.index(correct),
            "difficulty": difficulty, "age_group": age,
        })

    def pick(self, pool, k, exclude=()):
        return self.rng.sample([p for p in pool if p not in exclude], k)


def name(entry, lang):
    return entry[1] if lang == "en" else entry[2]


def near_numbers(rng, n, lo=0, hi=20):
    pool = [x for x in range(max(lo, n - 4), min(hi, n + 4) + 1) if x != n]
    return rng.sample(pool, 3)


def build(lang):
    rng = random.Random(f"kid-smile-{lang}-{SEED_REVISION}")
    b = Builder(lang, rng)
    en = lang == "en"
    N = lambda n: num(n, lang)  # noqa: E731

    # ---- Animals ----
    for emoji, *_ in ANIMALS:
        a = next(x for x in ANIMALS if x[0] == emoji)
        others = b.pick([x for x in ANIMALS if x != a], 3)
        b.add("animals", f"Which animal is this? {emoji}" if en else f"តើនេះជាសត្វអ្វី? {emoji}",
              name(a, lang), [name(o, lang) for o in others])
    for animal, legs in LEGS.items():
        a = ANIMAL[animal]
        options = [0, 2, 4, 6, 8, 10]
        b.add("animals",
              f"How many legs does a {animal.lower()} have? {a[0]}" if en
              else f"តើ{a[2]}មានជើងប៉ុន្មាន? {a[0]}",
              N(legs), [N(x) for x in b.pick(options, 3, exclude=[legs])],
              difficulty="medium", age="7-9")
    for animal, home in LIVES_IN.items():
        a = ANIMAL[animal]
        h = next(x for x in HABITATS if x[0] == home)
        others = [x for x in HABITATS if x != h]
        b.add("animals",
              f"Where does a {animal.lower()} live? {a[0]}" if en
              else f"តើ{a[2]}រស់នៅទីណា? {a[0]}",
              h[0] if en else h[1], [x[0] if en else x[1] for x in b.pick(others, 3)])
    if en:
        for animal, sound in SOUNDS.items():
            others = b.pick([x for x in SOUNDS if x != animal], 3)
            b.add("animals", f'Which animal says "{sound}"?', animal, others)
            b.add("animals", f"What sound does a {animal.lower()} make? {ANIMAL[animal][0]}",
                  sound, [SOUNDS[o] for o in others])

    # ---- Colors ----
    color_name = lambda c: COLORS[c][0 if en else 1]  # noqa: E731
    for emoji, en_name, km_name, color in COLORED_THINGS:
        b.add("colors",
              f"What color is the {en_name}? {emoji}" if en else f"តើ{km_name}មានពណ៌អ្វី? {emoji}",
              color_name(color), [color_name(c) for c in b.pick(list(COLORS), 3, exclude=[color])])
    for emoji, en_name, km_name, color in COLORED_THINGS:
        others = [t for t in COLORED_THINGS if t[3] != color]
        thing = lambda t: f"{t[0]} {t[1] if en else t[2]}"  # noqa: E731
        b.add("colors",
              f"Which of these is {COLORS[color][0].lower()}?" if en
              else f"តើមួយណាមាន{COLORS[color][1]}?",
              thing((emoji, en_name, km_name)), [thing(t) for t in b.pick(others, 3)])
    for c1, c2, result in COLOR_MIXES:
        for x, y in ((c1, c2), (c2, c1)):
            b.add("colors",
                  f"{COLORS[x][0]} mixed with {COLORS[y][0].lower()} makes which color?" if en
                  else f"{COLORS[x][1]} លាយនឹង{COLORS[y][1]} ក្លាយជាពណ៌អ្វី?",
                  color_name(result),
                  [color_name(c) for c in b.pick(list(COLORS), 3, exclude=[result, x, y])],
                  difficulty="medium", age="7-9")

    # ---- Numbers ----
    plus, minus = ("+", "-")
    for a in range(1, 10):
        for c in range(1, 10):
            s = a + c
            b.add("numbers",
                  f"What is {a} {plus} {c}?" if en else f"{N(a)} {plus} {N(c)} ស្មើនឹងប៉ុន្មាន?",
                  N(s), [N(x) for x in near_numbers(rng, s, 1, 20)],
                  *(("easy", "4-6") if s <= 10 else ("medium", "7-9")))
    for a in range(2, 13):
        for c in range(1, a):
            if a > 10 and c < 3:
                continue
            d = a - c
            b.add("numbers",
                  f"What is {a} {minus} {c}?" if en else f"{N(a)} {minus} {N(c)} ស្មើនឹងប៉ុន្មាន?",
                  N(d), [N(x) for x in near_numbers(rng, d, 0, 12)],
                  *(("easy", "4-6") if a <= 6 else ("medium", "7-9")))
    count_emoji = ["🍎", "⭐", "🐟", "🎈", "🌸", "🚗", "🐤", "🍪"]
    for i, e in enumerate(count_emoji):
        for n in range(1, 11):
            if (n + i) % 2:  # half the combinations keeps it varied, not huge
                continue
            b.add("numbers",
                  f"How many are there? {e * n}" if en else f"តើមានប៉ុន្មាន? {e * n}",
                  N(n), [N(x) for x in near_numbers(rng, n, 1, 12)])
    for n in range(1, 20):
        b.add("numbers",
              f"What number comes after {n}?" if en else f"តើលេខអ្វីមកបន្ទាប់ពី {N(n)}?",
              N(n + 1), [N(n - 1), N(n + 2), N(n)] if n > 1 else [N(3), N(4), N(1)])
    for n in range(2, 21):
        b.add("numbers",
              f"What number comes before {n}?" if en else f"តើលេខអ្វីមកមុន {N(n)}?",
              N(n - 1), [N(n + 1), N(n), N(n - 2) if n > 2 else N(n + 2)])
    for _ in range(20):
        nums = rng.sample(range(1, 21), 4)
        biggest = max(nums)
        b.add("numbers",
              f"Which number is the biggest: {', '.join(map(str, nums))}?" if en
              else f"តើលេខមួយណាធំជាងគេ៖ {', '.join(N(x) for x in nums)}?",
              N(biggest), [N(x) for x in nums if x != biggest])
    for _ in range(20):
        nums = rng.sample(range(1, 21), 4)
        smallest = min(nums)
        b.add("numbers",
              f"Which number is the smallest: {', '.join(map(str, nums))}?" if en
              else f"តើលេខមួយណាតូចជាងគេ៖ {', '.join(N(x) for x in nums)}?",
              N(smallest), [N(x) for x in nums if x != smallest])

    # ---- Shapes ----
    shape_name = lambda s: SHAPES[s][0 if en else 1]  # noqa: E731
    for shape, sides in SIDES.items():
        b.add("shapes",
              f"How many sides does a {SHAPES[shape][0].lower()} have?" if en
              else f"តើ{SHAPES[shape][1]}មានជ្រុងប៉ុន្មាន?",
              N(sides), [N(x) for x in b.pick([0, 3, 4, 5, 6, 8], 3, exclude=[sides])])
        b.add("shapes",
              f"How many corners does a {SHAPES[shape][0].lower()} have?" if en
              else f"តើ{SHAPES[shape][1]}មានកែងប៉ុន្មាន?",
              N(sides), [N(x) for x in b.pick([0, 3, 4, 5, 6, 8], 3, exclude=[sides])],
              difficulty="medium", age="7-9")
        if shape not in ("square", "rectangle"):  # both have 4 sides
            b.add("shapes",
                  f"Which shape has {sides} sides?" if en else f"តើរាងអ្វីមាន {N(sides)} ជ្រុង?",
                  shape_name(shape),
                  [shape_name(s) for s in b.pick(list(SIDES), 3, exclude=[shape])])
    b.add("shapes", "Which shape has no corners?" if en else "តើរាងអ្វីគ្មានកែងសោះ?",
          shape_name("circle"), [shape_name(s) for s in ("triangle", "square", "hexagon")])
    for emoji, shape in SHAPE_EMOJI:
        b.add("shapes", f"What shape is this? {emoji}" if en else f"តើនេះជារាងអ្វី? {emoji}",
              shape_name(shape), [shape_name(s) for s in b.pick(list(SHAPES), 3, exclude=[shape])])
    for emoji, en_name, km_name, shape in SHAPED_THINGS:
        b.add("shapes",
              f"What shape is a {en_name}? {emoji}" if en else f"តើ{km_name}មានរាងអ្វី? {emoji}",
              shape_name(shape), [shape_name(s) for s in b.pick(list(SHAPES), 3, exclude=[shape])])
        others = [t for t in SHAPED_THINGS if t[3] != shape]
        thing = lambda t: f"{t[0]} {t[1] if en else t[2]}"  # noqa: E731
        b.add("shapes",
              f"Which of these is shaped like a {SHAPES[shape][0].lower()}?" if en
              else f"តើមួយណាមានរាង{SHAPES[shape][1]}?",
              thing((emoji, en_name, km_name)), [thing(t) for t in b.pick(others, 3)],
              difficulty="medium", age="7-9")

    # ---- Nature ----
    label = lambda t: f"{t[0]} {t[1] if en else t[2]}"  # noqa: E731
    for f in FRUITS:
        vegs = b.pick(VEGETABLES, 3)
        b.add("nature",
              "Which of these is a fruit?" if en else "តើមួយណាជាផ្លែឈើ?",
              label(f), [label(v) for v in vegs])
    for v in VEGETABLES:
        fruits = b.pick(FRUITS, 3)
        b.add("nature",
              "Which of these is a vegetable?" if en else "តើមួយណាជាបន្លែ?",
              label(v), [label(f) for f in fruits])
    for emoji, en_name, km_name in WEATHER:
        others = [w for w in WEATHER if w[0] != emoji]
        b.add("nature",
              f"What is the weather like? {emoji}" if en else f"តើអាកាសធាតុយ៉ាងម៉េច? {emoji}",
              en_name if en else km_name, [w[1] if en else w[2] for w in b.pick(others, 3)])
    for prompt, correct, *wrong in NATURE_FACTS[lang]:
        b.add("nature", prompt, correct, wrong)

    return b.items


def write_pack(lang, path):
    existing = json.loads(path.read_text(encoding="utf-8"))
    kept = [q for q in existing["questions"] if q["id"] < KEEP_BELOW_ID[lang]]
    kept_keys = {(q["prompt"], q["choices"][q["correct_index"]]) for q in kept}
    next_id = FIRST_GENERATED_ID[lang]
    questions = list(kept)
    for item in build(lang):
        if (item["prompt"], item["choices"][item["correct_index"]]) in kept_keys:
            continue
        q = {"id": next_id, "category_id": CATS[lang][item.pop("category")], **item}
        if lang != "en":
            q["language"] = lang
        # Field order matches the hand-written rows.
        order = ["id", "category_id", "prompt", "choices", "language",
                 "correct_index", "difficulty", "age_group"]
        questions.append({k: q[k] for k in order if k in q})
        next_id += 1

    lines = ["{", f'  "version": {existing["version"]},',
             f'  "seed_revision": {SEED_REVISION},',
             f'  "generated_at": "{existing["generated_at"]}",', '  "categories": [']
    lines.append(",\n".join("    " + json.dumps(c, ensure_ascii=False) for c in existing["categories"]))
    lines += ["  ],", '  "questions": [']
    lines.append(",\n".join("    " + json.dumps(q, ensure_ascii=False) for q in questions))
    lines += ["  ]", "}"]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    per_cat = {}
    for q in questions:
        per_cat[q["category_id"]] = per_cat.get(q["category_id"], 0) + 1
    print(f"{path.name}: {len(questions)} questions {per_cat}")


if __name__ == "__main__":
    write_pack("en", ASSETS / "seed_pack.json")
    write_pack("km", ASSETS / "seed_pack_km.json")
