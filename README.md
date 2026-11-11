# mc1h — entity-resolution pipeline (username + Sherlock PD)

Два режима в одном API:

1. **username → нормализация → 11 платформенных резолверов → граф → отчёт**;
2. **Sherlock-combiner**: ФИО+ДР, контакты (телефон/email), транспорт
   (госномер/VIN), соцсети, Telegram, документы (`/vu`, `/passport`,
   `/snils`, `/inn`), онлайн-следы (`/tag`, домен/IP), недвижимость
   (`/adr`, кадастр), юрлица (ИНН/ОГРН/ОГРНИП), поиск по лицу → fan-out →
   идентификаторы/персоны/организации/записи → граф → досье.

Ключевой принцип: совпадение handle/ФИО/номера — **гипотеза**, а не тождество.
`verified_link` ставится только по внешнему подтверждению. Каждый факт несёт
источник, endpoint, время, HTTP-статус и confidence. Всё, что нельзя получить
легально (ключ, captcha, закрытый API, утечки), попадает в раздел
**«Пробелы и сбои»**, а не выдумывается.

## Быстрый старт

```bash
pip install -r requirements.txt

# username
python -m app.cli sindresorhus --out out

# Sherlock (синтетические значения)
python -m app.cli "+79990000001" --type phone --out out_pd
python -m app.cli "771234567859" --type inn --out out_pd
python -m app.cli "Тестов Тест Тестович" --type fio --birth-date 1990-01-01 --out out_pd
python -m app.cli "А123БВ777" --type transport --out out_pd
python -m app.cli "/vu 1234567890" --type vu --out out_pd
python -m app.cli "/tag сварщик Москва" --out out_pd
python -m app.cli "/adr Москва, Тверская, 1" --out out_pd
python -m app.cli "1027700132195" --type legal_entity --out out_pd

# API
uvicorn app.main:app --port 8000
curl -s -X POST localhost:8000/resolve \
  -H 'content-type: application/json' \
  -d '{"username":"sindresorhus","sources":["github","keybase","npm"]}'
curl -s -X POST localhost:8000/resolve \
  -H 'content-type: application/json' \
  -d '{"selector":"+79990000001","selector_type":"phone"}'
curl -s -X POST localhost:8000/resolve \
  -H 'content-type: application/json' \
  -d '{"selector":"А123БВ777","selector_type":"transport"}'
curl -s -X POST localhost:8000/resolve \
  -H 'content-type: application/json' \
  -d '{"selector":"/vu 1234567890"}'
curl -s localhost:8000/runs/<run_id>
curl -s localhost:8000/selectors
```

## Артефакты прогона

`out/<run_id>/`:

| файл | содержимое |
|---|---|
| `report.md` | username-отчёт или PD-досье: резюме, источники, сущности, связи, граф, **пробелы**, provenance |
| `dossier.json` | PD-JSON для Android: selector_kind, summary, gaps, entities, edges |
| `entities.json` | все Entity + Edge с provenance |
| `graph.dot` | Graphviz-граф |
| `graph.json` | узлы/рёбра + статистика |
| `run.json` | статусы резолверов, ошибки, допущения, gaps |

`report.md` — самостоятельный документ. Матрица источников:
[`docs/sources.md`](docs/sources.md) и [`docs/sources_pd.md`](docs/sources_pd.md).

## Структура

```
app/
  api.py            FastAPI: /resolve, /runs/{id}, /sources, /selectors
  cli.py            python -m app.cli (username или PD)
  config.py         Settings, MC1H_* env
  opsec.py          rate limit, proxy rotation, retry/backoff, timeouts
  cache.py          SQLite response cache (TTL, aiosqlite)
  schemas.py        Provenance, Entity, Edge, ResolverResult, RunResult
  service.py        username-оркестрация, depth-1, дедуп
  pipeline.py       Sherlock fan-out, merge, gaps, pipeline-level detect_selector
  detect.py         единая детекция/нормализация всех типов селекторов
  resolvers/        username-резолверы
  resolvers/pd/     fio, phone, email, inn, snils, passport, transport,
                    documents, social, telegram, online_traces,
                    real_estate, legal_entity, face, common, base
  db.py             SQLite: runs, entities (+PD columns), edges, provenance
  graph.py          NetworkX MultiDiGraph, DOT/JSON
  report.py         Markdown-рендер и запись артефактов
tests/              23 offline-теста, сеть не используется
```

## Модель данных

```
Provenance(source, endpoint, query, fetched_at, http_status, outcome,
           confidence, latency_ms, note)
Entity(id, kind[root|account|artifact|person|identifier|organization|record|breach],
       key, label, selector, platform, profile_url, data, raw_hash,
       attributes, provenance[], confidence)
Edge(src, dst, relation[handle_match|verified_link|owns|same_as|registered_at|
       observed_in|registered_as|director_of|founder_of|identified_as|
       affiliated_with], confidence, provenance, note)
```

`Entity.id` детерминирован: `kind:namespace:key` (например,
`identifier:phone:+79990000001`, `person:wikidata:Q42`). Полные номера
СНИЛС/паспорта не хранятся: только маска и необратимый хеш.

## Статусы прогона

- `complete` — все выбранные проверки ответили `ok`/`not_found` и нет gaps;
- `partial` — есть `blocked`, `error`, `timeout`, `invalid`, `not_configured`
  или заявленные пробелы (ключ, captcha, отсутствие легального API).

PD-прогон почти всегда `partial`: это честное отражение того, что часть
источников недоступна без ключа или запрещена.

## Переменные окружения

| переменная | по умолчанию | смысл |
|---|---|---|
| `MC1H_PROXIES` | пусто | `http://u:p@host:port,...`, round-robin |
| `MC1H_TIMEOUT` | 12 | таймаут одного запроса, сек |
| `MC1H_ATTEMPTS` | 3 | попыток на запрос |
| `MC1H_HOST_INTERVAL` | 0.8 | минимальный интервал к одному хосту, сек |
| `MC1H_CONCURRENCY` | 6 | глобальный семафор |
| `MC1H_PER_SOURCE_CONCURRENCY` | 2 | семафор на резолвер |
| `MC1H_RESOLVER_TIMEOUT` | 45 | таймаут одного резолвера, сек |
| `MC1H_MAX_SECONDARY` | 5 | лимит depth-1 добора |
| `MC1H_DB` | `data/mc1h.db` | SQLite |
| `MC1H_OUT` | `out` | каталог артефактов |
| `MC1H_CACHE_DB` | `data/mc1h_cache.db` | кеш ответов |
| `MC1H_CACHE_TTL` | 3600 | TTL кеша, сек; 0 выключает |
| `MC1H_FNS_API_URL` | пусто | легальный endpoint ЕГРЮЛ/ЕГРИП |
| `MC1H_FNS_API_KEY` | пусто | ключ к нему |
| `MC1H_HIBP_API_KEY` | пусто | HIBP API |
| `MC1H_GIBDD_API_URL` / `MC1H_GIBDD_API_KEY` | пусто | легальный API транспорта |
| `MC1H_DRIVER_API_URL` / `MC1H_DRIVER_API_KEY` | пусто | проверка ВУ |
| `MC1H_TELEGRAM_DB_URL` / `MC1H_TELEGRAM_DB_KEY` | пусто | поиск по Telegram ID |
| `MC1H_ROSREESTR_API_URL` / `MC1H_ROSREESTR_API_KEY` | пусто | Росреестр/ПКК |
| `MC1H_NOMINATIM_URL` | OSM | геокодер адресов |
| `MC1H_SEARCH_API_URL` / `MC1H_SEARCH_API_KEY` | пусто | поисковый API для `/tag` |
| `MC1H_FACE_API_URL` / `MC1H_FACE_API_KEY` | пусто | легальный biometric API |
| `GITHUB_TOKEN` | пусто | лимиты GitHub |
| `MC1H_PD_ENABLED` | 1 | kill-switch PD-модуля |

## Тесты

```bash
python -m pytest -q     # 26 passed, без сети
```

Проверка артефактов:

```bash
python tests/validate_artifacts.py out/<run_id>
```

## Известные ограничения

- Reddit отдаёт 403 с datacenter IP; нужен residential proxy или OAuth.
- Twitter/X, Instagram, TikTok, PyPI-профили не реализованы.
- Глубина username-разрешения — 1 хоп по verified-ссылкам.
- ЕГРЮЛ/ЕГРИП/ГИБДД/Росреестр/Telegram-ID/face требуют легального API и
  ключа; без них в отчёте появляется явный gap, а не выдуманные данные.
- Арбитраж/суды, Avito/Youla, Telegram-по-номеру не автоматизируются
  (captcha/ToS/авторизация). Avito/Youla поддерживают локальные HTML/JSON-экспорты.
- СНИЛС/паспорт/ВУ: только проверка формата/контрольного числа; легального
  публичного API «номер → ФИО» нет. Полные номера не хранятся: маска + SHA-256.
- Утечки, кроме официального HIBP по ключу, не используются.
- APK собран: `download/mc1h.apk`; debug v2 signing.
- Публичный URL в APK — постоянный Render: `https://mc1h-backend.onrender.com/`.

## Локальные данные из `data/`

`PhoneSearchResolver` читает файлы из `MC1H_LOCAL_DATA` (по умолчанию `data/`).
В Docker/Render это `/app/data`. Файл должен содержать цифры номера в имени:

```text
data/avito_79990000001.html
data/avito_79990000001.json
data/youla_79990000001.html
data/youla_79990000001.json
data/phone_79990000001.json
```

Поддерживаются HTML-экспорты Avito/Youla и JSON со списком объявлений или
контейнером `items/results/listings/ads/offers/records/data/@graph`.
Записи добавляются в граф как `record` с ребром `observed_in` и confidence
`0.45`. Пути к файлам в отчёте маскируются, полный номер в provenance не
попадает. Если локальный файл для Avito/Youla найден, сетевой запрос к этой
площадке не выполняется.

Подробный формат: `data/README.md`.

### Загрузка файлов в GitHub

1. Открой репозиторий `https://github.com/pasaurev26-ai/mc1h-backend`.
2. Нажми **Add file → Upload files**.
3. Перетащи/выбери файл, но в поле пути укажи `data/`:
   `data/avito_79990000001.html`.
   В мобильном браузере проще сначала открыть папку `data/`, затем
   **Add file → Upload files**.
4. Нажми **Commit changes**.
5. Render пересоберёт сервис (автодеплой при коммите) или нажми
   **Manual Deploy → Deploy latest commit**.
6. После сборки проверь: `https://mc1h-backend.onrender.com/health`.
7. В приложении запусти телефонный селектор с тем же номером.

`Dockerfile` содержит `COPY data/ /app/data/`, поэтому файлы из GitHub
попадают в образ. `.dockerignore` исключает только `*.db/*.sqlite`, а
HTML/JSON копируются.

## Постоянный бэкенд на Render.com

Сервис задеплоен: `https://mc1h-backend.onrender.com` (Frankfurt, free).
Проверка: `GET /health` → `{"status":"ok"}`.

Для повторного деплоя без ПК (только браузер телефона) подготовлены:

- `Dockerfile` — сборка FastAPI-образа;
- `render.yaml` — Blueprint бесплатного Render web service;
- `requirements.txt` — зависимости;
- `mc1h-src.tar.gz` — исходники одним архивом (Dockerfile распаковывает его);
- `DEPLOY_RENDER.md` — пошаговая инструкция;
- `download/mc1h-render-deploy.zip` — все пять файлов одним архивом.

Render free засыпает после ~15 минут простоя; первый запрос может идти
30–60 секунд. Файловая система временная: SQLite и `out/` живут в `/tmp`
и пропадают при перезапуске. Для тестов этого достаточно.

## Android: смена URL без пересборки

`ApiClient` больше не использует жёсткий `BASE_URL` для Retrofit. Адрес
хранится в `SharedPreferences` (`mc1h_server_settings` / `base_url`) и
читается при каждом создании сервиса. `INITIAL_BASE_URL` — только значение
по умолчанию для первого запуска.

1. Нажми ⚙ в TopAppBar.
2. Вставь новый публичный HTTPS URL (схему `https://` можно опустить).
3. Нажми «Сохранить». APK пересобирать не нужно.

Если сохранённый адрес пустой или невалидный, приложение показывает
«Нужен адрес бэкенда» и открывает диалог настройки. Ошибка соединения также
содержит кнопку «Настройки сервера».