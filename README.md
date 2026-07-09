# cunica

![cunica](cunica.jpg)

[Unica](https://github.com/IngvarConsulting/unica) — плагин для Codex, который помогает работать с проектами 1С:Предприятие.

**Cunica** адаптирует обвязку Unica для [Cursor](https://cursor.com): скачивает release-пакет Unica локально, подключает MCP-сервер `unica` и skills в Cursor. Файлы Unica **не хранятся** в этом репозитории — только скрипты установки.

## Совместимость с Unica

| | |
|---|---|
| Версия разработки и тестов | **[0.6.1](https://github.com/IngvarConsulting/unica/releases/tag/v0.6.1)** (`v0.6.1`) |
| Контракт cunica | `unica-contract.json` → `developmentVersion` |

Cunica разработан и проверен для этой версии Unica. При выходе нового релиза Unica обновите контракт, выполните проверки и обновите номер версии в этом разделе.

## Быстрая установка

### Windows (PowerShell 5.1+)

```powershell
git clone https://github.com/cherdynperm-tech/cunica.git
cd cunica
powershell -ExecutionPolicy Bypass -File .\scripts\install-cunica.ps1
```

Или одной командой (после публикации release):

```powershell
iwr https://github.com/cherdynperm-tech/cunica/releases/latest/download/install-cunica.ps1 -OutFile install-cunica.ps1
powershell -ExecutionPolicy Bypass -File .\install-cunica.ps1
```

### PowerShell-only режим

Поддерживаемый путь — только PowerShell:

```powershell
git clone https://github.com/cherdynperm-tech/cunica.git
cd cunica
powershell -ExecutionPolicy Bypass -File .\scripts\install-cunica.ps1
```

## Подключение к 1С-проекту

После глобальной установки, из корня вашего 1С-репозитория:

```powershell
powershell -ExecutionPolicy Bypass -File C:\path\to\cunica\scripts\cunica-init.ps1
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
| `install-cunica.ps1 -AgentCheck` | Алиас для агентов Cursor: строгая проверка версии/контракта перед планированием |
| `install-cunica.ps1 -Status` | Показать версию и доступность обновления |
| `install-cunica.ps1 -Uninstall` | Удалить локальную установку |
| `install-cunica.ps1 -ArchivePath C:\path\to\unica-codex-marketplace-win-x64.zip` | Установить из локального архива (если сеть блокирует GitHub) |

Для запуска используйте только `install-cunica.ps1`.

При установке Cunica автоматически добавляет глобальное правило Cursor
`~/.cursor/rules/1c-unica-version-check.mdc`, которое требует от агента проверять
версию/контракт Unica в начале планирования задач по 1С.

## PowerShell quality standard

В проект добавлены guidance-артефакты для качественных PowerShell-скриптов:

- project rule: `.cursor/rules/powershell-quality.mdc`
- project skill: `.cursor/skills/powershell-quality/SKILL.md`
- global rule: `~/.cursor/rules/powershell-quality.mdc`
- global skill: `~/.cursor/skills/powershell-quality/SKILL.md`

Базовые проверки после изменения `.ps1`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-powershell-quality.ps1
```

CI workflow: `.github/workflows/powershell-quality.yml`.

## Куда устанавливается

| Путь | Содержимое |
|------|------------|
| `~/.cunica/releases/{version}/` | Распакованный пакет Unica |
| `~/.cunica/current` | Ссылка на активную версию |
| `~/.cunica/manifest.json` | Версия, платформа, дата установки |
| `~/.cursor/mcp.json` | MCP-конфиг (добавляется сервер `unica`) |
| `~/.cursor/skills/unica-*` | Ссылки на skills Unica |

## Что нужно для работы

- [Cursor](https://cursor.com)
- Для операций с базами и конфигурациями — установленная платформа 1С
- Интернет для первой установки и обновлений

Не требуется: Codex CLI, Rust, Python.

## Обновление Unica

Когда выходит новый релиз [Unica](https://github.com/IngvarConsulting/unica/releases):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-cunica.ps1 -Update
```

## Лицензия

- Скрипты cunica — [GPL-3.0](LICENSE)
- Runtime Unica — [LGPL-3.0-or-later](https://github.com/IngvarConsulting/unica/blob/main/LICENSE)
