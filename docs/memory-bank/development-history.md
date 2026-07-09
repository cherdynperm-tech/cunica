# Development History

## Инициализация проекта

- Репозиторий стартовал как минимальный scaffold (`README`, `LICENSE`, изображение).

## Базовая интеграция Unica -> Cursor

- Добавлены PowerShell-скрипты:
  - `scripts/install-cunica.ps1`
  - `scripts/cunica-init.ps1`
  - `scripts/lib/cunica-common.ps1`
- Реализованы:
  - установка в `~/.cunica`
  - MCP merge в `~/.cursor/mcp.json`
  - links skills в `~/.cursor/skills/unica-*`

## Контракт и контроль архитектуры Unica

- Добавлен `unica-contract.json` как источник целевой версии и обязательной структуры.
- Введены проверки:
  - `Assert-UnicaContract`
  - `Verify-InstalledUnicaContract`
- Поведение:
  - warning при version mismatch;
  - error при strict mismatch и при отсутствии обязательных файлов.

## Агентские сценарии

- Добавлены алиасы:
  - `-AgentCheck` (строгая проверка)
  - `-AgentUpdate` (обновление)
- Добавлено глобальное правило Cursor:
  - `templates/1c-unica-version-check.mdc`

## Переход на PowerShell-only

- Убрана зависимость от Python из рабочего пути.
- Удалены shell-скрипты (`*.sh`).
