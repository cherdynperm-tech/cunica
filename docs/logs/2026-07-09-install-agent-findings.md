# Ключевые находки: установка через Cursor Agent

**Дата:** 2026-07-09  
**Сессия:** `e9d19ffc-6e4f-4d49-aa41-e8d0ca928a74`  
**Команда пользователя:** `установи https://github.com/cherdynperm-tech/cunica`  
**Итог (до оптимизации):** `installed` (Unica 0.6.1, win-x64, Contract OK)  
**Полный лог:** [2026-07-09-cursor-agent-install-session.md](./2026-07-09-cursor-agent-install-session.md)

---

## Контекст

| Параметр | Значение |
|----------|----------|
| Workspace Cursor | `C:\data\cunica\cunica-git` (1С-проект, не репозиторий cunica) |
| Путь клона (факт, до оптимизации) | `C:\data\cunica\cunica` (выбран агентом, не задокументирован) |
| Общее время агента | ~60 с (~53 с — загрузка Unica 70 MB) |

---

## Находки и статус

| # | Находка | Статус после оптимизации |
|---|---------|--------------------------|
| 1 | Workspace ≠ репозиторий cunica; лишние tool calls | Rule: intent «Unica для 1С», один `-AgentInstall`, без git/glob |
| 2 | Путь клона не детерминирован | `%USERPROFILE%\.cunica\installer\` (+ `CUNICA_INSTALLER_PATH`) |
| 3 | `&&` ломает PowerShell 5.1 | Запрет `&&` в `cunica-auto-install.mdc` |
| 4 | Нет машиночитаемого итога | `CUNICA_RESULT=`, `CUNICA_VERSION=`, `CUNICA_TARGET=`, `CUNICA_LOG_PATH=` |
| 5 | Verbose curl progress | `-Quiet` / quiet download |
| 6 | `cunica-init` не в сценарии | `CUNICA_PROJECT_INIT=needed` + вопрос пользователю |
| 7 | Агент не использует `-AgentCheck` | verify встроен в `-AgentInstall`; templates → `-AgentCheck` |

---

## Метрики

| Метрика | Факт (до) | Цель |
|---------|-----------|------|
| Время до первой ошибки | 426 ms | 0 |
| Tool calls до установки | 3 | 1 |
| Время загрузки Unica | 53.5 s | сеть |
| Время verify | 2.1 s | < 5 s (внутри `-AgentInstall`) |

---

## Целевой сценарий агента (после оптимизации)

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

При `CUNICA_PROJECT_INIT=needed` — спросить пользователя и запустить `cunica-init.ps1`.

---

## Baseline до оптимизации (git clone)

```powershell
$repo = if ($env:CUNICA_REPO_PATH) { $env:CUNICA_REPO_PATH } else { "$env:USERPROFILE\.cunica\repo" }
if (-not (Test-Path "$repo\scripts\install-cunica.ps1")) {
    New-Item -ItemType Directory -Force -Path (Split-Path $repo) | Out-Null
    git clone https://github.com/cherdynperm-tech/cunica.git $repo
} else {
    git -C $repo pull
}
powershell -ExecutionPolicy Bypass -File "$repo\scripts\install-cunica.ps1"
powershell -ExecutionPolicy Bypass -File "$repo\scripts\install-cunica.ps1" -AgentCheck
```

---

*Источник: реальная сессия установки через Cursor Agent, 2026-07-09. Обновлено после реализации zip + `-AgentInstall`.*
