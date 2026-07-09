# Commands Runbook

## Базовые команды (PowerShell)

Из корня репозитория `cunica`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-cunica.ps1
```

## Установка и обновление

- Установить latest:
  - `install-cunica.ps1`
- Установить конкретную версию:
  - `install-cunica.ps1 -Version v0.6.1`
- Установить из локального архива:
  - `install-cunica.ps1 -ArchivePath C:\path\to\unica-codex-marketplace-win-x64.zip`
- Обновить до latest:
  - `install-cunica.ps1 -Update`
- Алиас для агентов:
  - `install-cunica.ps1 -AgentUpdate`

## Проверки и диагностика

- Статус:
  - `install-cunica.ps1 -Status`
- Проверка контракта/структуры:
  - `install-cunica.ps1 -Verify`
- Строгая проверка версии:
  - `install-cunica.ps1 -Verify -StrictVersion`
- Алиас для агентов (строгая проверка по умолчанию):
  - `install-cunica.ps1 -AgentCheck`
- Печать URL release-архива:
  - `install-cunica.ps1 -PrintDownloadUrl`

## Инициализация 1С-проекта

- В целевом репозитории 1С:
  - `powershell -ExecutionPolicy Bypass -File C:\path\to\cunica\scripts\cunica-init.ps1 -ProjectDir <path-to-1c-project>`

## Cursor chat install flow

Фраза в чате Cursor:

- `установи https://github.com/cherdynperm-tech/cunica`

Ожидаемое поведение агента:

1. Проверить, есть ли локальный репозиторий `cunica`.
2. Если есть — обновить (`git pull`), если нет — клонировать.
3. Выполнить:
   - `powershell -ExecutionPolicy Bypass -File .\scripts\install-cunica.ps1`
4. Проверить результат:
   - `powershell -ExecutionPolicy Bypass -File .\scripts\install-cunica.ps1 -Verify`
5. Вернуть явный статус: installed / updated / already installed / blocked.

Fallback для сетевых ограничений:

- `install-cunica.ps1 -ArchivePath C:\path\to\unica-codex-marketplace-win-x64.zip`

## Удаление

- Полный uninstall:
  - `install-cunica.ps1 -Uninstall`

Удаляет:
- локальный `~/.cunica`
- `unica` из `~/.cursor/mcp.json`
- `~/.cursor/skills/unica-*`
- `~/.cursor/rules/1c-unica-version-check.mdc`

## Troubleshooting

- **`Unica is not installed.`**
  - сначала выполнить `install-cunica.ps1`.
- **`Missing unica-contract.json`**
  - запускать из репозитория `cunica` или задать `CUNICA_CONTRACT_PATH`.
- **`Missing required Unica ...`**
  - структура архива не совпала с контрактом; обновить версию или контракт.
- **Сбой загрузки с GitHub**
  - скачать архив вручную и использовать `-ArchivePath`.

## PowerShell quality checks

Применяется для любых изменений `.ps1`/`.psm1`:

- Rule (project): `.cursor/rules/powershell-quality.mdc`
- Skill (project): `.cursor/skills/powershell-quality/SKILL.md`
- Rule (global): `~/.cursor/rules/powershell-quality.mdc`
- Skill (global): `~/.cursor/skills/powershell-quality/SKILL.md`

Минимальный чеклист (одной командой):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-powershell-quality.ps1
```

CI: `.github/workflows/powershell-quality.yml` (запускается при изменениях в `scripts/`).

Ручные проверки (если нужны по отдельности):

- syntax check:
  - `powershell -NoProfile -Command "[ScriptBlock]::Create((Get-Content '<file>' -Raw)) | Out-Null"`
- smoke checks:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\install-cunica.ps1 -Status`
  - `powershell -ExecutionPolicy Bypass -File .\scripts\install-cunica.ps1 -PrintDownloadUrl`
  - `powershell -ExecutionPolicy Bypass -File .\scripts\install-cunica.ps1 -Verify` (ожидаемо падает без install)
- optional:
  - `.\scripts\test-powershell-quality.ps1 -RequireScriptAnalyzer` (если установлен PSScriptAnalyzer)
