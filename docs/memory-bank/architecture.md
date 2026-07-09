# Architecture

## Компоненты

- `scripts/install-cunica.ps1` — точка входа установки/обновления/проверок.
- `scripts/cunica-init.ps1` — проектная инициализация в 1С-репозитории.
- `scripts/lib/cunica-common.ps1` — общая логика (download, contract checks, mcp merge, skills links).
- `unica-contract.json` — контракт целевой версии и обязательной структуры Unica.
- `templates/1c-unica.mdc` — проектное правило для 1С-задач.
- `templates/1c-unica-version-check.mdc` — глобальный planning gate для агентов.

## Локальные директории

- `~/.cunica/releases/{version}` — распакованные версии Unica.
- `~/.cunica/current` — активная версия Unica (link).
- `~/.cunica/manifest.json` — установленная версия, target, путь и метаданные контракта.
- `~/.cursor/mcp.json` — MCP-сервер `unica`.
- `~/.cursor/skills/unica-*` — ссылки на skills из активной версии.
- `~/.cursor/rules/1c-unica-version-check.mdc` — глобальное правило для planning-проверки.

## Поток выполнения

1. `install-cunica.ps1` определяет target (`win-x64`, `darwin-arm64`, `linux-x64`).
2. Скачивает (или берёт локальный архив), распаковывает release.
3. Проверяет контракт и версию через `Assert-UnicaContract`.
4. Обновляет `~/.cunica/current`, `manifest.json`, `~/.cursor/mcp.json`, skills и глобальное правило.
5. `cunica-init.ps1` на уровне проекта добавляет `.cursor/mcp.json` и `.cursor/rules/1c-unica.mdc`.

## Критические stop-rules

- Нет `unica-contract.json` -> немедленная ошибка.
- Нет обязательного файла/директории/bin/skill из контракта -> ошибка.
- `-Verify -StrictVersion` и несовпадение версии -> ошибка.
- Нет установленной Unica при `-Verify`/`cunica-init.ps1` -> ошибка.
