# Игра: срез 01 (Godot 4.7, GDScript)

Первая локация «Ворота, сторожка, аллея и мостки» по `docs/levels/slice-01-spec.md`.
Движок — Godot 4.7.2, рендерер Compatibility (OpenGL ES 3), горизонтальный экран, Android (APK).

## Собрать APK одной командой

```bash
game/tools/build_apk.sh               # данные → заглушки → импорт → тесты → экспорт → проверка подписи
game/tools/build_apk.sh --skip-tests  # быстрее
game/tools/build_apk.sh --force-art   # перегенерировать картинки-заглушки
game/tools/build_apk.sh --armv7       # ещё отдельный APK для старых 32-битных телефонов (armeabi-v7a)
```

Результат: `builds/owlight-slice01-debug.apk` (arm64-v8a, ~29 МБ; папка `builds/` в git не попадает).
С `--armv7` — ещё `builds/owlight-slice01-debug-armv7.apk` (~33 МБ) для старых телефонов. Отдельным файлом, потому что
библиотека движка для armeabi-v7a добавляет ~32 МБ (debug) / ~26 МБ (release): общий APK вырос бы до ~61 МБ.
В Google Play (AAB) архитектуры и так раздаются раздельно.
Установка на телефон: `adb install -r builds/owlight-slice01-debug.apk` или скопировать файл на телефон
и открыть (разрешить установку из этого источника).

## Что нужно на машине сборки (ставится вне репозитория)

| Что | Версия | Где по умолчанию | Переменная |
|---|---|---|---|
| Godot (editor, Linux x86_64) | 4.7.2-stable | `godot` в `PATH` | `GODOT` |
| Export templates | 4.7.2 | `~/.local/share/godot/export_templates/4.7.2.stable/` | — |
| Android SDK | cmdline-tools, platform-tools, build-tools 36.1.0, platforms;android-36 | `/opt/android-sdk` | `ANDROID_HOME` |
| JDK | 17 (требование шаблона Godot 4.7: `javaVersion 17`) | `/usr/lib/jvm/java-17-openjdk-amd64` | `JAVA_HOME` |
| Python | 3.10+ с PyYAML и Pillow | `python3` | — |
| Для перерендера панорам (необязательно) | xvfb + Mesa (OpenGL 3.3), Python numpy | `xvfb-run` | — |
| Debug keystore | создаётся скриптом при первом запуске | `~/.android/debug.keystore` | `DEBUG_KEYSTORE` |

Установка с нуля (Linux):
```bash
# Godot + шаблоны (github releases)
B=https://github.com/godotengine/godot/releases/download/4.7.2-stable
curl -LO $B/Godot_v4.7.2-stable_linux.x86_64.zip && unzip Godot_v4.7.2-stable_linux.x86_64.zip -d /opt/godot
curl -LO $B/Godot_v4.7.2-stable_export_templates.tpz
mkdir -p ~/.local/share/godot/export_templates/4.7.2.stable && unzip -j Godot_v4.7.2-stable_export_templates.tpz 'templates/*' -d ~/.local/share/godot/export_templates/4.7.2.stable
# Android SDK
curl -LO https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip
mkdir -p /opt/android-sdk/cmdline-tools && unzip commandlinetools-linux-*_latest.zip -d /tmp/ct && mv /tmp/ct/cmdline-tools /opt/android-sdk/cmdline-tools/latest
yes | /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=/opt/android-sdk --licenses
/opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=/opt/android-sdk "platform-tools" "build-tools;36.1.0" "platforms;android-36"
# JDK 17
sudo apt-get install -y openjdk-17-jdk-headless
```

Ключи: в репозиторий не кладутся ни keystore, ни пароли (`.gitignore`: `*.keystore`, `*.jks`, `/builds/`).
Debug-APK подписан стандартным локальным debug-ключом. Релизная подпись (upload key, Play App Signing) — отдельно, у владельца.

## Тесты

```bash
game/tools/run_tests.sh
```
- `tools/data_build.py` — проверка данных: ссылки на реплики/зоны/предметы, граф прогрессии без тупиков
  (перебор всех порядков решения), уникальность кодов, ограничения значений `GATE-01`.
- `tools/data_build.py` проверяет и головоломки: GATE-03 — отправление + в пути = целевое время на каждом уровне,
  шаблон LOGIC-GATE-03 на Н даёт канонический текст; PIER-01 — у каждой цели есть зона ≥ 48 dp
  (`data/puzzles/layouts.yaml`), правила реакций известны; ALLEY-01 — две свежие цепочки в разные стороны;
  GATE-02 — ответ ссылается на существующие фрагменты, а тексты фрагментов дословно есть в документах уровня.
- `tests/run_tests.gd` — модульные тесты GDScript (headless): математика панорамы, кодовый замок и реакции
  по уровням, прогрессия и зоны, конец среза, сохранение/загрузка, «Мысли» (сразу / ожидание / нет);
  `tests/test_puzzles.gd` — проверка ответов, классификация ошибок и реакции по уровням для GATE-03, PIER-01,
  ALLEY-01, GATE-02, параметры показа логики, вмещаемость текста логики в карточку.
- `tests/smoke_ui.gd` — сквозной прогон настоящих экранов без отладочных кнопок: меню → сложность → пролог →
  диалог у ворот → панорама → столбы → замок GATE-01 (ошибка и решение) → сторожка → ящик GATE-03 (ошибка и
  решение) → «Мысли» → блокнот → сумка → мостки PIER-01 → гравий ALLEY-01 → лента GATE-02 → «Решённое» →
  фонтан → парадная → экран конца (5 из 5) → сохранение; затем на Л и С каждая новая головоломка с типичной ошибкой.
  Со скриншотами (нужны Xvfb и Mesa):
  `xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 1600x720 -s res://tests/smoke_ui.gd -- --shots=/abs/dir`

## Устройство

```
game/
  data/            контент в YAML (правят сценарист и левел-дизайнер) — формат spec 8, см. data/README.md
  content/         game_data.json — генерируется из data/ (в git не попадает)
  assets/placeholder/  заглушки (генерируются, в git не попадают); настоящая графика → assets/<вид>/<имя>.png|webp|jpg
  data/puzzles/layouts.yaml  зоны касания сцены поиска PIER-01 (правит левел-дизайнер)
  scripts/core/    чистая логика без сцен: данные, состояние/сохранение, зоны, «Мысли», математика 360°,
                   головоломки (code_lock, clock_lock, search, tracks, compare) и реакции по уровням (puzzle_rules)
  scripts/ui/      экраны: панорама, диалог, крупный план, сумка, блокнот, меню, пролог, конец среза
  scripts/puzzles/ экраны головоломок: T01 замок, T19 часовой замок, T08 поиск, T16 следы, T15 сравнение
                   (общая основа puzzle_screen.gd: карточка реакции/логики подгоняет шрифт под экран)
  tests/           тесты
  tools/           build_apk.sh, run_tests.sh, data_build.py, gen_placeholders.py, sync_lines_from_spec.py,
                   render_panos.sh + pano_bake.py (панорамы, карта и углы из 3D-макета)
  art_src/         3D-макет зоны и скрипт рендера (не входит в APK)
  assets/pano, assets/map  панорамы и карта, отрендеренные из макета (закоммичены)
```

- **Черновая графика пространства — 3D-макет** `art_src/slice01_blockout.tscn` (скрипт `art_src/blockout.gd`, в APK не
  входит): дорога, ограда, 4 столба с медальонами, ворота, сторожка (снаружи и внутри), аллея, фонтан с совой, кадка, дом
  с башней и террасой, калитка, тропа к озеру, мостки, сарай, озеро, холмы; пасмурное утро, туман, тени. Простые формы
  без деталей — до настоящих картинок художника.
  `tools/render_panos.sh` (Godot под xvfb + Mesa, ~1,5 мин) рендерит из макета:
  панорамы `assets/pano/pan_*.jpg` (кубическая карта 6×2048 → equirect 4096×2048, JPEG ~200 КБ, в APK — WebP ~100 КБ),
  карту зоны `assets/map/map_grounds.jpg` (вид сверху) и `data/world/pano_anchors.yaml` — yaw/pitch/size_deg каждой
  зоны, медальона, ходиков и метки перехода, посчитанные из 3D-позиций (+ проверка лучом, что объект не загорожен).
  Затем переписывает эти углы в `world/hotspots.yaml` и `world/viewpoints.yaml`; `data_build.py` падает, если их
  поправили руками и они разошлись с панорамой. Результаты рендера закоммичены (сборке GPU не нужен);
  `build_apk.sh` перерендеривает их, только если менялся `art_src/` (`--if-stale`).
- **Навигация**: метки переходов — крупные, со значком (шаги / дверь / замок) и подписью «куда» (`label_key` у перехода),
  пульсируют, когда впервые появляются на экране, и мягко светятся, пока место не посещено; подпись места при входе;
  кнопка «Карта» (внизу слева) и вкладка «Карта» в блокноте: точки обзора, «вы здесь» с направлением взгляда, тропы
  между точками, непосещённые — «?»; тап по посещённой точке — сразу переход. Между фонтаном и мостками добавлена
  точка VP-PATH-1 «Тропа к озеру» (с развилки мостки скрыты склоном — библия 6.2). При переходе направление взгляда
  сохраняется в мировых координатах (у каждой точки свой `heading`).
- **Панорама 360°**: эквидистантная развёртка 2:1, рисуется шейдером (`scripts/core/panorama.gdshader`) по той же
  математике, что `PanoMath` (покрыта тестами). Центр картинки = yaw 0°, yaw растёт вправо; наклон ±40°.
- **Слой деталей**: знаки, уровни воды, цифры шкал, отметки лент рисует движок поверх фона по значениям
  `values/<профиль>.yaml` и уровню сложности. Фон-картинка их не содержит — настоящие фоны можно подменять,
  не трогая логику (решение владельца №18).
- **Тексты**: канон реплик — разделы 4 и 7.3 спецификации; в данные их переносит
  `python3 game/tools/sync_lines_from_spec.py`. У каждой реплики ID, RU, EN и пустые `audio_ru/audio_en` (решение №11).
- **Отладка (сборка владельца = debug-APK)**: главное меню → «Отладка»: контуры зон + yaw/pitch по тапу,
  ускорение ожидания «Мыслей» (5 мин → 10 с), «начать с точки» на любом уровне, протокол прохождения.
