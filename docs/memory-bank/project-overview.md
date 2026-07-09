# Project Overview

## Что такое Cunica

`cunica` адаптирует обвязку [Unica](https://github.com/IngvarConsulting/unica) для использования в Cursor.

Главная цель: дать агентам Cursor воспроизводимый рабочий контур для 1С-проектов через локальную установку Unica, MCP `unica`, skills и правила.

## Scope

- Установка Unica из GitHub Releases в локальный кэш пользователя.
- Подключение `unica` MCP в Cursor.
- Подключение skills Unica в Cursor.
- Валидация архитектурного контракта и версии Unica.
- Инициализация конкретного 1С-репозитория (`.cursor/mcp.json`, `.cursor/rules`).

## Non-goals

- Хранение бинарников/skills Unica в репозитории `cunica`.
- Замена самого проекта Unica.
- Управление лицензией 1С или автоматический обход лицензионных проблем.

## Основные ограничения

- Режим выполнения: **PowerShell-only**.
- Источник пакетов: GitHub Releases `IngvarConsulting/unica`.
- При несовпадении структуры или отсутствующих файлах Unica выполнение останавливается ошибкой (через контракт).
