# Internet Structure Explorer - Исследование структуры и глобальной
связности Интернет
BGPAdmins

# Обзор проекта

## Назначение и цели

Internet Structure Explorer - это комплексный R-пакет для исследования
структуры и связности глобального интернета на основе данных автономных
систем (AS), BGP-маршрутов и анализа сетевого трафика.

### Основные возможности

-   Сбор данных: Автоматизированный сбор данных из публичных источников
    (DB-IP, MaxMind GeoLite, RIPE, CAIDA)
-   Анализ сети: Трассировка маршрутов (IPv4/IPv6), извлечение AS-путей,
    метрики связности
-   Интерактивная визуализация: Веб-приложение Shiny с картами,
    графиками и таблицами
-   Контейнеризация: Docker для легкого развертывания и масштабирования
-   Фоновый сбор данных: Worker-процессы для непрерывного обновления
    данных

## Архитектура проекта

### Структура пакета

    internetstructure/
    ├── DESCRIPTION                    
    ├── NAMESPACE                      
    ├── R/                            
    │   ├── data_collection.R         
    │   ├── traceroute.R              
    │   ├── as_data.R                 
    │   ├── visualization.R           
    │   └── utilities.R               
    ├── tests/                        
    ├── data-raw/                     
    ├── inst/docker/                  
    │   ├── Dockerfile               
    │   ├── Dockerfile.worker        
    │   ├── nginx.conf              
    │   ├── init-db.sql             
    │   └── worker.R                
    └── docker-compose.yml           

### Папка R/

Папка R/ содержит основной программный код пакета: функции сбора данных,
анализа трассировок, работы с AS-данными, визуализации и вспомогательные
утилиты.

### Папка inst/docker/

Содержит файлы для контейнеризации проекта.

Состав:

-   Dockerfile
-   Dockerfile.worker
-   nginx.conf
-   init-db.sql
-   worker.R

### Папка tests/

Папка содержит автоматизированные тесты для проверки корректности работы
функций пакета.

### Папка data-raw/

Папка data-raw/ содержит исходные данные и скрипты для их обработки. Это
промежуточные данные, которые используются для создания финальных
датасетов, включаемых в пакет.

### Основные модули

# Модуль сбора данных (data_collection.R)

## Функции сбора данных

### `collect_dbip_data()`

Скачивает и обрабатывает данные IP-to-ASN из сервиса DB-IP.

    Скачивание данных DB-IP
    dbip_data <- collect_dbip_data()

    Структура возвращаемых данных
    head(dbip_data)
       start_ip     end_ip asn organization start_ip_numeric end_ip_numeric
     1 1.0.0.0    1.0.0.255 13335  Cloudflare     16777216       16777471
     2 1.0.1.0    1.0.1.255 13335  Cloudflare     16777472       16777727

Параметры: - `url`: URL для скачивания данных DB-IP (по умолчанию -
бесплатная база) - `save_path`: Путь для сохранения скачанного файла
(опционально)

### `collect_maxmind_data()`

Скачивает геолокационные данные из базы MaxMind GeoLite.

    Скачивание данных MaxMind (требуется лицензионный ключ)
    maxmind_data <- collect_maxmind_data(license_key = "your_key")

Особенности: - Поддержка бесплатной и платной версий - Данные включают
страну, континент, координаты - Формат CIDR для IP-диапазонов

### `download_geolite_asn()`

Скачивает базу данных MaxMind GeoLite ASN для сопоставления IP-AS.

    Скачивание ASN-данных
    asn_data <- download_geolite_asn(license_key = "your_key")

### `parse_geolite_csv()`

Парсит скачанные CSV-файлы GeoLite в структурированные данные.

    Парсинг GeoLite файла
    parsed_data <- parse_geolite_csv("GeoLite2-Country-Blocks-IPv4.csv", type = "country")

# Модуль анализа трассировки (traceroute.R)

## Функции трассировки сети

### `run_traceroute()`

Выполняет команду traceroute к указанному IP или хосту.

    Запуск трассировки
    result <- run_traceroute("8.8.8.8", max_hops = 30, timeout = 2)

    Структура результата
    str(result)
    # List of 9
    #  $ target   : chr "8.8.8.8"
    #  $ command  : chr "traceroute -m 30 -w 2 8.8.8.8"
    #  $ output   : chr [1:15] "traceroute to 8.8.8.8 (8.8.8.8), 30 hops max..." ...
    #  $ error    : chr ""
    #  $ status   : int 0
    #  $ timestamp: POSIXct[1:1], format: "2024-01-01 12:00:00"
    #  $ protocol : chr "icmp"
    #  $ max_hops : num 30
    #  $ timeout  : num 2

Параметры: - `target`: IP-адрес или имя хоста - `max_hops`: Максимальное
количество hop’ов (по умолчанию 30) - `timeout`: Таймаут на hop в
секундах (по умолчанию 2) - `protocol`: Протокол (“icmp”, “udp”, “tcp”)

### `parse_traceroute_output()`

Парсит сырой вывод traceroute в структурированные данные.

    Парсинг результатов трассировки
    parsed <- parse_traceroute_output(result)

    Структура данных
    head(parsed)
       hop ip_hostname   rtt1   rtt2   rtt3 avg_rtt asn target  protocol timestamp as_path as_path_length
     1   1 192.168.1.1   1.2    1.1    1.3    1.20  NA 8.8.8.8 icmp     ...       ""      0
     2   2  10.0.0.1     5.4    5.6    5.2    5.40  NA 8.8.8.8 icmp     ...       ""      0

### `extract_as_path()`

Извлекает путь автономных систем из данных трассировки.

    Извлечение AS-пути
    as_path <- extract_as_path(parsed, dbip_data)

    Результат с AS-информацией
    head(as_path)
       hop ip_hostname rtt1 ... asn as_path        as_path_length
     1   1 192.168.1.1 ...    NA "3356 -> 15169"   2
     2   2  10.0.0.1   ...    NA "3356 -> 15169"   2
     3   3 203.0.113.1 ...  3356 "3356 -> 15169"   2
     4   4  8.8.8.8    ... 15169 "3356 -> 15169"   2

### `batch_traceroute()`

Выполняет трассировку к множеству целей.

    Пакетная трассировка
    targets <- c("8.8.8.8", "1.1.1.1", "208.67.222.222")
    results <- batch_traceroute(targets, delay = 1)

# Модуль управления данными AS (as_data.R)

## Функции работы с данными AS

### `create_as_dataframe()`

Создает унифицированный датафрейм с информацией об AS.

    Создание унифицированного датасета
    unified <- create_as_dataframe(dbip_data, maxmind_data, as_info_data)

    Структура данных
    str(unified)
     'data.frame': 1000 obs. of 15 variables:
      $ asn              : num  15169 15169 3356 ...
      $ organization     : chr  "Google LLC" "Google LLC" "Level 3" ...
      $ start_ip         : chr  "8.8.8.0" "8.8.4.0" ...
      $ end_ip           : chr  "8.8.8.255" "8.8.4.255" ...
      $ country_code     : chr  "US" "US" "US" ...
      $ country_name     : chr  "United States" "United States" ...
      $ continent_code   : chr  "NA" "NA" "NA" ...
      $ continent_name   : chr  "North America" "North America" ...
      $ ip_count         : num  256 256 1048576 ...
      $ start_ip_numeric : num  134217728 134217728 ...
      $ end_ip_numeric   : num  134217983 134217983 ...
      $ latitude         : num  37.4 37.4 38.6 ...
      $ longitude        : num  -122 -122 -90.1 ...
      $ data_source      : chr  "unified_as_data" ...
      $ created_at       : POSIXct[1:1], format: ...

### `merge_as_data()`

Сливает данные из множественных источников.

    Слияние данных из разных источников
    merged <- merge_as_data(list(dbip_data, maxmind_asn), c("dbip", "maxmind"))

### `save_as_data()` и `load_as_data()`

Сохранение и загрузка данных AS в различных форматах.

    Сохранение в разных форматах
    save_as_data(unified, "as_data.csv", "csv")
    save_as_data(unified, "as_database.db", "sqlite")

    Загрузка данных
    loaded_data <- load_as_data("as_database.db", "sqlite")

### `get_as_info()`

Получение детальной информации об автономных системах.

    Получение информации об AS
    google_info <- get_as_info(unified, 15169)
    print(google_info)
       asn organization country_code country_name total_ip_ranges total_ip_count data_sources
     1 15169 Google LLC           US United States              25       6553600   unified_as_data

# Модуль визуализации (visualization.R)

## Интерактивное веб-приложение Shiny

### `create_shiny_app()`

Создает полнофункциональное Shiny-приложение для исследования данных.

    Создание приложения
    app <- create_shiny_app(as_data = unified_data)

    Запуск
    shiny::runApp(app)

### Структура приложения

Приложение включает следующие вкладки:

1.  Обзор (Overview): Общая статистика и распределения
2.  Анализ AS (AS Analysis): Детальный анализ автономных систем
3.  Географический вид (Geographic View): Интерактивная карта мира
4.  Граф сети (Network Graph): Визуализация связей между AS
5.  Трассировка (Traceroute Explorer): Интерактивная трассировка
    маршрутов
6.  Таблица данных (Data Table): Полная таблица данных

### `run_shiny_app()`

Запускает Shiny-приложение с демо-данными.

    Быстрый запуск с демо-данными
    run_shiny_app()

### `create_network_plot()` и `create_geographic_map()`

Создание статических визуализаций.

    Сетевой граф
    network_plot <- create_network_plot(as_data, traceroute_data)

    Географическая карта
    world_map <- create_geographic_map(as_data)

# Модуль утилит (utilities.R)

## Вспомогательные функции

### Функции работы с IP-адресами

    Валидация IP
    validate_ip("192.168.1.1")  # TRUE
    validate_ip("256.1.1.1")    # FALSE

    Преобразование IP
    ip_numeric <- ip_to_numeric("192.168.1.1")  # 3232235777
    ip_string <- numeric_to_ip(3232235777)      # "192.168.1.1"

    Проверка диапазона
    ip_in_range("192.168.1.50", "192.168.1.0", "192.168.1.255")  # TRUE

### `ip_to_asn()`

Поиск ASN по IP-адресу.

    Поиск ASN для IP
    asn <- ip_to_asn("8.8.8.8", dbip_data)  # 15169

### Метрики связности

    Расчет метрик связности
    metrics <- calculate_connectivity_metrics(as_data, traceroute_data)

    Структура метрик
    str(metrics)
     List of 12
      $ total_asns               : int 500
      $ total_ip_ranges          : int 10000
      $ total_ip_space           : num 2.5e+09
      $ countries_with_asns      : int 120
      $ continents_represented   : int 6
      $ top_asn_concentration    : data.frame [50 × 4]
      $ total_traceroutes        : int 10
      $ average_hops             : num 15.2
      $ average_rtt              : num 45.8
      $ hop_distribution         : table [1:20]
      $ rtt_distribution         : Named num [1:3] 12.3 45.8 89.2
      $ average_as_path_length   : num 4.2

### Генерация тестовых данных

    Генерация случайных IP
    random_ips <- generate_random_ips(100)

    Форматирование информации об AS
    formatted <- format_as_info(15169, "Google LLC", "US")
     "AS15169 (Google LLC, US)"
