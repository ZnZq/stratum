# Ревʼю коду й архітектури STRATUM

*Дата: 2026-09-01. Стан: `dart analyze` — **No issues found**; `dart test` (stratum_core) — **464 тести зелені** (~1 с). Ревʼю зроблено читанням коду незалежним агентом у режимі read-only; кожна знахідка має посилання `файл:рядок`. Знахідки К1 і К4 додатково перевірені вручну.*

---

## 1. Резюме

### Оцінка

Це **незвично дисциплінований для інкрементальної гри код**. Ядро справді чисте (`stratum_core/pubspec.yaml` без Flutter — заборона тримається структурно), реактивний граф (`reactive_graph.dart`) — грамотний lazy pull-граф з версійною інвалідацією і захистом від циклів; `TickEngine` (`tick_engine.dart:160-185`) розвʼязує проблему «замерзлої шкали» правильно і з коментарем-поясненням; `RandomSource` (`random_source.dart`) з іменованими підпотоками і серіалізацією стану — рівно те, що потрібно для паритету; сейв атомарний з бекапом і карантином; **жодного TODO/FIXME/`// ignore` у всьому репозиторії**; жоден `CustomPainter` не має `shouldRepaint => true`. Коментарі пояснюють *чому*, а не *що* — це рідкість.

Проблеми лежать не в «якості рядка», а в **трьох системних місцях**: god-object ядра, копії формул ядра в UI і одна-єдина точка нотифікації на весь застосунок.

### Сім головних проблем

1. **Виплата товстого/звичайного пробиття не множить реголіт на `fundScaleOf`** (`prototype_simulation.dart:1464`, `:1479`) — сусідні рядки (кристали, руди, дані) множать; пряме порушення правила «множники в одному місці на смугу».
2. **Крит множить ЗДОБИЧ** (`prototype_simulation.dart:1305-1310`), хоча журнал 2026-08-27 каже «крит множить ЛИШЕ шкоду циклу, ніколи здобич»; а коментар у `strike()` (`:1266-1269`) стверджує, що крит тут узагалі не котиться — і це неправда.
3. **Дві вітрини одного числа розходяться**: смуга реголіту в `blow_summary.dart:61` — без `fundScaleOf`, у `loot_table.dart:58-59` — з ним.
4. **Пошкоджений (але валідний JSON) сейв кидає неперехоплений виняток**: `BigDouble.parse`/`RandomSource.fromJson` кидають `FormatException`, а `Game._apply` ловить лише `SaveFormatException` (`game.dart:470`) — шлях «читати `.bak` → карантин» не спрацює.
5. **`PrototypeSimulation` — 2848 рядків / ~15 підсистем / 332 декларації** в одному файлі, при тому що прецедент декомпозиції вже є (`CraftLine`).
6. **Одна `ListenableBuilder` на весь застосунок** (`game_shell.dart:237`) + `notifyListeners()` на кожен удар (`game.dart:1037`) → до ~10 повних ребілдів дерева на секунду, і в цих ребілдах живуть цикли до 1000 ітерацій `BigDouble.pow` (`track_row.dart:35`, `part_card.dart:47`).
7. **Формули ядра продубльовані в UI** (тирова математика крафту в 4 файлах, темп реплікатора, «наступна секунда» треку) — при цьому відповідна вітрина ядра (`replicatorPerMinuteOf`) стала мертвою.

### Кількісні факти

| Метрика | Значення |
|---|---|
| `.dart` файлів у `packages/` (з тестами й `tool/`) | 163 |
| Рядків коду | 30 592 |
| Найбільші файли | `prototype_simulation.dart` 2848, `craft_line_card.dart` 1498, `game.dart` 1092, `craft_recipe_sheet.dart` 811, `tick_engine_test.dart` 740 |
| `Signal(` / `Computed(` у `PrototypeSimulation` | 38 / 17 |
| `Signal`/`Computed` у всьому ядрі (згадок) | 135 / 48 |
| Файлів із >1 публічним класом | 26 |
| Циклів імпорту | 1 (`hud/box.dart` ↔ `hud/corners.dart`) |
| Методів > 60 рядків | 62 (макс.: `_ConveyorPainter.paint` 389, `readJson` 227, `_Passport.build` 222) |
| Тестів ядра / файлів | 464 / 27 |
| Тестів застосунку | **0** (при `flutter_test` і `flutter_driver` у dev-залежностях) |
| TODO/FIXME/`// ignore` | 0 |

---

## 2. Знахідки за пріоритетом

### 🔴 КРИТИЧНО

---

#### К1. Виплата за пробиття шару не множиться на `fundScaleOf(regolith)`

`packages/stratum_core/lib/src/preview/prototype_simulation.dart:1459-1481`

```dart
payout = rawDataDropAt(layer.value) * BigDouble.fromNum(thickSpan)
       * fundScaleOf(ResourceId.rawData);          // ✔ множник
final regolith = regolithPerCycle.value * bonus;   // ✘ БЕЗ множника
final crystals = crystalDropAt(layer.value) * bonus * fundScaleOf(ResourceId.crystals); // ✔
...
stock.add(row.id, oreDropAt(layer.value) * bonus * fundScaleOf(row.id));               // ✔
} else {
  stock.add(ResourceId.regolith, regolithPerCycle.value * BigDouble.fromNum(1.5));      // ✘
}
```

**Чому проблема саме тут.** CLAUDE.md, «Формула видобутку»: *«множники застосовуються В ОДНОМУ місці кожної смуги (рол лут-таблиці, **виплата товстого шару**, `expectedPerStrike`) — не в кількох, що розійдуться»*. Тут смуга реголіту має рівно три місця виплати, і третє (пробиття) множник загубило. Це не питання величини (правило 0), а порушення інваріанта: рівні фінансування реголіту не діють на частину його ж доходу, і жодна вітрина цього не побачить.

**Виправлення.** Домножити обидва рядки на `fundScaleOf(ResourceId.regolith)`. Ще краще — завести приватний `_payRegolith(BigDouble base)`, який єдиний у класі має право класти реголіт на склад, і провести через нього всі три точки (`_rollLoot:1322`, `_breakLayer:1468`, `:1477`).

**Обсяг:** S. **Міграція сейву:** ні. **RNG-паритет:** не зачіпає (ролів не додається/не забирається). **Тест:** «рівень фінансування реголіту множить виплату товстого шару так само, як лут-рол».

---

#### К2. Крит множить здобич — код проти журналу, і коментар проти коду

`packages/stratum_core/lib/src/preview/prototype_simulation.dart:1303-1310`

```dart
final critical = random.stream('${prefix}loot.crit').chance(critChance ?? strikeCritChance);
if (critical) {
  multiplier = multiplier * BigDouble.fromNum(strikeCritPower);   // множить УСЮ здобич нижче
}
```

при тому, що `strike()` (`:1266-1269`) документований як:

```dart
/// ... each on its own streams; the difference between the lanes is who threw
/// the blow. No crit roll here -- crits are the drill's drama.
```

Крит **котиться** саме тут (потік `strike.loot.crit`), і `strike()` множить на нього ще й шкоду (`:1275-1277`). `StrikeOutcome.critical` (`strike_outcome.dart:29-30`) документований чесно — «multiplying its damage and haul alike», тобто код послідовно реалізує **стару** редакцію правила (CLAUDE.md:98-100), а не пізнішу (CLAUDE.md:55-58, 2026-08-27: *«Крит множить ЛИШЕ шкоду циклу, ніколи здобич»*).

**Чому проблема саме тут.** Журнал сам собі суперечить у двох місцях, і код обрав старіше правило мовчки. Це та сама «дірка вітрини», що вже двічі кусала власника: лут-таблиця (`loot_table.dart`) обіцяє X, удар платить 1.2·X у 5% випадків. Формально правило 4 («вітрина цитує підлогу») це виправдовує, але правило 2026-08-27 — ні.

**Виправлення.** Рішення власника, два варіанти:
- (а) залишити поведінку → **виправити коментар `:1266-1269`** і дописати в CLAUDE.md, що редакція 2026-08-27 скасована;
- (б) виконати правило → винести `multiplier` з лутової частини `_rollLoot` і застосовувати крит лише до `blow`/`damage` у `strike()` і `_cycle()`.

**Обсяг:** S (а) / M (б). **Міграція:** ні. **RNG-паритет:** варіант (б) **не зсуває потоки** (рол лишається на місці, змінюється лише що на нього множиться) — але змінює числа, тож тести на конкретні значення в `prototype_simulation_test.dart:108-117` треба переписати на формулу.

---

#### К3. Пошкоджений сейв може кинути повз захист «бекап → карантин»

`packages/stratum_app/lib/game.dart:445-474`

```dart
bool _apply(String raw) {
  try {
    final document = codec.decode(raw);
    ...
    sim.readJson(Map<String, Object?>.from(run));
    ...
  } on SaveFormatException catch (error) { ... return false; }
}
```

`codec.decode` справді конвертує JSON-помилки в `SaveFormatException` (`save_codec.dart:102-103`), але **`sim.readJson` виконується після** і кидає інші типи:

- `prototype_simulation.dart:2809` `BigDouble.parse(damaged)` → `FormatException` (`big_double.dart:360-366`);
- `stockpile.dart:143`, `prototype_simulation.dart:2598-2601`, `:2687` — те саме;
- `random_source.dart:106,116-118` — `FormatException` і `(state as List)` / `(v as int)` → `TypeError`.

`SaveFormatException implements Exception` (не `FormatException`), тож жодне з цього не ловиться. Результат: структурно валідний, але побитий у значеннях сейв → виняток летить з `loadFrom` → `Game.start()` падає, `.bak` не читається, `quarantine()` не викликається — тобто найдорожчий запобіжник проєкту не спрацьовує саме в сценарії, заради якого існує.

**Виправлення.** У `_apply` ловити `on Object catch (error)` (лишивши `debugPrint`); окремо — обгорнути `readJson` так, щоб симуляція не лишалась напівзаповненою (найпростіше: читати в свіжий `PrototypeSimulation` і підміняти лише при успіху — але це велика зміна; мінімальний крок — розширений `catch` + `quarantine`).

**Обсяг:** S. **Міграція:** ні. **RNG:** ні. **Тест:** можливий уже зараз у ядрі — `readJson` з `{'stock': {'regolith': 'abc'}}` має або не кидати, або кидати `SaveFormatException`.

---

#### К4. `Game.dispose()` не гасить `_breachTimer`

`packages/stratum_app/lib/game.dart:1074-1091` проти `:251`, `:270-277`

```dart
_breachTimer = Timer.periodic(const Duration(seconds: 1), (_) {
  if (!_clockBreached()) { _exitBreach(); } else { notifyListeners(); }
});
```

`dispose()` скасовує `_autosave`, таймери нотисів, `_lifecycle`, обидва рушії й обидва `ValueNotifier` — **але не `_breachTimer`**. Якщо застосунок закривається (або в тестах/hot-restart дерево перебудовується) під брічем, таймер живе далі й раз на секунду кличе `notifyListeners()` на задиспоуженому `ChangeNotifier` → `FlutterError: A Game was used after being disposed`.

**Виправлення:** `_breachTimer?.cancel();` у `dispose()`. **Обсяг:** S.

---

### 🟠 ВАЖЛИВО

---

#### В1. Розрив вітрини: смуга реголіту цитується двічі, по-різному

- `packages/stratum_app/lib/ui/drill/loot_table.dart:57-59` — `'${sim.strikeRegolithMin * sim.fundScaleOf(ResourceId.regolith)} – ${sim.strikeRegolithMax * sim.fundScaleOf(...)}'`
- `packages/stratum_app/lib/ui/blow_summary.dart:61` — `'${sim.strikeRegolithMin} – ${sim.strikeRegolithMax}'` (**без множника**)

Одне й те саме число («реголіт за удар») на екрані Шахти й на екрані Маніпулятора відрізняється рівно на `fundScaleOf`. Це буквально та дірка, яку власник ловив 2026-08-30 («лут-таблиця показувала 16.3 там, де удар платив 127.9»), тільки з іншого боку.

**Виправлення:** завести в ядрі `strikeRegolithBand` (пару `Computed`, уже помножену на `fundScaleOf`) і цитувати її з обох місць; UI не має права сам збирати добуток — це третє місце застосування множника, чого правило прямо забороняє. **Обсяг:** S. **Міграція:** ні.

---

#### В2. `PrototypeSimulation` — god-object (2848 рядків)

Детальна карта і план — у розділі 5. Тут — оцінка: 332 декларації, ~15 незалежних відповідальностей, 5 із них уже мають власні файли-супутники (`CraftLine`, `DrillState`, `TradeRequest`…), тобто патерн декомпозиції в проєкті **вже прийнятий і працює** — просто не доведений до кінця. Найдорожчі наслідки сьогодні: `readJson` на 227 рядків (`:2588-2814`), `toJson` на 97 (`:2484-2580`), і неможливість тестувати підсистему без підняття всього світу.

---

#### В3. Порушення правила графа: голі гетери на гарячому шляху

Правило (CLAUDE.md, «Примітиви ядра»): *«УСІ похідні розрахунки ядра живуть у графі… Голий гетер, що читає сигнали, — порушення»*. Підтверджені порушники, від найгарячішого:

| Символ | `файл:рядок` | Читає сигналів | Частота |
|---|---|---|---|
| `strikeRegolithMin` / `Max` / `_strikeRegolithMean` | `prototype_simulation.dart:1053`, `:1058`, `:1063` | 3 (+`BigDouble.pow` ×2) | **2 рази на кожен удар** (`:1315-1316`), 10 уд/с рукою |
| `pierceShare` | `:1076` | 1 | 4 рази на удар (`_applyDamage:1434`, `strikeBite`, `hitsToBreak`, `layerEffort`) |
| `strikePower` / `strikePowerAt` | `:1078`, `:1083` | 2 | кожен удар + кожен цикл |
| `drillYieldScale`→`drillArea`→`drillRadius` | `:956`, `:949`, `:945` | 1 | кожен цикл (`_cycle:1387`) |
| `expectedPerStrike` / `expectedPerCycle` | `:1198`, `:1233` | 5–7 | 23 рази на скибку офлайну (див. В4) |
| `walletEarned` | `:654` | 2 | у `pendingCollapses`, який кличе `navigation.dart:147` **на кожен ребілд** |
| `energyCap` / `energySeconds` | `:379`, `:396` | 1 | кожен реген + кожен ребілд плити |
| `replicatorSeconds` / `replicatorYieldOf` | `:1898`, `:1907` | 1–2 | **кожен кадр** сцени друку (`replicator_screen.dart:390`) |
| `sellAllYield` | `:2341` | 13 позицій × 3 сигнали | двічі за ребілд (`trade_screen.dart:167`, мітка й `onTap`) |

**Виправлення:** перевести в `Computed`, будовані в конструкторі, за зразком ланцюга фінансування (`:130-179`) — там це вже зроблено і працює. `crystalChance`, `criticalChance` тощо — окремо, вони дешеві. **Обсяг:** M. **Міграція:** ні. **RNG:** ні.

---

#### В4. `claimOffline` перераховує всю таблицю темпів на кожній 60-секундній скибці

`prototype_simulation.dart:745-783` (цикл скибок) → `:809-817`:

```dart
for (final id in ResourceId.values) {          // 23 ресурси
  final rate = yieldPerSecond(id, ...);        // → expectedPerStrike + expectedPerCycle
```

За 48 год відсутності це 2880 скибок × 23 ресурси × (кілька `BigDouble.pow`) ≈ 66 000 перерахунків **абсолютно незмінних** величин: офлайн не рухає ні глибину (`:723-726` — свідомо), ні рівні фінансування. Виконується синхронно на першому кадрі після повернення.

**Виправлення:** підняти обчислення карти темпів на рівень `settleAbsence` (один раз перед `while`) і передавати готову `Map<ResourceId, BigDouble>` у `claimOffline`. Результат ідентичний до біта. **Обсяг:** S–M. **Міграція:** ні. **RNG:** ні (ролів в офлайні немає за задумом).

---

#### В5. Один нотифікатор на весь застосунок + важкі цикли в `build()`

- `game_shell.dart:237-245` — **єдина** `ListenableBuilder(listenable: _game)` огортає геть усе: сцену, екран, ресурсну смугу, навбар, оверлеї.
- `Game.notifyListeners()` викликається з `strike()` (`game.dart:1037`) — тобто до 10 разів на секунду при затиснутому пальці, — з `_onEnergyBatch` (`:925`), `_onDrillBatch` (`:917`), і з `craft_screen.dart:50` раз на секунду через `pokeListeners()`.
- У цих ребілдах:
  - `track_row.dart:35` → `affordableDrillLevels` — цикл **до 1000 ітерацій** `drillCostOf` (`prototype_simulation.dart:1038-1044`), ×3 треки;
  - `part_card.dart:47` → `affordableLevels` — цикл до `maxPartLevel = 1000` (`:1186-1192`), ×3 деталі;
  - `navigation.dart:147` → `pendingCollapses(DateTime.now())` — цикл по стійках із `BigDouble.pow` **на кожен ребілд навбару**;
  - `trade_screen.dart:167` — `sellAllYield()` двічі.

Ядро вже має ідеальний інструмент для точкових оновлень (`Signal.listen`), але **UI користується ним рівно в одному місці** — `game.dart:38`. Решта дерева живе на «все перебудувати».

**Виправлення (поетапно, без переписування):**
1. `craft_screen._sync` → `setState` замість `pokeListeners()` (як уже зроблено в `trade_screen.dart:54` і `since_clock.dart:34-36`) — миттєвий виграш;
2. кешувати `affordableLevels`/`affordableDrillLevels` (обчислювати лише коли `batch == 0` **і** гаманець/рівень змінились), або обмежити цикл розумною стелею;
3. довгостроково — тонкий `SignalBuilder<T>` віджет над `Signal.listen`, щоб плитки складу/ціни підписувались на свій сигнал, а не на `Game`.

**Обсяг:** (1) S, (2) S, (3) L. **Міграція:** ні.

---

#### В6. Формули ядра переписані в UI (дублікат істини)

| Місце | Що рахує сам | Що є в ядрі |
|---|---|---|
| `craft_recipe_sheet.dart:162-168` | `baseYield * pow(craftYieldStep,_tier)`, `max(craftMinSeconds, baseSeconds*pow(craftTimeStep,_tier)/_jobSpeed)` | `CraftLine.unitsPerCraft`, `craftSeconds` (`craft_line.dart:22-35`) |
| `craft_recipe_sheet.dart:309-316` | те саме, вдруге в тому ж файлі | — |
| `craft_line_card.dart:180-188` | «стартовий темп тиру» `1 − craftSeconds/(baseSeconds*pow(craftTimeStep,tier))` | немає — формула народилась в UI |
| `craft_line_card.dart:468-470` | `pow(craftYieldStep/CostStep/TimeStep, tier)` | — |
| `craft_resource_strip.dart:102` | `pow(craftCostStep, line.tier.value)` | `CraftLine.starving` рахує те саме (`craft_line.dart:42`) |
| `replicator_screen.dart:106` | `replicatorYieldOf(id) / replicatorSeconds(id)` — темп машини | `replicatorPerMinuteOf` (`:1948`) — **і він мертвий** |
| `replicator_screen.dart:210-216` | `_nextSeconds` — `× 0.99` з клампом підлоги | `replicatorSeconds` (`:1898`) — та сама формула, інший рівень |

**Чому проблема.** Правило 10: *«кнопка цитує ту саму формулу, що й механіка, **з одного місця**»*. Сьогодні тирова математика крафту живе у пʼяти місцях, і будь-яка зміна `craftTimeStep`/підлоги вимагає ручного синхрону чотирьох файлів.

**Виправлення.** Чисті статичні функції в `craft_recipe.dart` (вони не читають сигналів, тож гетер там законний):
```dart
double craftUnitsAt(CraftRecipe r, int tier);
double craftSecondsAt(CraftRecipe r, int tier, double speed); // з клампом craftMinSeconds
double craftCostScaleAt(int tier);
```
`CraftLine.craftSeconds`/`unitsPerCraft` кличуть їх же, пікер — теж. Для реплікатора — `replicatorSecondsAt(id, speedLevel)` в ядрі; `_nextSeconds` стає `replicatorSecondsAt(id, level+1)`, а `replicatorPerMinuteOf` або воскресає (`× 60`), або замінюється на `replicatorPerSecondOf` під нову вітрину «+X / с».

**Обсяг:** M. **Міграція:** ні. **RNG:** ні.

---

#### В7. `replicatorUnlockCost` обходить власний хелпер `_tierOf`

`prototype_simulation.dart:1813-1825` проти `:1771-1788`

```dart
static double replicatorUnlockCost(ResourceId id) {
  for (final group in tradeGroups) {
    if (group.ids.contains(id)) {
      return switch (group.key) { 'materials' => 5000, 'building' => 2500, 'tech' => 750, _ => 5000 };
```

Журнал (2026-09-01): *«Усі тирові числа зведені в ОДИН хелпер `_tierOf(id, m, b, t)` — нова тирова таблиця це один рядок, а не свій switch»*. Тут — рівно свій switch, повна копія тіла `_tierOf`. Заміна на `_tierOf(id, 5000, 2500, 750)` — один рядок. **Обсяг:** S.

---

#### В8. Реплікатор: чотири паралельні мапи замість обʼєкта машини

`prototype_simulation.dart:1828-1893` — `_replicatorUnlocked`, `_replicatorSpeed`, `_replicatorAmount`, `_replicatorFraction`, усі `{for (final row in craftTable) row.output: Signal(...)}`, плюс 12 методів-аксесорів (`:1890-1951`) і по три гілки в `toJson`/`readJson` (`:2539-2554`, `:2749-2780`).

`CraftLine` (`craft_line.dart`) — доведений у цьому ж проєкті контрприклад: один клас, свої сигнали, свій `toJson/readJson`, свої `Computed`. **Виправлення:** `ReplicatorMachine(stock, id)` з полями `unlocked/speed/amount/fraction` і `Computed` `seconds`/`yield`/`perSecond`; `PrototypeSimulation` тримає `Map<ResourceId, ReplicatorMachine>`. Ключі сейву не міняються ('u'/'sp.'/'am.'/'fr.'), тож **міграція не потрібна**. **Обсяг:** M.

---

#### В9. Нуль тестів застосунку; міграції сейву не покриті взагалі

`packages/stratum_app/` не має теки `test/`, хоча `flutter_test` і `flutter_driver` — у dev-залежностях (`pubspec.yaml`), а `test_driver/app.dart` існує для ручних сесій.

Найгостріше: **ланцюг міграцій v1→v8 живе у `game.dart:75-193`**, тобто в пакеті без жодного тесту. Це найкрихкіший код проєкту (мапи, `?? 0`, перенесення секцій), і він єдиний, який неможливо перевірити `dart test`. `save_codec_test.dart` тестує сам механізм ланцюга, але не ці сім міграцій.

**Виправлення (мінімум):** перенести список `migrations` у ядро (`src/save_migrations.dart`) — він не залежить від Flutter, лише від мап і `PrototypeSimulation.generationOf` — і покрити кожен крок фікстурою «сейв версії N → readJson не кидає й дає очікуваний стан». **Обсяг:** M. **Міграція:** ні (список той самий, лише переїхав).

---

### 🟡 БАЖАНО

---

#### Б1. Мертві вітрини та мертвий payload на гарячому шляху

`StrikeOutcome` несе `spent`, `regolithGained`, `oresGained` (`strike_outcome.dart:24-33`) — **застосунок не читає з них нічого**, крім `landed`, `critical`, `layersBroken` (`game.dart:1028-1033`), бо дохід тепер звітує наглядач складу (`game.dart:1034-1035`). Те саме для `CycleOutcome.regolithGained/crystalsGained/quantoniumGained` (`game.dart:945-975` читає лише `critical`, `thickLayersBroken`, `layersBroken`, `echoes`).

Ціна: `_rollLoot` алокує `Map<ResourceId, BigDouble>` на **кожен** удар (`:1301`), а `strike()` ще й мутує її каскадом `..remove` (`:1284`) — 10 мап/с при затиснутому пальці, які нікуди не йдуть.

Плюс: `quantoniumGained` (`:1397-1399`) повертає **немножений** дроп, а не те, що реально впало на склад (крит його множить) — тобто поле ще й бреше.

**Виправлення:** урізати обидва `*Outcome` до того, що читається, і не збирати `loot` map, коли вона нікому не потрібна (передавати `null` у прапорці). **Обсяг:** S–M. **RNG:** ні.

---

#### Б2. Пʼять різних форматерів часу

| Файл:рядок | Формат |
|---|---|
| `ui/craft_clock.dart:3-10` | `1h 5m 27s`, пропуск нулів |
| `ui/craft_line_card.dart:1141-1148` | `43s` / `1:27` / `61m` |
| `ui/trade_request_card.dart:150-154` | `m:ss` з мс |
| `ui/trade_screen.dart:247-253` | `m:ss` з мс — **байт у байт та сама логіка** |
| `ui/shell/breach_overlay.dart:27-36` | `h:mm:ss` |
| `ui/simulation_screen.dart:25-34` | `Nд h:mm:ss` |

Останні дві пари відрізняються лише формою виводу. **Виправлення:** один `ui/clock_text.dart` з чотирма іменованими функціями (`craftClock`, `shortClock`, `mmss`, `hmsClock`, `simClock`). Мінімальний безсуперечний крок — злити `trade_request_card._left` і `trade_screen._clockText`. **Обсяг:** S.

---

#### Б3. Дубльовані віджети й painter-и

Див. таблицю в розділі 3. Найбільші: `arm_diagram.dart` ↔ `drill_diagram.dart` (спільний `_paintFace`, каркас тікера, `_ease` — ~120 рядків), «рядок прокачки» `part_card.dart:38-117` ↔ `track_row.dart:31-116` (~80 рядків), фазове серво `craft_line_card.dart:71-123` ↔ `replicator_screen.dart:386-419` (~35 рядків одного алгоритму, описаного в журналі як правило).

---

#### Б4. `arm_style.dart`: кроки бафів — літерали поруч із реальними константами

`packages/stratum_app/lib/ui/arm_style.dart:45-66`

```dart
ArmBuff(label: 'базова потужність', step: '+10 / рів.', total: _bitPower),
ArmBuff(label: 'мін. реголіт', step: '×1.03 / рів.', total: _bitMinRegolith),
ArmBuff(label: 'пробивання', step: '+0.001% / рів.', total: _drivePierce),
```

`total` читає справжні `PrototypeSimulation.basePowerPerLevel/minRegolithGrowth/piercePerLevel` (`:86-110`), а `step` — рядковий літерал тих самих чисел. Сьогодні вони збігаються; після першого ж тюнінгу балансу (а він попереду за правилом 0) картка почне брехати про крок, а підсумок казатиме правду. **Виправлення:** будувати `step` з тієї ж константи (`'×${minRegolithGrowth} / рів.'`). **Обсяг:** S.

---

#### Б5. `craft_line.dart:79` дублює `unitsPerCraft` усередині одного класу

```dart
ratePerSecond = Computed(() {
  ...
  final baseUnits = row.baseYield * math.pow(craftYieldStep, tier.value);  // = unitsPerCraft.value
```
`unitsPerCraft` — сусідній `Computed` (`:31-35`). Заміна дає і DRY, і кеш. **Обсяг:** S.

---

#### Б6. `Opacity` у покадрових сценах замість альфи в paint

`craft_line_card.dart:1341`, `replicator_screen.dart:455,476`, `drill/layer_tile.dart:33`, `drill/flash.dart:56`, `floating_number_view.dart:55`, `notices.dart:79`, `evolve_overlay.dart:173,204`.

Кожен `Opacity` з непостійним значенням у дереві, що перебудовується щокадру, — це `saveLayer` на кожен кадр. Для `flash`/`notices`/`floats` це маленькі області (терпимо), для `layer_tile.dart:33` — **кожна з ~64 плиток породи**, і значення там статичне (`isPast/isCurrent`), тобто його взагалі можна вшити в кольори градієнта. **Обсяг:** S (layer_tile) / M (решта).

---

#### Б7. `LayerTile` отримує `hpFraction`, який потрібен лише поточній плитці

`ui/drill/rock.dart:86,93` — `hpFraction` передається всім плиткам, хоч `damage` використовує лише гілка `isCurrent` (`layer_tile.dart:58-60`). Кожна зміна hp міняє конфігурацію всіх ~64 плиток; від зайвого перемальовування рятує лише `RepaintBoundary` + чесний `StonePainter.shouldRepaint` (`stone_painter.dart:200-201`). **Виправлення:** передавати `hpFraction` тільки поточній (`isCurrent ? hp : 0`), решті — константу. **Обсяг:** S.

---

#### Б8. Алокації рядків RNG-потоків на кожен рол

`prototype_simulation.dart:1306,1317,1327,1334,1346,1355` — шість `'${prefix}...'` інтерполяцій + шість `Map.putIfAbsent` (`random_source.dart:133-134`) на кожен удар. Виправляється кешем `RandomStream`-посилань на смугу (`_handStreams` / `_rigStreams`, побудовані раз). **Ключова умова: імена потоків не міняються** — інакше паритет ролів злетить. **Обсяг:** S. **RNG:** нейтрально при незмінних іменах.

---

#### Б9. Сейв: секції пишуться навіть порожніми

`prototype_simulation.dart:2555-2578` — `'craft'` і `'trade'` (з `'off': []`, `'share': {}`) пишуться завжди; `'data'`, `'arm'`, `'tree'`, `'bores'` — теж безумовно, разом із нульовими рівнями. Правило «лише відхилення від дефолтів» дотримане в `finance` (`:2530-2538`), `replicator` (`:2539-2554`) і `CraftLine.toJson` (`craft_line.dart:161-174`), але не в старших секціях. Не баг, але це і є та неоднорідність, через яку наступна секція знову напишеться «як усі». **Обсяг:** S.

---

#### Б10. `SaveStore.list()` ковтає помилки мовчки

`packages/stratum_app/lib/save_store.dart:83-87`
```dart
try { held = await read(slot); } on Object { continue; }
```
Слот, який не читається через I/O, просто зникає зі списку — при тому що `storageFault` (`game.dart:555`) існує саме для того, щоб пояснити гравцеві порожній слот. Плюс `_summarise` (`:95-129`) ловить лише `FormatException`, а `BigDouble.parse` в ньому (`:111`) кидає `FormatException` — ок, але `SaveSummary` з побитим `meta.stock` мовчки втрачає ресурси. **Обсяг:** S.

---

#### Б11. Кнопка калібрування реплікатора — купівля без `holdRepeat`

`ui/replicator_screen.dart:240-246` — платить ресурсом + КВ, але `holdRepeat` немає. Правило 1 формально порушене; фактично покупка одноразова (`unlockReplicator` вдруге поверне `false`), тож повтор безглуздий. **Рішення власника:** або додати для однорідності, або дописати в журнал виняток «одноразові покупки — без повтору». **Обсяг:** S.

---

#### Б12. Логіка й презентація в `game.dart`

- `game.dart:824` — `energyInterval` повертає готовий рядок з українською «с» (форматування в координаторі);
- `:826-827` — `secondsLabel` (мертвий);
- `:954-974` — координати, кольори (`0xFFFFD782`) і тексти плаваючих чисел зашиті в координатор; `:1015-1016` — псевдовипадкове розкидання по екрану через `hitShakes.value * 37 % 150`.

Це презентація, і їй місце в `ui/` (поруч із `FloatingNumberView`), а `Game` мав би віддавати подію («товстий шар пробито»), а не її верстку. **Обсяг:** M.

---

### ⚪ КОСМЕТИКА

- **Цикл імпорту** `ui/hud/box.dart` ↔ `ui/hud/corners.dart` — наслідок розрізання `hud.dart`; лікується виносом `HudCorners`/`HudSides` у `hud/geometry.dart` без `CornerClipper`.
- **Кириличні коментарі** в `ui/building/building_node.dart:78,79,112,145,177,212,267,304,392` (банери секторів) — порушення стандарту «коментарі англійською»; решта репозиторію чиста (кирилиця в інших файлах — це цитати UI-рядків, законно).
- **Застарілі коментарі:**
  - `ui/blow_summary.dart:30-33` — «the sum visibly equals the drive's own bonus plus **the 0.02% floor** every blow carries», а підлогу видалено 2026-09-01 (`prototype_simulation.dart:1072-1076`);
  - `craft_recipe.dart:24-28` — «the duplicate chance rides on top **as an expectation** (the conversion is continuous…)», хоча крафт v2 зробив дубль справжнім ролом (`prototype_simulation.dart:2078`);
  - `craft_line.dart:70-73` — «**the ramp** AND the duplicate chance… deliberately not quoted», хоча розгін тепер усередині `speedFactor` (`:15-21`) і, отже, всередині `ratePerSecond`. *(Гіпотеза: поведінка відповідає журналу — «без стеків **майбутніх**», — тобто виправити треба саме коментар.)*
  - `prototype_simulation.dart:184-186` і `:248-256`, `:278-282`, `:541-555` — місцями по два doc-коментарі поспіль на одне поле (сліди редагувань).
- **`strike()` мутує чужу мапу каскадом** (`:1284`: `oresGained: rolled.loot..remove(...)`) — працює лише завдяки порядку обчислення іменованих аргументів; крихко.
- **`_readInt` мовчки ковтає нецілі** (`:2816-2817`): `5.0` з JSON → fallback. Плюс `craft['last']` читається інлайном (`:2784-2786`) замість `_readInt` — три різні читачі чисел в одному методі.
- **`uses-material-design: true`** (`stratum_app/pubspec.yaml`) при повній відсутності `package:flutter/material.dart` у коді — у бандл їде шрифт MaterialIcons.
- **`_disposed` у `TickEngine.dispose()`** ставиться після `_stopTimer()` — коректно, але `dispose()` не ідемпотентний щодо `_assertUsable` у вже запланованому колбеку; на практиці не стріляє.

---

## 3. Таблиця дублікатів

| # | Місця (`файл:рядок`) | Обсяг | Спільна абстракція | Ризик |
|---|---|---|---|---|
| Д1 | `ui/arm_diagram.dart:238-300` ↔ `ui/drill_diagram.dart:204-240` (вибій, градієнт, тріщини, лінія) + `:118-125`/`:108-115` (`_ease`, `dispose`) + `:76-90`/`:74-88` (тікер) | ~120 рядків | `ui/drill/face_backdrop.dart` — функція `paintFace(canvas, ...)` + міксин `FramePhase` | Низький (чиста графіка) |
| Д2 | `ui/part_card.dart:38-117` ↔ `ui/track_row.dart:31-116` | ~80 | `UpgradeRow({leading, title, note, level, capped, cost, onBuy})` | Середній: різні гліфи (`PartFace` vs `_TrackGlyph`) і різні підвали (`_MarkProgress` vs `_Effect`) — параметризувати слотами |
| Д3 | `ui/craft_recipe_sheet.dart:162-168` ↔ `:309-316` ↔ `ui/craft_line_card.dart:468-470,180-188` ↔ `ui/craft_resource_strip.dart:102` | ~30 | чисті `craftUnitsAt/craftSecondsAt/craftCostScaleAt` у `craft_recipe.dart` (див. В6) | Низький; тести крафту пришпилюють поведінку |
| Д4 | `ui/craft_line_card.dart:71-123` ↔ `ui/replicator_screen.dart:386-419` (плавна фаза + серво + снап на діру кадрів) | ~35 × 2 | `ui/phase_servo.dart` — `class PhaseServo { void advance(dt, core, unitSeconds); double get phase; }` | Середній: правило 2 журналу вимагає точної поведінки — обовʼязково юніт-тест на серво до рефакторингу |
| Д5 | `ui/strikes_screen.dart:114-134` ↔ `ui/drill_detail.dart:145-165` | ~20 × 2 | `TrackHeader(label, batch, onPick)` | Низький |
| Д6 | `ui/craft_line_card.dart:513-525` ↔ `ui/craft_recipe_sheet.dart:393-405` (комірковий трек 14 тирів) | ~13 × 2 | `TierTrack(tier, tierCap, colour)` | Низький |
| Д7 | `ui/trade_request_card.dart:150-154` ↔ `ui/trade_screen.dart:247-253` (+3 інші форматери, Б2) | ~6 × 5 | `ui/clock_text.dart` | Низький |
| Д8 | `ui/drill/bit.dart:35-45` ↔ `ui/drill/pipe.dart:23-33` ↔ `ui/drill/shaft.dart:29-39` ↔ `ui/shell_backdrop.dart:26-36` ↔ `ui/arm_diagram.dart:76-86` ↔ `ui/drill_diagram.dart:74-84` | ~10 × 6 | `mixin FrameClock on State` (тікер + `clampFrameDelta` + `ValueNotifier<double>`) | Низький |
| Д9 | `ui/part_card.dart:104-114` ↔ `ui/track_row.dart:102-113` («межа» vs `BuyButton`) | ~11 × 2 | `BuyButton.capped()` конструктор | Низький |
| Д10 | `ui/evolve_overlay.dart:239-250` ↔ `ui/part_sheet.dart:203-214` (рядок бафа) | ~12 × 2 | `BuffRow(buff, sim)` (є `_BuffRow` у `part_card.dart:271` — третя копія) | Низький |
| Д11 | `ui/drills_screen.dart:124-140` ↔ `ui/part_card.dart:60-93` ↔ `ui/part_sheet.dart:143-150` ↔ `ui/track_row.dart:59-93` (шапка «іконка + назва + примітка + число») | ~15 × 4 | `HudTitleRow` | Низький |
| Д12 | `test/energy_cadence_test.dart:1-27` ↔ `test/tick_engine_test.dart:1-22` (`TestClock`, `elapse*`) | ~25 × 2 | `test/support/test_clock.dart` | Нульовий |
| Д13 | `test/arm_test.dart:4-11` (`_funded`) ↔ `test/yield_rate_test.dart:6-12` (`_at`) ↔ `test/prototype_simulation_test.dart:8-15` (`_played`) ↔ `test/data_progress_test.dart:6-10` (`_pinLayer`) | ~10 × 4 | `test/support/sim_fixtures.dart` (`stocked()`, `funded()`, `atDepth()`) | Нульовий |
| Д14 | `prototype_simulation.dart:1813-1825` ↔ `:1771-1788` (`_tierOf`) | 13 | сам `_tierOf` (В7) | Нульовий |
| Д15 | `prototype_simulation.dart:1018-1031` (`upgradeDrill`) ↔ `:1167-1178` (`upgrade`) ↔ `:1033-1046` ↔ `:1181-1194` (`affordable*`) | ~14 × 4 | `_buyLevels({Signal<int> level, cap, BigDouble Function(int) price, ResourceId coin})` — одна пара на всі треки | Середній: `affordableLevels` порівнює `gteWithTolerance` (`:1188`), а `affordableDrillLevels` — голим `<` (`:1040`). **Це ще й розбіжність із правилом «ігрові гейти зобовʼязані користуватись порівнянням із допуском»** — злиття заразом її лікує |

---

## 4. Мертвий код

Доказ — grep по всьому workspace, включно з `test/` і `tool/`. «[1]» = єдине входження, тобто саме оголошення.

| Символ | `файл:рядок` | Доказ / статус |
|---|---|---|
| `canBuyDrill` | `prototype_simulation.dart:1505` | [1] — жодного виклику |
| `buyDrill` (ядро) | `:1507` | лише `Game.buyDrill` + `prototype_simulation_test.dart:19` |
| `Game.buyDrill` | `game.dart:1040-1043` | [0] викликів з UI — скасована економіка (журнал 2026-08-30) |
| `canBuyPowerUpgrade` | `:1514` | [1] |
| `buyPowerUpgrade` (ядро) | `:1517` | лише `Game.buyPowerUpgrade` |
| `Game.buyPowerUpgrade` | `game.dart:1045-1048` | [0] викликів з UI |
| `powerUpgradeCost` (Computed) | `:44-50`, `:360` | читається лише мертвою парою вище |
| `drillCost` (Computed) | `:58-65`, `:362` | читається лише `canBuyDrill`/`buyDrill` |
| `nextMilestone` | `:2826-2831` | [1] |
| `criticalChance` | `:521` | [1] — реальний шанс береться з `strikeCritChance`/`drillCritChance` |
| `criticalMultiplier` | `:523` | [1] |
| `quantoniumChance` | `:536-539` | [1] — цикл котить `strikeQuantoniumChance` (`:1346`) |
| `collapseReady` | `:693` | [1] — UI кличе `pendingCollapses` (`simulation_screen.dart:100`) |
| `sellingResources` | `:2312` | [1] |
| `backgroundCompute` | `:202` | [1] |
| `capsules` / `cores` (гетери sim) | `:200`, `:201` | [1] кожен — «Капсули і Ядра скасовано» (журнал); самі `ResourceId` ще потрібні `resource_style.dart` |
| `dataBanked` | `:267`, тільки `toJson`/`readJson` | пишеться й читається, ніким не використовується — мертвий стан у сейві |
| `replicatorPerMinuteOf` | `:1948-1951` | лише `replicator_test.dart:215,218`; UI рахує темп сам (`replicator_screen.dart:106`) |
| `setCraftHalted` | `:2160-2162` | лише `craft_test.dart` — журнал це визнає («UI її поки не кличе»), але `halted` у UI читається (`craft_line_card.dart:141`) |
| `Game.yieldPerSecond` | `game.dart:817-821` | [1] — Склад більше не показує «X / с» (`warehouse.dart:50-52`) |
| `Game.secondsLabel` | `game.dart:826-827` | [1] |
| `StrikeOutcome.spent`/`regolithGained`/`oresGained` | `strike_outcome.dart:24-33` | застосунок не читає (Б1) |
| `CycleOutcome.regolithGained`/`crystalsGained`/`quantoniumGained` | `cycle_outcome.dart:25-27` | застосунок не читає; `quantoniumGained` ще й неточний |
| `Stockpile.dispose` | `stockpile.dart:126-130` | [1] — ніхто не кличе (акт Перезапуску ще не написаний; лишити як гачок) |

**НЕ мертве, хоч і схоже:** `ScreenPlaceholder` (`game_shell.dart:132`) обслуговує 10 запланованих екранів (`planets`, `lab`, `avatar`, `samples`, `analytics`, `settings`, `daily`, `achievements`, `stats`, `account`) — це дорожня карта, а не сміття. `test_driver/app.dart` — вхід для асистованих сесій, задокументований.

**Тестів, що нічого не перевіряють, не знайдено:** у кожному з 27 файлів `expect` більше, ніж `test` (мінімум — `structural_damage_test.dart`: 3 тести / 4 expect).

---

## 5. Карта `PrototypeSimulation` і план декомпозиції

### 5.1 Групи відповідальностей

| # | Група | Рядки | Обсяг | Ключові члени |
|---|---|---|---|---|
| 1 | Конструктор і збірка графа | 29-182 | 154 | 17 `Computed`, ланцюг фінансування, `_resetLayer()` |
| 2 | Базовий стан рана | 187-296 | 110 | `layer`, `stock`, 8 гетерів-вью, `drills`, `modules`, `restarts`, `energy`, треки Аватара/дерева, `servers` |
| 3 | **Визнаний годинник** | 298-348 | 51 | `absenceCapMs`, `wallSeenMs`, `runStartSeenMs`, `lastWallMs`, `seenNow`, `observeWall`, `simSeconds` |
| 4 | Шар і його похідні | 350-372 | 23 | `layerHp/Max`, `layerDensity`, `hitsToBreak`, `layerEffort`, `strikeBite` |
| 5 | Енергія | 374-397 | 24 | `energyCapBase`, `energyCap`, `energySeconds`, `regenSpeedPerLevel` |
| 6 | Марки/еволюція | 399-425 + 1109-1194 | 113 | `markCeiling/Floor/Span`, `generationOf`, `levelOf/markOf/peakOf`, `canEvolve`, `evolve`, `upgrade`, `affordableLevels` |
| 7 | Порода: щільність, товсті шари, таблиця руд | 427-519 | 93 | `densityAt`, `isThick`, `spanOf`, `nextLayer`, `layerStart`, `oreTable`, `oreDropAt`, `crystalDropAt` |
| 8 | Шанси | 521-539 | 19 | `crystalChance(At)`, `quantoniumChance`(мертвий), `echoChance` |
| 9 | **Дані / Колапс / стійки / дрейф** | 541-707 | 167 | `rawPerCube`, `compileRate`, `walletEarned`, `collapseThreshold`, `driftDays/Progress/Discount`, `pendingCollapses`, `rackFill`, `_recordData` |
| 10 | **Офлайн** | 709-838 | 130 | `offlineEfficiency`, `offlineSliceSeconds`, `settleAbsence`, `claimOffline` |
| 11 | Удар: константи | 840-886 | 47 | `baseStrikePower`, `strikeShareOfRig`, `rawDataChance`, `strikeCrit*` |
| 12 | **Бури** | 888-1046 | 159 | `drillTable`, `drillState`, `drillRadius/Area/YieldScale/Interval`, `drillDriveCap`, `drillCostOf`, `canUpgradeDrill`, `upgradeDrill`, `affordableDrillLevels` |
| 13 | **Маніпулятор** | 1048-1194 | 147 | `strikeRegolithMin/Max`, `armPowerAt`, `pierceShare`, `strikePower(At)`, `costOf`, + група 6 |
| 14 | Вітрини темпу | 1196-1261 | 66 | `expectedPerStrike`, `expectedPerCycle`, `yieldPerSecond` |
| 15 | **Цикл удару** | 1263-1493 | 231 | `strike`, `_rollLoot`, `_cycle`, `_applyDamage`, `_breakLayer`, `_resetLayer` |
| 16 | Реген + мертві покупки | 1495-1522 | 28 | `regenerateEnergy`, `buyDrill`/`buyPowerUpgrade` (мертві) |
| 17 | **Фінансування** | 1524-1756 | 233 | `fundTable`, `_funding`, `_financeRound/Rank/Cap`, `tranchesInto`, `grantFundLevels`, `_fundingBooksBalance`, `_resetFunding`, `fundScaleOf`, `_earnCredits` |
| 18 | **Реплікатор** | 1758-1995 | 238 | `_tierOf`, 4 мапи сигналів, 12 аксесорів, `syncReplicator`, `_runReplicator` |
| 19 | **Крафт** | 1997-2229 | 233 | `craftLines`, `syncCraft`, `_runCraftLine`, `_loadCraftUnit`, `_refundCraftUnit`, `assignCraftRecipe`, `setCraftTier/Halted`, 3 покупки |
| 20 | **Торгівля: прейскурант і продаж** | 2231-2371 | 141 | `priceTable`, `tradeGroups`, `_selling`, `_sellShare`, `sellPrice/Lot/Yield`, `sellAll(Yield)`, `sellPosition` |
| 21 | **Запити** | 2373-2477 | 105 | `requests`, `syncRequests`, `_spawnRequest`, `requestPayout`, `fulfilRequest` |
| 22 | **Сейв** | 2479-2823 | 345 | `toJson` (97), `readJson` (227), `_readInt/_readDouble/_readBig` |
| 23 | Легасі рига | 2825-2847 | 23 | `nextMilestone`(мертвий), `perDrillPowerWith`, `powerWith`, `_milestoneMultiplier` |

**Найдорожчі:** сейв (345), реплікатор (238), фінансування і крафт (по 233), цикл удару (231).

### 5.2 План декомпозиції — кроки, порядок, ризики

Принцип, який уже доведено `CraftLine`: **підсистема = свій файл, свої `Signal`, свої `Computed`, свої `toJson/readJson`, залежність лише від `Stockpile`** (+ `RandomSource`, де є роли). `PrototypeSimulation` лишається фасадом: тримає підсистеми, делегує методи (щоб UI і 464 тести не змінювались), склеює сейв.

**Крок 0 — страховка (обовʼязково перший).**
Додати тест-«золотий слід»: сім з фіксованим сідом, 5000 тіків + 5000 ударів, звірка (глибина, увесь склад, `random.toJson()`) з еталоном, знятим ДО рефакторингу. Це і є детектор зсуву RNG на всіх наступних кроках. Плюс раундтрип `toJson→readJson→toJson` на насиченому стані. *Ризик без цього кроку — головний ризик усього плану.*

**Крок 1 — `TradeDesk` (група 20+21, ~246 рядків).**
Найбезпечніша: залежить лише від `stock`, `fundScaleOf` (передати колбеком) і потоку `trade.request`. Сейв — уже окрема секція `'trade'`. Ризики: `_spawnRequest` тягне `random.stream('trade.request')` — імʼя потоку **не змінювати**.

**Крок 2 — `ReplicatorBank` + `ReplicatorMachine` (група 18, ~238).**
Чотири мапи → мапа обʼєктів (В8). Ключі сейву ті самі. RNG не задіяний узагалі. Заразом закрити В7 (`_tierOf`) і винести `replicatorSecondsAt(level)` для прев'ю (В6).

**Крок 3 — `FinancingBooks` (група 17, ~233).**
Уже суцільний ланцюг `Computed`; переїжджає майже механічно. Обережно: `fundScaleOf` кличуть `_rollLoot`, `_breakLayer`, `expectedPerStrike`, `sellYield`, `requestPayout` — фасадний делегат обовʼязковий. Секція `'finance'` і самолікування (запобіжник №6) переїжджають цілком, разом із тестами `financing_test.dart`.

**Крок 4 — `CraftShop` (група 19, ~233).**
`CraftLine` уже виділений; переїжджають `syncCraft`, `_runCraftLine`, `_loadCraftUnit`, `_refundCraftUnit`, покупки. Тонке місце — `settleAbsence` кличе `_runCraftLine` посеред скибки: `CraftShop.runSlice(seconds, made, offline: true)` як єдина точка входу.

**Крок 5 — `AbsenceSettler` (група 10, ~130).**
Після кроків 2 і 4 у `settleAbsence` лишається оркестрація: скибка → дохід → верстаки → реплікатори. Тут же зробити В4 (винести карту темпів із циклу).

**Крок 6 — `CollapseLedger` (група 9, ~167).**
Дані, куби, стійки, дрейф. Залежить від визнаного годинника — його (група 3, 51 рядок) винести окремо як `AcknowledgedClock` ще на кроці 5, бо ним користуються всі синки.

**Крок 7 — `DrillBank` (12) і `ArmTracks` (6+13).**
Тут же злити чотири копії `upgrade/affordable` в один `_buyLevels` (Д15) і полагодити розбіжність із допуском (`:1040`).

**Крок 8 — `SimulationSave` (група 22, 345).**
Після кроків 1-7 `toJson/readJson` схудне до склейки секцій: кожна підсистема відповідає за свою. Тут же — К3 (стійке читання), Б9 (лише відхилення), єдиний `_readInt`.

**Крок 9 — прибирання.** Мертвий код розділу 4, група 23, група 16.

**Що лишиться в `PrototypeSimulation`:** порода і цикл удару (групи 4, 7, 8, 11, 14, 15) ≈ 600-700 рядків — це і є «симуляція буріння», далі різати немає сенсу.

**Ризики й запобіжники (наскрізні):**
- **Сейв-сумісність** — жоден крок не змінює жодного ключа; після кожного кроку прогнати раундтрип на реальному сейві власника.
- **RNG-паритет** — імена потоків (`strike.regolith`, `cuprite`, `echo`, `trade.request`, `*quantonium.loot`, `*rawdata`) — заморожені рядкові літерали; будь-яке перейменування = зсув усіх ролів.
- **Порядок ролів** — `_rollLoot` (`:1305-1362`) тягне числа у фіксованій послідовності; при переїзді не змінювати порядок гілок.
- **API для UI** — 39 файлів імпортують `game.dart` і крізь нього `sim`; фасадні делегати обовʼязкові, інакше кожен крок = правка десятків екранів.

---

## 6. Прогалини тестів

| Підсистема | Покриття сьогодні | Прогалини — конкретні сценарії |
|---|---|---|
| **Бури / радіус** | `yield_rate_test.dart:462` («площа розширює ЛИШЕ свій ресурс»), 8 тестів | немає тесту на `drillDriveCap` (мертві рівні не продаються: `upgradeDrill` на капі повертає 0 і нічого не списує); немає на `affordableDrillLevels` при рівно достатньому гаманці (розбіжність допуску, Д15) |
| **Товсті шари** | `prototype_simulation_test.dart` (пробиття, `layerStart`) | **немає тесту на К1**: «рівень фінансування реголіту множить виплату товстого шару так само, як лут-рол»; немає на `maxLayersPerCycle` (кап 25 шарів за цикл) |
| **Структурна шкода** | `structural_damage_test.dart` (3 тести) | немає гілки `share == 0` для `layerEffort` (`:95-101`) — саме її 2026-09-01 зробили досяжною, видаливши підлогу; немає перевірки «`hitsToBreak` збігається з фактичною кількістю ударів ±1» |
| **Фінансування** | `financing_test.dart` (15 тестів, анти-лок інваріант, подарунки, самолікування) | найкраще покрита підсистема; бракує лише «`_resetFunding` не чіпає здоровий сейв із подарунками на капі» |
| **Торгівля** | `trade_test.dart` (9) | немає на закінчення строку запиту рівно в `expiresAtMs`; немає на «довга відсутність постить не більше повної дошки» (`syncRequests:2406-2415` — гілка з `break`); немає на групові свічі з сейву легасі-формату (`readJson:2721-2729`) |
| **Крафт** | `craft_test.dart` (24) — передоплата, повернення, стеки, підлога 1 с, офлайн-скибки | немає на `setCraftHalted` під час синку (механіка є, UI не кличе — тест і є її єдиний власник); немає на `buyCraftLine`, коли `craftLines.length < craftStartLines` після побитого сейву |
| **Реплікатор** | `replicator_test.dart` (13) | немає на «частка з сейву поза [0,1] клампиться» (`readJson:2775-2777`); немає на паралельність двох тирів з різними `durationFactor` в одному спані |
| **Сейв-міграції** | `save_codec_test.dart` (21) — сам механізм ланцюга | **міграції v1→v8 (`game.dart:75-193`) не покриті жодним тестом** — вони в пакеті без тестів (В9). Мінімум: сім фікстур, по одній на крок, + «сейв v8 із побитим значенням не кидає» (К3) |
| **Годинник / бріч** | `collapse_drift_test.dart` (кап на проміжок, монотонність, раундтрип) | немає тесту на `simSeconds`/`runStartSeenMs` (нова вітрина Датацентру); немає на послідовність «бріч → чистий слот знімає → зіпсутий підіймає» (це логіка `Game`, знову без тестів) |
| **Офлайн** | `prototype_simulation_test.dart` (6 сценаріїв `claimOffline`), `data_progress_test.dart` | немає на «одна скибка 3600 с == 60 скибок по 60 с» для ЗВʼЯЗКИ видобуток+крафт+реплікатор (для крафту окремо є) |
| **Застосунок** | **нічого** | Мінімум, який варто завести: (1) `widget test` на `GameShell` — застосунок будується і перемикає секції; (2) golden на `CraftLineCard` у трьох станах (порожня / працює / голодна) — правило «стала висота в усіх станах» перевіряється саме так; (3) unit-тест на форматери часу (Б2) після їх злиття; (4) тест на `PhaseServo` (Д4) — правило 2 «анімація ніколи не наздоганяє» зараз тримається лише на очах власника |

**Крихкі тести:** сіди без пояснення — `yield_rate_test.dart:6` (`seed = 808`), `prototype_simulation_test.dart` (дефолтний 20260825). Числа-літерали замість формул: `prototype_simulation_test.dart:108-117` (звірка з `strikeRegolithMin/Max` — це добре) проти `arm_test.dart:145-193` (частина очікувань — конкретні значення). `arm_test.dart:12-19` (`_bottomless` через `BigDouble(1, 600)`) прокоментований — зразок, як треба.

---

## 7. План рефакторингу: топ-10 за «цінність / ризик»

| # | Дія | Цінність | Ризик | Обсяг | Критерій готовності |
|---|---|---|---|---|---|
| 1 | **К1**: `fundScaleOf(regolith)` у виплатах пробиття (`:1464`, `:1479`), звести три точки в `_payRegolith` | Дуже висока (порушення правила формули) | Мінімальний | S | Новий тест: рівень фінансування реголіту множить виплату товстого шару; 464+1 зелених |
| 2 | **К3**: `_apply` ловить `Object`; тест на побите значення в сейві | Дуже висока (єдиний невідновний сценарій гравця) | Мінімальний | S | Сейв із `'regolith': 'abc'` → слот у карантині, гра стартує, нотис показано |
| 3 | **К4**: `_breachTimer?.cancel()` у `Game.dispose` | Висока | Нульовий | S | Немає «used after dispose» при закритті під брічем |
| 4 | **К2**: рішення власника по криту + виправлення коментаря `:1266-1269` (і/або журналу) | Висока (правда про механіку) | Низький, якщо (а); середній, якщо (б) | S/M | Журнал і код кажуть одне; при (б) — тести переведені на формулу, `random.toJson()` не змінився |
| 5 | **В1**: `strikeRegolithBand` у ядрі; `blow_summary` і `loot_table` цитують його | Висока (розрив вітрини) | Низький | S | Обидва екрани показують те саме число при `fundingOf(regolith) > 0` |
| 6 | **В5.1**: `craft_screen._sync` → `setState`; кеш `affordable*` у `part_card`/`track_row` | Висока (найпомітніший fps-виграш) | Низький | S | Профіль: ребілд дерева не частіше 1/с поза Шахтою; тримання пальця не дає stutter |
| 7 | **В3**: перевести 9 гарячих гетерів у `Computed` | Висока (правило графа + удар) | Середній: `Computed`, що читає `layerHp`, інвалідується щоудар — виміряти, що не гірше | M | 464 зелених; замір: час 10 000 ударів не зріс |
| 8 | **В6**: чисті `craftUnitsAt/SecondsAt/CostScaleAt` + `replicatorSecondsAt`; UI цитує їх | Висока (DRY, правило 10) | Низький | M | Жодного `math.pow(craft*Step, …)` поза `craft_recipe.dart`; grep чистий |
| 9 | **В9**: міграції → ядро + тест на кожен крок; каркас `stratum_app/test/` | Висока (найкрихкіший непокритий код) | Низький | M | 7 нових тестів; `flutter test` у застосунку запускається й зелений |
| 10 | **В2**, кроки 1-2: `TradeDesk` і `ReplicatorBank` із «золотим слідом» (крок 0) | Висока (розблоковує решту плану) | Середній: сейв + RNG | L | Золотий слід збігається до біта; раундтрип сейву власника цілий; 464 зелених |

*Далі за списком:* В4 (офлайн-скибки), Д2/Д5/Д9 (віджети прокачки), Д4 (`PhaseServo`), Б1 (payload удару), решта декомпозиції.

---

## 8. Що НЕ треба чіпати

Дивні на вигляд рішення, які журнал пояснює і які ревʼю **підтверджує як правильні**:

1. **`_startTimer` з одноразовими таймерами замість `Timer.periodic`** (`tick_engine.dart:160-185`). Виглядає як ускладнення — насправді єдиний спосіб не заморозити шкалу: періодичний таймер тримає фазу і проходить повз забанкований залишок (журнал, «Урок замерзлої шкали»; пришпилено `energy_cadence_test.dart`). Перевірка `identical(_timer, shot)` (`:179`) — захист від фантомного циклу, теж із регресійним тестом.
2. **`chance(p)` тягне число завжди, навіть при `p = 0`** (`random_source.dart:69-78`). Виглядає як марна робота — це фундамент паритету: зміна числа балансу не сміє зсунути послідовність.
3. **`random` не `final`** (`prototype_simulation.dart:184-187`). Ламає звичне «поля незмінні», але саме заміна джерела на читанні сейву дає продовження ролів з місця гравця.
4. **`meta` дублює дані рана** (`game.dart:514-525`). Свідома денормалізація: меню слотів описує сейв, не розбираючи ран; пишеться в тому ж виклику з того ж стану, тож розійтись не може.
5. **Пауза НЕ морозить настінні механіки** (дрейф, запити, крафт). Виглядає як баг — це прямий наслідок правила часозалежних механік, прийнятий свідомо.
6. **`cycleStartMs` у «визнаних» мс, старий епохальний ключ ігнорується** (`:2603-2606`). Втрата дрейфу старих сейвів — навмисна: визнаний годинник не може чесно прочитати епохальну мітку.
7. **`hud.dart` як барель із 15 export-ів** (`ui/hud.dart`) і `tokens.dart` із чотирма публічними класами. Журнал прямо називає це «когезивними сімʼями»; `tokens.dart` (77 імпортерів) — це мова, а не звалище.
8. **Файли з двома публічними класами виду `DrillBit` + `DrillBitState` + `BitPainter`** (`ui/drill/bit.dart` та ще 8 таких). `State` і painter — «власні одноразові листки» за формулюванням правила; це не порушення.
9. **`Gauge` замість `LinearProgressIndicator`** і взагалі відсутність Material. Обґрунтовано в журналі (Theme, крива, 4 px) і підтверджується кодом: `main.dart` будує `WidgetsApp`, не `MaterialApp`.
10. **`ProgressPainter` + `Gauge` в одному файлі**, `HudProgress` окремо від `Gauge`. Два різні типи смуги («ллється» проти «перетинають») — це мова інтерфейсу, а не дублікат.
11. **Дублікат `_ChamberPainter`/`_ConveyorPainter`-логіки фази** *виглядає* як Д4, але зводити її треба обережно: журнал описує чотири окремі уточнення поведінки (снап на діру кадрів, снап на новий джоб, тяга лише в момент осідання, розлив похибки). Спільний `PhaseServo` вартий того лише **разом із тестом**, який фіксує всі чотири правила.
12. **`craftLineCost` рахується від `craftLines.length - craftStartLines`** (`:2185-2188`), а `readJson` доливає лінії до `craftStartLines` (`:2796-2798`) — виглядає крихко, але це і є самолікування сейву, збитого зміною стартової кількості.
13. **Кириличні назви бурів і рецептів у ядрі** (`drillTable:924-928`, банери в `craft_recipe.dart`). Формально «презентація в ядрі», але це один рядок таблиці, а не система; винесення в `resource_style` коштувало б більше, ніж дає.

---

### Підсумок

Проєкт має рідкісну властивість: **журнал рішень і код здебільшого збігаються**, і там, де вони розійшлися, розбіжність вимірюється одиницями рядків (К1, К2, В1, В7), а не архітектурою. Тому найдорожче зараз — не переписувати, а **закрити чотири розбіжності з власними правилами** (пункти 1-5 плану), **поставити страховку у вигляді золотого сліду й тестів міграцій**, і лише потім різати `PrototypeSimulation` — у вже перевіреному порядку, де кожна підсистема має готовий зразок у вигляді `CraftLine`.

---

## 9. Статус виконання (2026-09-02)

Власник: «виправ все проблеми що були знайдені». Зроблено (посилання на
журнал: CLAUDE.md, «Архітектурний ревью і його виконання»):

| Знахідка | Статус |
|---|---|
| К1 фонд-множник у виплатах пробиття | ✅ `_payRegolith` — єдині двері; тест |
| К2 крит множить здобич | ✅ виконано правило: крит множить лише удар; RNG-потоки не зсунулись |
| К3 побитий сейв повз карантин | ✅ `_apply` ловить `Object`; читачі лагідні; тест |
| К4 `_breachTimer` у dispose | ✅ |
| В1 дві смуги реголіту | ✅ `strikeRegolithBand` |
| В2 god-object | ✅ 2848 → 1387; 8 підсистем; золотий слід |
| В3 голі гетери на гарячому шляху | ✅ Computed |
| В4 офлайн-скибки перераховують темпи | ✅ через кешовані Computed (перерахунок = читання кешу) |
| В5 один нотифікатор + важкі цикли | ✅ (1) `setState` у craft_screen, (2) мемо `affordable*`; (3) `SignalBuilder` — відкладено свідомо |
| В6 формули ядра в UI | ✅ `craftUnitsAt/SecondsAt/CostScaleAt/TimeScaleAt`, `replicatorSecondsAt`, `replicatorPerSecondOf` |
| В7 `_tierOf` обхід | ✅ |
| В8 реплікатор — 4 мапи | ✅ `ReplicatorMachine` |
| В9 нуль тестів застосунку, міграції без тестів | ✅ міграції в ядрі + 7 тестів; `stratum_app/test/` — 2 файли, 7 тестів |
| Б1 мертвий payload удару | ◐ поля лишились (їх читають тести); `quantoniumGained` чесний, каскад знято |
| Б2 п'ять форматерів часу | ✅ `clock_text.dart` |
| Б3/Д1–Д10, Д12–Д15 дублікати | ✅ (Д11 — частково через `UpgradeRow`) |
| Б4 кроки бафів літералами | ✅ друкуються з констант |
| Б5 дубль `unitsPerCraft` | ✅ |
| Б6 `Opacity` у сценах | ✗ свідомо: статичні плитки кешуються, решта — крихітні області |
| Б7 hp усім плиткам | ✅ |
| Б8 алокації імен потоків | ✅ `_LootStreams`, імена незмінні |
| Б9 сейв пише порожні секції | ✅ лише відхилення (марки/піки — завжди, свідомо) |
| Б10 `SaveStore.list` ковтає | ✅ `listFaults` → `storageFault` |
| Б11 калібрування без `holdRepeat` | ✅ |
| Б12 презентація в `Game` | ✅ `FloatCue`; `energyInterval`/`secondsLabel` видалено |
| Косметика (цикл імпорту, кирилиця, застарілі коментарі, `_readInt`, material) | ✅ |
| Мертвий код (розділ 4) | ✅ усе, крім `setCraftHalted` (механіка з тестом) і `Stockpile.dispose` (гачок Перезапуску) |
| Прогалини тестів (розділ 6) | ◐ 10 нових сценаріїв; golden/widget-тести карток — відкладено |

Застосунок під час робіт не був запущений: потрібен повний `flutter run`.
