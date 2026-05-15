# Airflow для аналитического отдела

Проект поднимает Apache Airflow 3 в Docker Compose с PostgreSQL в качестве metadata DB,
Adminer для доступа к базе и Airflow Code Editor для редактирования DAG-файлов из UI.

Главное production-like требование: metadata DB хранится в физической папке проекта
`./data/postgres`, а не в SQLite и не только во внутреннем Docker volume.

Для эксплуатации на рабочем сервере используйте [RUNBOOK.md](RUNBOOK.md).

Для запуска внешних ETL-джоб других проектов рекомендуется использовать
`SSHOperator` и отдельного пользователя на сервере. Конкретный DAG для Streamlit
ETL добавляется отдельно, когда в проекте Streamlit появится сервис
`ab_metrics_etl`.

## Сервисы

- `postgres` - metadata DB Airflow.
- `airflow-init` - миграции БД и создание admin-пользователя.
- `airflow-api-server` - UI/API Airflow.
- `airflow-scheduler` - планировщик задач.
- `airflow-dag-processor` - парсер DAG-файлов.
- `adminer` - web-интерфейс для PostgreSQL.

## Структура данных

- `./data/postgres` - физические файлы PostgreSQL.
- `./dags` - DAG-файлы.
- `./logs` - логи Airflow.
- `./plugins` - плагины Airflow.
- `./config` - пользовательская конфигурация.
- `./backups` - дампы metadata DB.

Не удаляйте `./data/postgres`, если нужно сохранить метаданные Airflow.

## Первый запуск

Создайте `.env` из шаблона:

```bash
cp .env.example .env
```

В `.env` проверьте абсолютный путь к проекту:

```env
AIRFLOW_PROJECT_DIR=/absolute/path/to/airflow_postgresql
```

Проверьте UID пользователя, который владеет папкой проекта:

```bash
id -u
```

И укажите его в `.env`, чтобы Airflow Code Editor мог сохранять DAG-файлы
в примонтированную папку:

```env
AIRFLOW_UID=1000
```

На рабочем сервере это может быть, например:

```env
AIRFLOW_PROJECT_DIR=/opt/analytics-airflow
```

Сгенерируйте Fernet key:

```bash
./scripts/generate_fernet_key.sh
```

Вставьте полученное значение в `.env`:

```env
AIRFLOW__CORE__FERNET_KEY=...
```

Также поменяйте пароли:

```env
AIRFLOW_PROJECT_DIR=/absolute/path/to/airflow_postgresql
POSTGRES_PASSWORD=...
SUPERSET_DB_PASSWORD=...
AIRFLOW_ADMIN_PASSWORD=...
AIRFLOW_DATA_ENGINEER_PASSWORD=...
AIRFLOW_ANALYTICS_HEAD_PASSWORD=...
AIRFLOW_BUSINESS_ANALYTIC_PASSWORD=...
```

Сгенерируйте JWT secret для взаимодействия компонентов Airflow 3:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(48))"
```

И вставьте в `.env`:

```env
AIRFLOW__API_AUTH__JWT_SECRET=...
```

Подготовьте права на скрипты:

```bash
chmod +x scripts/*.sh
```

Соберите образ:

```bash
docker compose build
```

Инициализируйте базу Airflow:

```bash
docker compose up airflow-init
```

Если база уже была создана раньше и нужно добавить или обновить read-only
пользователя для Superset, выполните:

```bash
./scripts/create_superset_reader.sh
```

Запустите сервисы:

```bash
docker compose up -d
```

## Пользователи Airflow

При выполнении `docker compose up airflow-init` создаются пользователи:

- `admin` - `Admin`
- `data_engineer` - `Admin`
- `analytics_head` - `Admin`
- `business_analytic` - `Viewer`

Имена, email и пароли задаются в `.env`. Если пользователь уже существует,
скрипт инициализации не меняет его пароль.

## Параллельность и pools

Для небольшого аналитического сервера заданы консервативные лимиты:

```env
AIRFLOW__CORE__PARALLELISM=8
AIRFLOW__CORE__MAX_ACTIVE_TASKS_PER_DAG=4
AIRFLOW__CORE__MAX_ACTIVE_RUNS_PER_DAG=1
```

`airflow-init` также создает pools:

- `clickhouse_pool` - 2 слота.
- `postgres_pool` - 3 слота.
- `oracle_pool` - 1 слот.
- `external_etl_pool` - 1 слот.

В DAG указывайте pool для задач, которые ходят во внешние системы:

```python
PythonOperator(
    task_id="count_sale_rows",
    python_callable=count_sale_rows,
    pool="postgres_pool",
)
```

## Примеры DAG

В проекте есть два рабочих примера:

- `dags/dags_examples/example_1.py` - одна задача, которая считает строки в
  `raw_data.sale` через Connection `local_toy_postgres`.
- `dags/dags_examples/parallel_table_counts.py` - параллельные count-задачи с
  цепочкой `start -> parallel tasks -> finish` и ограничением через
  `postgres_pool`.

## Доступ

Airflow UI:

```text
http://localhost:8080
```

Adminer:

```text
http://localhost:8081
```

Подключение в Adminer:

- System: `PostgreSQL`
- Server: `postgres`
- Username: значение `POSTGRES_USER` из `.env`
- Password: значение `POSTGRES_PASSWORD` из `.env`
- Database: значение `POSTGRES_DB` из `.env`

PostgreSQL публикуется на порт хоста из переменной `POSTGRES_PORT`. Это нужно,
если внешний контейнер Superset на том же сервере будет строить дашборды по
метаданным Airflow.

Если порт `5432` уже занят локальным PostgreSQL или другим контейнером, поменяйте
в `.env` только внешний порт, например:

```env
POSTGRES_PORT=5433
```

Внутри Docker Compose сервисы всё равно обращаются к PostgreSQL как
`postgres:5432`.

Для Superset создается отдельный read-only пользователь:

```env
SUPERSET_DB_USER=superset_reader
SUPERSET_DB_PASSWORD=...
```

Строка подключения из Superset:

```text
postgresql+psycopg2://superset_reader:<SUPERSET_DB_PASSWORD>@<SERVER_IP>:5432/airflow
```

Если Superset запущен на том же сервере, но в другом контейнере, в качестве хоста
обычно используется IP сервера или `host.docker.internal`, если это настроено в
Docker окружении.

## Airflow Code Editor

После запуска откройте в Airflow UI:

```text
Plugins -> Airflow Code Editor
```

Code Editor работает с папкой:

```text
/opt/airflow/dags
```

На сервере это соответствует:

```text
./dags
```

## Проверка, что используется PostgreSQL, а не SQLite

Выполните:

```bash
docker compose exec airflow-api-server airflow config get-value database sql_alchemy_conn
```

Ожидается строка вида:

```text
postgresql+psycopg2://...
```

Если там `sqlite`, запуск настроен неправильно.

## Проверка auth manager

Для UI-пользователей и ролей используется FAB auth manager:

```bash
docker compose exec airflow-api-server airflow config get-value core auth_manager
```

Ожидается:

```text
airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager
```

## Проверка Execution API URL

В Airflow 3 задачи обращаются к Execution API. В Docker Compose он должен
указывать на API server по имени сервиса:

```bash
docker compose exec airflow-scheduler airflow config get-value core execution_api_server_url
```

Ожидается:

```text
http://airflow-api-server:8080/execution/
```

## Проверка JWT secret

В Airflow 3 scheduler и API server используют JWT для Execution API. Значение
должно быть одинаковым во всех Airflow-сервисах:

```bash
docker compose exec airflow-scheduler airflow config get-value api_auth jwt_secret
docker compose exec airflow-api-server airflow config get-value api_auth jwt_secret
```

Обе команды должны вернуть одно и то же замаскированное значение.

## Проверка Fernet-шифрования

1. Откройте Airflow UI.
2. Создайте Connection с паролем.
3. Откройте Adminer.
4. Найдите таблицу `connection`.
5. Проверьте поле с паролем: пароль не должен быть виден открытым текстом.

## Безопасный рестарт

Обычный рестарт:

```bash
docker compose restart
```

Остановка без удаления данных:

```bash
docker compose down
```

Повторный запуск:

```bash
docker compose up -d
```

## Опасные команды

Не используйте на рабочем сервере без отдельного бэкапа и понимания последствий:

```bash
docker compose down -v
docker volume rm ...
docker volume prune
docker system prune --volumes
rm -rf ./data/postgres
```

Почему это опасно:

- `docker compose down -v` удаляет Docker volumes. В текущем проекте PostgreSQL
  хранится в `./data/postgres`, но привычка запускать `down -v` опасна для других
  окружений и может привести к потере данных.
- `docker volume prune` и `docker system prune --volumes` могут удалить volumes,
  которые кажутся Docker неиспользуемыми.
- `rm -rf ./data/postgres` удаляет физические файлы metadata DB Airflow.

Также не меняйте `AIRFLOW_PROJECT_DIR` в `.env` без миграции данных. Если указать
новую пустую папку, PostgreSQL создаст новую пустую базу, и в UI Airflow будет
выглядеть так, будто Connections, Variables и история запусков пропали.

Перед любыми опасными операциями сделайте бэкап:

```bash
./scripts/backup_postgres.sh
```

Технически Docker не запрещает ввод опасных команд. На рабочем сервере риск обычно
снижают организационно: доступ к Docker дают ограниченному кругу пользователей,
используют runbook с разрешенными командами, настраивают регулярные бэкапы и
проверяют восстановление.

## Бэкап metadata DB

Создать дамп:

```bash
./scripts/backup_postgres.sh
```

Срок хранения задается в `.env`:

```env
BACKUP_RETENTION_DAYS=14
```

Скрипт удаляет dump-файлы старше указанного количества дней. Если запускать
бэкап один раз в день, будет храниться примерно 14-15 последних дампов.

Для рабочего сервера добавьте ежедневный запуск через cron:

```bash
crontab -e
```

Пример запуска каждый день в 03:00:

```cron
0 3 * * * cd /opt/analytics-airflow && ./scripts/backup_postgres.sh >> ./backups/backup.log 2>&1
```

Дампы сохраняются в:

```text
./backups
```

Восстановить дамп:

```bash
./scripts/restore_postgres.sh backups/airflow_metadata_YYYYMMDD_HHMMSS.dump
```

Перед восстановлением на рабочем сервере остановите сервисы Airflow:

```bash
docker compose stop airflow-api-server airflow-scheduler airflow-dag-processor
```
