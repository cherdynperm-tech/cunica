# Commands Runbook

## Среда выполнения

Установка, инициализация и все команды cunica выполняются в среде **Windows** (PowerShell 5.1+).

Требования:

- Windows, PowerShell 5.1+
- Cursor
- Git — для клонирования и обновления репозитория (не нужен при однострочной установке через `iwr`)
- Интернет — для первой установки и обновлений
- Платформа 1С — для операций с базами и конфигурациями (не нужна для установки cunica)

Не требуется: Codex CLI, Rust, Python.

## Базовые команды (Windows, PowerShell)

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

## Публикация релиза GitHub

- Релиз `cunica` формируется автоматически GitHub Actions workflow
  `.github/workflows/release.yml` при пуше тега формата `v*`.
- В релиз публикуется asset `install-cunica.ps1` (берется из `scripts/install-cunica.ps1`).
- В релиз публикуется asset `cunica-installer.zip` (scripts, contract, templates для chat-install без git).
- После успешного release-run обновляется GitHub Pages workflow
  `.github/workflows/pages.yml` и публикуется страница:
  `https://cherdynperm-tech.github.io/cunica/`.
- Источник контента для страницы: `docs/site/index.html`,
  итоговый deploy artifact: `pages/index.html`.

Проверка публикации:

```powershell
git tag v0.0.0-test
git push origin v0.0.0-test
```

- Убедиться, что в GitHub появился Release для тега `v0.0.0-test`.
- Убедиться, что среди assets есть `install-cunica.ps1`.
- Убедиться, что GitHub Pages обновился и отображает новый тег/дату/ссылку на asset.

### Инструкция для разработчика (release publish)

1. Убедиться, что локальная ветка `develop` актуальна и рабочее дерево чистое.
2. Проверить, что изменения для релиза уже в удаленном репозитории.
3. Создать тег релиза в формате `vX.Y.Z`:

```powershell
git tag v0.6.2
git push origin v0.6.2
```

4. Проверить в GitHub:
   - workflow `Release` завершился успешно;
   - создан GitHub Release с asset `install-cunica.ps1`;
   - workflow `Pages` завершился успешно;
   - страница `https://cherdynperm-tech.github.io/cunica/` обновилась.

5. Если релиз не появился:
   - проверить, что тег начинается с `v`;
   - проверить логи `.github/workflows/release.yml` и `.github/workflows/pages.yml`;
   - при необходимости удалить ошибочный тег и выпустить новый корректный тег.

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

Intent: установить **Unica для 1С в Cursor**, не клонировать репозиторий cunica.

Ожидаемое поведение агента (без git):

```powershell
$installer = Join-Path $env:USERPROFILE '.cunica\installer\scripts\install-cunica.ps1'
if (-not (Test-Path -LiteralPath $installer)) {
  $zip = Join-Path $env:TEMP 'cunica-installer.zip'
  $dest = Join-Path $env:USERPROFILE '.cunica\installer'
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Invoke-WebRequest 'https://github.com/cherdynperm-tech/cunica/releases/latest/download/cunica-installer.zip' -OutFile $zip -UseBasicParsing
  Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
  Remove-Item -LiteralPath $zip -Force
}
powershell -NoProfile -ExecutionPolicy Bypass -File $installer -AgentInstall -Quiet -ProjectDir (Get-Location).Path
```

Парсить `CUNICA_RESULT=`, `CUNICA_PROJECT_INIT=` и `CUNICA_LOG_PATH=`. Если `needed` — спросить пользователя и запустить `cunica-init.ps1`.

Логи: `~/.cunica/logs/install-*.log` (отключить `-NoInstallLog` или `CUNICA_INSTALL_LOG=0`).

Dev-mode: если workspace — checkout cunica (`scripts/install-cunica.ps1` + `unica-contract.json`), использовать локальный `-AgentInstall`.

Fallback для сетевых ограничений:

- `install-cunica.ps1 -ArchivePath C:\path\to\unica-codex-marketplace-win-x64.zip`
- ручной `cunica-installer.zip` в `%USERPROFILE%\.cunica\installer`

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

PowerShell scripts (`.ps1`/`.psm1`) must use **English only** for comments and user-facing messages; localized docs stay in `README.md` and `docs/`.

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
