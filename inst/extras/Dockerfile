# ====================================================
# Dockerfile для NetWalker - анализа маршрутизации Интернета
# Версия: 1.0
# Сборка: docker build -t netwalker .
# Запуск: docker run -p 3838:3838 netwalker
# ====================================================

# Используем официальный образ Shiny Server от RStudio
FROM rocker/shiny:4.3.0

# Мета-информация
LABEL maintainer="NetWalker Team <netwalker@example.com>"
LABEL version="1.0"
LABEL description="Shiny приложение для анализа автономных систем и маршрутизации в Интернете"

# Установка системных утилит для сетевого анализа
RUN apt-get update && apt-get install -y \
    traceroute \
    iputils-ping \
    net-tools \
    dnsutils \
    whois \
    wget \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Создание директории приложения
RUN mkdir -p /srv/shiny-server/netwalker
RUN mkdir -p /srv/shiny-server/netwalker/www
RUN mkdir -p /srv/shiny-server/netwalker/data
RUN mkdir -p /var/log/shiny-server

# Установка необходимых R-пакетов
RUN R -e "install.packages(c( \
    'dplyr', \
    'tidyr', \
    'purrr', \
    'stringr', \
    'httr', \
    'jsonlite', \
    'data.table', \
    'DBI', \
    'duckdb' \
  ), repos='https://cloud.r-project.org/')"

# Установка пакетов для визуализации
RUN R -e "install.packages(c( \
    'shiny', \
    'shinydashboard', \
    'shinyWidgets', \
    'leaflet', \
    'visNetwork', \
    'DT', \
    'ggplot2', \
    'plotly' \
  ), repos='https://cloud.r-project.org/')"

# Установка вспомогательных пакетов
RUN R -e "install.packages(c( \
    'processx', \
    'logger', \
    'config', \
    'yaml', \
    'rmarkdown', \
    'knitr' \
  ), repos='https://cloud.r-project.org/')"

# Копирование файлов приложения
COPY ./inst/shinyapp /srv/shiny-server/netwalker

# Копирование данных (если есть)
COPY ./data /srv/shiny-server/netwalker/data

# Настройка прав доступа
RUN chown -R shiny:shiny /srv/shiny-server/netwalker
RUN chmod -R 755 /srv/shiny-server/netwalker

# Настройка логов
RUN chown -R shiny:shiny /var/log/shiny-server
RUN chmod -R 755 /var/log/shiny-server

# Создание символической ссылки для Shiny Server
RUN ln -s /srv/shiny-server/netwalker /srv/shiny-server/netwalker-app

# Конфигурация Shiny Server
COPY ./inst/extras/shiny-server.conf /etc/shiny-server/shiny-server.conf

# Экспозиция порта
EXPOSE 3838

# Переменные окружения
ENV SHINY_APP_DIR=/srv/shiny-server/netwalker
ENV SHINY_PORT=3838
ENV R_LIBS_USER=/usr/local/lib/R/site-library
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Здоровье контейнера (health check)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3838/ || exit 1

# Запуск Shiny Server
CMD ["/usr/bin/shiny-server"]