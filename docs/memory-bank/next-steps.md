# Next Steps

## Высокий приоритет

- Добавить smoke-тесты PowerShell-скриптов:
  - `-Status`, `-Verify`, `-AgentCheck`, `-AgentUpdate`, `-Uninstall`.
- Прогнать end-to-end сценарий на тестовом проекте:
  - `C:\data\cunica\cunica-git`.
- Добавить release-скрипт/инструкцию для публикации `install-cunica.ps1` как GitHub release asset.

## Средний приоритет

- Улучшить диагностику сетевых ошибок скачивания (проксирование/таймауты/retry telemetry).
- Добавить явный check команды `unica --help` после `-Switch` на уже скачанную версию.
- Добавить короткий FAQ в README на частые ошибки контракта.

## Низкий приоритет

- Подготовить шаблон changelog для синхронизации `cunica` с новыми релизами Unica.
- Добавить автоматическую валидацию `unica-contract.json` в CI.

## Definition of Done для ближайшего релиза

- Все команды install/update/verify/init/uninstall отрабатывают локально на Windows.
- `-AgentCheck` корректно блокирует несовместимую версию.
- Глобальное правило `1c-unica-version-check.mdc` ставится и удаляется автоматически.
- Memory Bank обновлён и содержит актуальные ссылки/команды.
