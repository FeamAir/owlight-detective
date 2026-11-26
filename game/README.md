# Игра: срез 01 (Godot 4.7, GDScript)

Первая локация «Ворота, сторожка, аллея и мостки» по `docs/levels/slice-01-spec.md`.
Движок — Godot 4.7.2, рендерер Compatibility (OpenGL ES 3), горизонтальный экран, Android (APK).

## Собрать APK одной командой

```bash
game/tools/build_apk.sh               # данные → заглушки → импорт → тесты → экспорт → проверка подписи
game/tools/build_apk.sh --skip-tests  # быстрее
game/tools/build_apk.sh --force-art   # перегенерировать картинки-заглушки
```

Результат: `builds/owlight-slice01-debug.apk` (папка `builds/` в git не попадает).
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
- `tests/run_tests.gd` — модульные тесты GDScript (headless): математика панорамы, кодовый замок и реакции
  по уровням, прогрессия и зоны, конец среза, сохранение/загрузка, «Мысли» (сразу / ожидание / нет).
- `tests/smoke_ui.gd` — сквозной прогон настоящих экранов: меню → сложность → пролог → диалог у ворот →
  панорама → столбы → замок (ошибка и решение) → сторожка → ящик → «Мысли» → блокнот → сумка → фонтан →
  парадная → экран конца → сохранение.
  Со скриншотами (нужны Xvfb и Mesa):
  `xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 1600x720 -s res://tests/smoke_ui.gd -- --shots=/abs/dir`

## Устройство

```
game/
  data/            контент в YAML (правят сценарист и левел-дизайнер) — формат spec 8, см. data/README.md
  content/         game_data.json — генерируется из data/ (в git не попадает)
  assets/placeholder/  заглушки (генерируются, в git не попадают); настоящая графика → assets/<вид>/<имя>.png|webp|jpg
  scripts/core/    чистая логика без сцен: данные, состояние/сохранение, зоны, замок T01, «Мысли», математика 360°
  scripts/ui/      экраны: панорама, диалог, крупный план, сумка, блокнот, меню, пролог, конец среза
  scripts/puzzles/ экраны головоломок (T01 сделан; остальные — заглушки с кнопкой отладки)
  tests/           тесты
  tools/           build_apk.sh, run_tests.sh, data_build.py, gen_placeholders.py, sync_lines_from_spec.py
```

- **Панорама 360°**: эквидистантная развёртка 2:1, рисуется шейдером (`scripts/core/panorama.gdshader`) по той же
  математике, что `PanoMath` (покрыта тестами). Центр картинки = yaw 0°, yaw растёт вправо; наклон ±40°.
- **Слой деталей**: знаки, уровни воды, цифры шкал, отметки лент рисует движок поверх фона по значениям
  `values/<профиль>.yaml` и уровню сложности. Фон-картинка их не содержит — настоящие фоны можно подменять,
  не трогая логику (решение владельца №18).
- **Тексты**: канон реплик — разделы 4 и 7.3 спецификации; в данные их переносит
  `python3 game/tools/sync_lines_from_spec.py`. У каждой реплики ID, RU, EN и пустые `audio_ru/audio_en` (решение №11).
- **Отладка (сборка владельца = debug-APK)**: главное меню → «Отладка»: контуры зон + yaw/pitch по тапу,
  ускорение ожидания «Мыслей» (5 мин → 10 с), «начать с точки» на любом уровне, протокол прохождения.
