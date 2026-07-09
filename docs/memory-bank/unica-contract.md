# Unica Contract

Источник: [`unica-contract.json`](../../unica-contract.json).

## Назначение

Контракт фиксирует версию Unica, для которой ведётся разработка `cunica`, и список обязательных элементов структуры, без которых интеграция считается невалидной.

## Текущая целевая версия

- `developmentVersion`: `0.6.1`
- `developmentReleaseTag`: `v0.6.1`

## Что проверяется

- Маркер marketplace:
  - `.agents/plugins/marketplace.json`
- Обязательные файлы плагина:
  - `.codex-plugin/plugin.json`
  - `third-party/manifest.json`
  - `third-party/tools.lock.json`
- Обязательные директории:
  - `skills`
  - `bin`
  - `references`
- Обязательные бинарники:
  - `unica`, `v8-runner`, `bsl-analyzer`, `rlm-tools-bsl`, `rlm-bsl-index`
- Обязательные skills:
  - полный список в `requiredSkills` (должны существовать `skills/<name>/SKILL.md`)

## Поведение при несовпадении версии

- Обычная проверка (`-Verify`) -> warning.
- Строгая проверка (`-Verify -StrictVersion` или `-AgentCheck`) -> ошибка.

## Когда обновлять контракт

Обновлять `unica-contract.json`, если:

- целевая версия Unica меняется;
- меняется структура marketplace/plugin;
- появляются/пропадают обязательные бинарники или skills;
- меняется критичный путь для запуска MCP runtime.
