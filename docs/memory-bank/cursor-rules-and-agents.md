# Cursor Rules and Agents

## Глобальное правило (для планирования 1С)

Файл: `~/.cursor/rules/1c-unica-version-check.mdc`  
Источник в репозитории: [`templates/1c-unica-version-check.mdc`](../../templates/1c-unica-version-check.mdc)

Устанавливается автоматически при:
- `install-cunica.ps1`
- переключении на уже скачанную версию через `-Version`/`-Update`

## Проектное правило

Файл в 1С-проекте: `.cursor/rules/1c-unica.mdc`  
Источник в репозитории: [`templates/1c-unica.mdc`](../../templates/1c-unica.mdc)

Добавляется командой:
- `scripts/cunica-init.ps1`

## Обязанности агента в 1С-проектах

Перед стартом планирования:

1. Выполнить строгую проверку:
   - `install-cunica.ps1 -AgentCheck`
2. Если проверка не прошла:
   - остановить планирование;
   - попросить пользователя обновить/установить Unica:
     - `install-cunica.ps1 -AgentUpdate` или `-Update`.

## Интерпретация результатов

- `Contract OK ...` -> можно планировать/выполнять задачи.
- `WARNING ... version mismatch` (не strict) -> допускается только с явным подтверждением пользователя.
- Ошибки отсутствующих файлов/skills/bin -> блокер, нужен fix версии/контракта.
