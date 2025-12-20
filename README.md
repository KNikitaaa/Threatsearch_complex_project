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
