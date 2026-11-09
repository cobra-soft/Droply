# Droply

Быстрая передача файлов между устройствами (телефон ↔ ПК) через временные
сессии с real-time синхронизацией. Короткая ссылка вида `https://<домен>/4820`,
время жизни 10 минут – 6 часов, автоочистка по TTL.

- **Backend:** Cloudflare Workers, Durable Objects (WebSocket Hibernation), D1, R2
- **Frontend:** один файл `frontend/index.html` — HTML + CSS + чистый JS,
  встроенный SVG-спрайт иконок и локальные шрифты. **Без сборки и без npm.**
- **Статика:** отдаётся тем же Worker'ом из `frontend/` (binding `ASSETS`)

```
worker/      # Cloudflare Worker + Durable Objects
frontend/    # index.html (всё приложение) + assets/ (шрифты)
migrations/  # SQL для D1
tests/       # grep-тесты структуры проекта
```

## Деплой в Termux

> `node_modules` нельзя ставить на `/sdcard` (FAT, нет symlink'ов). Сначала
> скопируйте проект в домашний каталог:

```bash
cp -r /storage/emulated/0/Download/Worker/Droply ~/droply
cd ~/droply
npm i -g wrangler
wrangler login
```

### 1. Ресурсы Cloudflare (один раз)

```bash
# D1: создать базу и вставить её database_id в worker/wrangler.toml
wrangler d1 create droply

# R2: создать бакет
wrangler r2 bucket create droply-files

# Применить схему
cd worker
wrangler d1 migrations apply droply --remote
cd ..
```

### 2. Задеплоить Worker

```bash
cd worker
npm install            # только для wrangler/типов; фронтенд не собирается
npx wrangler deploy
```

Worker раздаёт `../frontend` (готовый `index.html` + `assets/`) и API на одном
origin, поэтому отдельный хостинг фронта не нужен. Правки в `index.html`
подхватываются при следующем `wrangler deploy` — шага сборки нет.

### 3. Опционально

- **Домен.** Привяжите короткий домен к Worker (Custom Domain в дашборде или
  CNAME на `<worker>.<account>.workers.dev`). Same-origin запросы работают на
  любом домене; для отдельного хостинга фронта добавьте его в `ALLOWED_ORIGINS`
  в `worker/wrangler.toml`.
- **R2 Lifecycle.** В дашборде R2 → `droply-files` → Settings → Object lifecycle:
  удалять объекты старше **7 дней** (глубокая страховка; основной механизм —
  alarm в Durable Object + cron каждый час).

## Локальная разработка

```bash
cd worker && npm install && npx wrangler dev     # http://localhost:8787
```

`wrangler dev` отдаёт и API, и статику из `../frontend`, так что отдельный
dev-сервер фронтенда не нужен. Для `wrangler dev` создайте `worker/.dev.vars`
(см. `.dev.vars.example`).

## Проверки

```bash
bash tests/run_all.sh            # 12 структурных / синтаксических тестов
cd worker && npm run typecheck   # tsc --noEmit
```

Тест 04 извлекает встроенный `<script>` из `frontend/index.html` и проверяет его
через `node --check` — отдельный TypeScript/бандлер для фронта не требуется.

## API

| Метод  | Путь                        | Описание                                   |
| ------ | --------------------------- | ------------------------------------------ |
| POST   | `/api/sessions`             | Создать сессию `{ ttl }`                   |
| GET    | `/api/sessions/:id`         | Инфо о сессии + список файлов              |
| POST   | `/api/sessions/:id/upload`  | Загрузка файла (multipart, ≤ 50 МБ)        |
| GET    | `/api/files/:fileId`        | Скачивание файла                           |
| DELETE | `/api/files/:fileId`        | Удалить файл                               |
| WS     | `/api/sessions/:id/ws`      | Real-time: `init`, `file_added`, `file_removed`, `session_expiring` |
