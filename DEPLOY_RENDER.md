# Деплой mc1h на Render.com с телефона

## Что получится

Постоянный HTTPS-адрес вида:

```text
https://mc1h-backend.onrender.com
```

или с суффиксом, который Render добавит, если имя занято:

```text
https://mc1h-backend-a1b2.onrender.com
```

Точный URL показывается в панели Render после деплоя. Его нужно вставить
в приложении mc1h через **⚙ → Base URL → Сохранить**. Пересобирать APK
больше не нужно.

> Важно: я не могу создать аккаунт Render и нажать Deploy за тебя — в этом
> окружении нет доступа к GitHub/Render. Поэтому ниже — готовая связка файлов
> и пошаговый путь через браузер телефона.

---

## Файлы, которые нужно загрузить в GitHub

В папке `deploy/render/` (и в корне проекта) лежат 5 файлов:

| файл | назначение |
|---|---|
| `Dockerfile` | сборка Python-образа и запуск uvicorn |
| `render.yaml` | Blueprint Render: бесплатный Docker web service |
| `requirements.txt` | зависимости Python |
| `mc1h-src.tar.gz` | исходники `app/`, `data/`, `docs/` одним архивом |
| `DEPLOY_RENDER.md` | эта инструкция |

Архив `mc1h-src.tar.gz` — это специально один файл, чтобы не загружать
20 Python-файлов по одному с телефона. Dockerfile сам распакует его при сборке.

Готовый ZIP со всеми пятью файлами:

```text
mc1h-render-deploy.zip
```

---

## Шаг 1. Скачать файлы на телефон

1. Открой Downloads.
2. Найди `mc1h-render-deploy.zip` (или пять отдельных файлов).
3. Распакуй ZIP через «Files by Google»:
   - открой архив;
   - нажми «Extract» / «Извлечь»;
   - получишь папку с `Dockerfile`, `render.yaml`, `requirements.txt`,
     `mc1h-src.tar.gz`.

Если распаковщика нет — поставь ZArchiver из Play Store.

> Загружать на GitHub нужно именно отдельные файлы, а не ZIP-архив.

---

## Шаг 2. Создать GitHub-аккаунт

1. Открой в Chrome: `https://github.com/signup`
2. Введи email, пароль, username.
3. Подтверди email.
4. Войди в GitHub.

GitHub нужен только как хранилище кода. Render будет забирать код оттуда.

---

## Шаг 3. Создать публичный репозиторий

1. Открой: `https://github.com/new`
2. Repository name: `mc1h-backend`
3. Visibility: **Public**
4. Не ставь галочки README / .gitignore / license.
5. Нажми **Create repository**.

---

## Шаг 4. Загрузить 4 файла в корень репозитория

На странице пустого репозитория:

1. Нажми **Add file → Upload files**.
2. Нажми **choose your files**.
3. Выбери из распакованной папки:
   - `Dockerfile`
   - `render.yaml`
   - `requirements.txt`
   - `mc1h-src.tar.gz`
4. Убедись, что в поле пути нет папки вроде `deploy/render/`.
   Файлы должны лежать в **корне** репозитория.
5. Нажми **Commit changes**.

Проверка: на главной странице репозитория должны быть видны
`Dockerfile`, `render.yaml`, `requirements.txt`, `mc1h-src.tar.gz`.
Файл `DEPLOY_RENDER.md` можно загрузить дополнительно, но он не обязателен.

Не переименовывай файлы. Особенно важно:

- `Dockerfile` — **без** `.txt`;
- `render.yaml` — именно `.yaml`;
- `mc1h-src.tar.gz` — именно двойное расширение `.tar.gz`.

Если Android сохранил `Dockerfile.txt`, переименуй обратно в `Dockerfile`
через файловый менеджер.

---

## Шаг 5. Зарегистрироваться на Render

1. Открой: `https://dashboard.render.com/register`
2. Нажми **GitHub** (Sign up with GitHub).
3. Разреши Render доступ к GitHub.
4. Если попросит — подтверди email.

Бесплатный тариф Render не требует карту.

---

## Шаг 6. Задеплоить через Blueprint

1. В Render открой **New +**.
2. Выбери **Blueprint**.
3. Подключи GitHub, если ещё не подключён.
4. Выбери репозиторий `mc1h-backend`.
5. Render прочитает `render.yaml`.
6. Нажми **Apply** / **Create resources**.
7. Дождись статуса **Live**. Первая сборка обычно 5–10 минут.

Render создаст сервис с именем `mc1h-backend` на плане **Free**.

---

## Шаг 7. Получить постоянный URL

1. Открой созданный сервис `mc1h-backend`.
2. Вверху страницы будет ссылка вида:
   `https://mc1h-backend.onrender.com`
3. Если Render добавил суффикс — скопируй **точный** URL.
4. Проверь в браузере телефона:

```text
https://ТВОЙ-URL.onrender.com/health
```

Должно вернуться:

```json
{"status":"ok"}
```

---

## Шаг 8. Вставить URL в приложение

1. Открой mc1h.
2. Нажми **⚙** в правом верхнем углу.
3. Вставь `https://ТВОЙ-URL.onrender.com` (можно без `/` на конце).
4. Нажми **Сохранить**.
5. Сделай тестовый прогон, например email или `/vu`.

Всё. При смене хостинга/URL APK пересобирать не нужно.

---

## Ограничения бесплатного Render

- Сервис **засыпает после ~15 минут простоя**.
- Первый запрос после сна может идти 30–60 секунд. В приложении есть
  read-timeout 120 секунд; если ошибка — нажми «Повторить».
- Файловая система **временная**. SQLite и `out/` живут в `/tmp` и
  пропадают при перезапуске/редеплое. Для тестов это нормально.
- Для постоянного хранения прогонов нужен платный Render Disk или внешняя БД.
- Публичный endpoint не имеет авторизации. Не публикуй URL в открытых чатах.
- Ключи API (ГИБДД, ЕГРЮЛ, Росреестр, face и т.д.) добавляются позже в
  Render → Environment. Без них в отчёте будут честные gaps.

---

## Если сборка упала

Открой в Render:

```text
Service → Logs
```

Частые причины:

1. **`mc1h-src.tar.gz` not found** — файл не загружен или лежит не в корне.
2. **`render.yaml` not found** — Blueprint создан не из того репозитория.
3. **Port bind error** — Dockerfile должен запускать uvicorn с
   `--host 0.0.0.0 --port $PORT`; в готовом Dockerfile это уже есть.
4. **Health check failed** — проверь `https://URL/health`; первый старт
   может быть медленным.
5. **Build timed out** — нажми **Manual Deploy → Clear build cache & deploy**.
6. **Имя `mc1h-backend` занято** — открой `render.yaml` в GitHub,
   замени `name: mc1h-backend` на `name: mc1h-backend-ТВОЙ_ЛОГИН`
   (латиница, цифры и дефисы), закоммить и нажми **Apply** снова.

---

## Альтернатива: деплой одной кнопкой

После создания репозитория можно открыть ссылку:

```text
https://render.com/deploy?repo=https://github.com/ТВОЙ_ЛОГИН/mc1h-backend
```

Render откроет Blueprint и предложит **Apply**. Это тот же деплой, только
без ручного выбора репозитория.