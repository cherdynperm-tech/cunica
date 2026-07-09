# cunica

![cunica](cunica.jpg)

[Unica](https://github.com/IngvarConsulting/unica) — плагин для Codex, который помогает работать с проектами 1С:Предприятие.

**Cunica** адаптирует обвязку Unica для [Cursor](https://cursor.com): скачивает release-пакет Unica локально, подключает MCP-сервер `unica` и skills в Cursor. Файлы Unica **не хранятся** в этом репозитории — только скрипты установки.

## Ключевые слова для поиска

`1с`, `1c`, `bsl`, `cursor`, `unica`

Проект предназначен для сценариев разработки 1С/1c на BSL в Cursor с использованием Unica.

## Совместимость с Unica

| | |
|---|---|
| Версия разработки и тестов | **[0.6.1](https://github.com/IngvarConsulting/unica/releases/tag/v0.6.1)** (`v0.6.1`) |
| Source of truth | `unica-contract.json` → `developmentVersion` |

Cunica разработан и проверен для этой версии Unica.

## Что нужно для работы

Установка и все команды cunica выполняются в среде **Windows**.

- Windows, [PowerShell](https://learn.microsoft.com/powershell/) 5.1+
- [Cursor](https://cursor.com)
- [Git](https://git-scm.com/) — для клонирования и обновления репозитория (не нужен при однострочной установке через `iwr`)
- Интернет — для первой установки и обновлений
- Платформа 1С — для операций с базами и конфигурациями (не нужна для установки cunica)

Не требуется: Codex CLI, Rust, Python.

## Быстрая установка

### Из репозитория

```powershell
git clone https://github.com/cherdynperm-tech/cunica.git
cd cunica
powershell -ExecutionPolicy Bypass -File .\scripts\install-cunica.ps1
```

### Одной командой

После публикации release на GitHub:

```powershell
iwr https://github.com/cherdynperm-tech/cunica/releases/latest/download/install-cunica.ps1 -OutFile install-cunica.ps1
powershell -ExecutionPolicy Bypass -File .\install-cunica.ps1
```

Релизы `cunica` формируются автоматически при пуше тега формата `v*`.
После успешной публикации релиза автоматически обновляется GitHub Pages:
`https://cherdynperm-tech.github.io/cunica/`.
Пошаговая инструкция для разработчика: `docs/memory-bank/commands-runbook.md` -> `Инструкция для разработчика (release publish)`.

## Установка через чат Cursor

Команда в чате:

```text
установи https://github.com/cherdynperm-tech/cunica
```

означает **установку Unica для работы с 1С в Cursor**, а не клонирование репозитория cunica в workspace.

Агент выполняет **один** вызов (без git):

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

Скрипт печатает машиночитаемый итог: `CUNICA_RESULT=...`, `CUNICA_PROJECT_INIT=...`, `CUNICA_LOG_PATH=...`.

Лог установки сохраняется в `~/.cunica/logs/install-*.log` (отключить: `-NoInstallLog` или `CUNICA_INSTALL_LOG=0`).

Если `CUNICA_PROJECT_INIT=needed` (обнаружен 1С-проект), агент **спрашивает** пользователя и при согласии запускает `cunica-init.ps1`.

Исключение для разработки cunica: если workspace уже содержит `scripts/install-cunica.ps1` и `unica-contract.json`, используйте локальный скрипт с `-AgentInstall`.

Если GitHub release недоступен из сети, используйте fallback:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-cunica.ps1 -ArchivePath C:\path\to\unica-codex-marketplace-win-x64.zip
```

## Подключение к 1С-проекту

После глобальной установки, из корня вашего 1С-репозитория:

```powershell
powershell -ExecutionPolicy Bypass -File $env:USERPROFILE\.cunica\installer\scripts\cunica-init.ps1
```

Создаётся:

- `.cursor/mcp.json` — MCP-сервер `unica`
- `.cursor/rules/1c-unica.mdc` — правила для задач 1С
- запись `v8project.local.yaml` в `.gitignore` (если файла ещё нет)

Перезапустите Cursor или выполните **Reload Window**, чтобы MCP подключился.

## Команды

| Команда | Описание |
|---------|----------|
| `install-cunica.ps1` | Установить последний релиз Unica |
| `install-cunica.ps1 -Version v0.6.1` | Установить конкретную версию |
| `install-cunica.ps1 -Update` | Обновить, если есть новый релиз |
| `install-cunica.ps1 -AgentUpdate` | Алиас для агентов Cursor: выполнить обновление Unica |
| `install-cunica.ps1 -Verify` | Проверить соответствие установленной Unica контракту cunica |
| `install-cunica.ps1 -Verify -StrictVersion` | Ошибка при несовпадении версии разработки и установленной версии |
| `install-cunica.ps1 -AgentInstall` | Алиас для агентов Cursor: установка/обновление Unica + verify + `CUNICA_RESULT=` |
| `install-cunica.ps1 -AgentInstall -Quiet` | То же, без verbose progress загрузки |
| `install-cunica.ps1 -NoInstallLog` | Установка без записи лога в `~/.cunica/logs/` |
| `install-cunica.ps1 -AgentCheck` | Алиас для агентов Cursor: строгая проверка версии/контракта перед планированием |
| `install-cunica.ps1 -Status` | Показать версию и доступность обновления |
| `install-cunica.ps1 -Uninstall` | Удалить локальную установку |
| `install-cunica.ps1 -ArchivePath C:\path\to\unica-codex-marketplace-win-x64.zip` | Установить из локального архива (если сеть блокирует GitHub) |

Для запуска используйте только `install-cunica.ps1`.

При установке Cunica автоматически добавляет глобальное правило Cursor
`~/.cursor/rules/1c-unica-version-check.mdc`, которое требует от агента проверять
версию/контракт Unica в начале планирования задач по 1С.

## Куда устанавливается

| Путь | Содержимое |
|------|------------|
| `~/.cunica/releases/{version}/` | Распакованный пакет Unica |
| `~/.cunica/current` | Ссылка на активную версию |
| `~/.cunica/installer/` | Кэш installer bundle (`cunica-installer.zip`) |
| `~/.cunica/logs/` | Логи сессий установки (`install-*.log`) |
| `~/.cunica/manifest.json` | Версия, платформа, дата установки, `installerPath`, `lastInstallLogPath` |
| `~/.cursor/mcp.json` | MCP-конфиг (добавляется сервер `unica`) |
| `~/.cursor/skills/unica-*` | Ссылки на skills Unica |

## Обновление Unica

Когда выходит новый релиз [Unica](https://github.com/IngvarConsulting/unica/releases):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-cunica.ps1 -Update
```

## Лицензия

- Скрипты cunica — [GPL-3.0](LICENSE)
- Runtime Unica — [LGPL-3.0-or-later](https://github.com/IngvarConsulting/unica/blob/main/LICENSE)
