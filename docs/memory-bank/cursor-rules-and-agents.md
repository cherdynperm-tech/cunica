# Cursor Rules and Agents

## Chat install (Unica for 1C, not cunica repo clone)

Rule: [`.cursor/rules/cunica-auto-install.mdc`](../../.cursor/rules/cunica-auto-install.mdc)

- Trigger: `установи https://github.com/cherdynperm-tech/cunica`
- Intent: install Unica runtime for 1C in Cursor
- Flow: one `-AgentInstall` call, no git
- Installer cache: `%USERPROFILE%\.cunica\installer\` (from `cunica-installer.zip` release asset)
- Machine-readable result: `CUNICA_RESULT=`, `CUNICA_PROJECT_INIT=`, `CUNICA_LOG_PATH=`
- Install logs: `%USERPROFILE%\.cunica\logs\install-*.log`
- If `CUNICA_PROJECT_INIT=needed`, ask user before `cunica-init.ps1`

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
- `%USERPROFILE%\.cunica\installer\scripts\cunica-init.ps1`

## Обязанности агента в 1С-проектах

Перед стартом планирования:

1. Выполнить строгую проверку:
   - `%USERPROFILE%\.cunica\installer\scripts\install-cunica.ps1 -AgentCheck`
2. Если проверка не прошла:
   - остановить планирование;
   - попросить пользователя обновить/установить Unica:
     - `-AgentInstall` (chat install) или `-AgentUpdate`.

## Интерпретация результатов

- `Contract OK ...` -> можно планировать/выполнять задачи.
- `CUNICA_RESULT=installed|updated|already_installed` -> глобальная установка OK.
- `CUNICA_PROJECT_INIT=needed` -> спросить про `cunica-init.ps1`.
- `WARNING ... version mismatch` (не strict) -> допускается только с явным подтверждением пользователя.
- Ошибки отсутствующих файлов/skills/bin -> блокер, нужен fix версии/контракта.
