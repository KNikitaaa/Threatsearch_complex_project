#' Генерация Dockerfile для NetWalker
#'
#' Создает Dockerfile для контейнеризации приложения NetWalker
#'
#' @param output_path Путь для сохранения Dockerfile (по умолчанию: "Dockerfile")
#' @param base_image Базовый Docker образ (по умолчанию: "rocker/shiny:latest")
#' @param r_version Версия R (если используется rocker/r-ver)
#' @param install_devtools Установить devtools для разработки?
#' @param expose_port Порт для экспозиции (по умолчанию: 3838)
#'
#' @return Путь к созданному Dockerfile
#' @export
#'
#' @examples
#' \dontrun{
#' # Создать стандартный Dockerfile
#' generate_dockerfile()
#'
#' # Создать с указанием порта 80
#' generate_dockerfile(expose_port = 80)
#' }
generate_dockerfile <- function(
    output_path = "Dockerfile",
    base_image = "rocker/shiny:latest",
    r_version = "4.3.0",
    install_devtools = FALSE,
    expose_port = 3838
) {
  
  docker_content <- c(
    "# ====================================================",
    "# Dockerfile для NetWalker - анализа маршрутизации Интернета",
    "# Автоматически сгенерировано функцией generate_dockerfile()",
    "# ====================================================\n",
    paste("FROM", base_image),
    "",
    "# Мета-информация",
    "LABEL maintainer=\"NetWalker Team <netwalker@example.com>\"",
    "LABEL version=\"1.0\"",
    "LABEL description=\"Shiny приложение для анализа автономных систем и маршрутизации\"\n",
    "# Установка системных зависимостей",
    "RUN apt-get update && apt-get install -y \\",
    "    traceroute \\",
    "    iputils-ping \\",
    "    whois \\",
    "    net-tools \\",
    "    dnsutils \\",
    "    && rm -rf /var/lib/apt/lists/*\n",
    "# Создание директории приложения",
    "RUN mkdir -p /srv/shiny-server/netwalker\n",
    "# Установка R-пакетов",
    "RUN R -e \"install.packages(c(\\\"dplyr\\\", \\\"tidyr\\\", \\\"purrr\\\", \\\"stringr\\\"))\"",
    "RUN R -e \"install.packages(c(\\\"shiny\\\", \\\"shinydashboard\\\", \\\"shinyWidgets\\\"))\"",
    "RUN R -e \"install.packages(c(\\\"leaflet\\\", \\\"visNetwork\\\", \\\"DT\\\"))\"",
    "RUN R -e \"install.packages(c(\\\"httr\\\", \\\"jsonlite\\\", \\\"data.table\\\"))\"",
    "RUN R -e \"install.packages(c(\\\"processx\\\", \\\"logger\\\", \\\"config\\\"))\""
  )
  
  # Добавляем devtools если нужно
  if (install_devtools) {
    docker_content <- c(docker_content, 
                        "RUN R -e \"install.packages('devtools')\"")
  }
  
  docker_content <- c(docker_content,
                      "",
                      "# Копирование приложения",
                      "COPY inst/shinyapp /srv/shiny-server/netwalker",
                      "",
                      "# Настройка прав доступа",
                      "RUN chown -R shiny:shiny /srv/shiny-server/netwalker",
                      "RUN chmod -R 755 /srv/shiny-server/netwalker",
                      "",
                      "# Экспозиция порта",
                      paste("EXPOSE", expose_port),
                      "",
                      "# Переменные окружения",
                      "ENV SHINY_APP_DIR=/srv/shiny-server/netwalker",
                      "ENV SHINY_PORT=3838",
                      "ENV R_LIBS_USER=/usr/local/lib/R/site-library",
                      "",
                      "# Запуск приложения",
                      "CMD [\"/usr/bin/shiny-server\"]"
  )
  
  # Запись в файл
  writeLines(docker_content, output_path)
  
  message("Dockerfile успешно создан: ", normalizePath(output_path))
  message("Для сборки образа выполните: docker build -t netwalker .")
  
  return(normalizePath(output_path))
}

#' Проверка Docker окружения
#'
#' Проверяет наличие и работоспособность Docker
#'
#' @return Список с результатами проверки
#' @export
check_docker_environment <- function() {
  result <- list(
    docker_installed = FALSE,
    docker_compose_installed = FALSE,
    docker_running = FALSE,
    docker_version = NULL,
    docker_compose_version = NULL,
    can_pull_images = FALSE,
    can_run_containers = FALSE
  )
  
  # Проверка Docker
  tryCatch({
    docker_version_output <- system2("docker", "--version", stdout = TRUE, stderr = TRUE)
    result$docker_installed <- TRUE
    result$docker_version <- docker_version_output[1]
    
    # Проверка, что Docker демон запущен
    docker_info <- system2("docker", "info", stdout = TRUE, stderr = TRUE)
    result$docker_running <- !any(grepl("Cannot connect", docker_info))
    
    # Проверка возможности pull
    system2("docker", "pull hello-world", stdout = FALSE, stderr = FALSE)
    result$can_pull_images <- TRUE
    
    # Проверка возможности запуска контейнеров
    test_run <- system2("docker", c("run", "--rm", "hello-world"), 
                        stdout = TRUE, stderr = TRUE)
    result$can_run_containers <- any(grepl("Hello from Docker", test_run))
  }, error = function(e) {
    result$docker_installed <- FALSE
  })
  
  # Проверка Docker Compose
  tryCatch({
    compose_version <- system2("docker-compose", "--version", stdout = TRUE, stderr = TRUE)
    result$docker_compose_installed <- TRUE
    result$docker_compose_version <- compose_version[1]
  }, error = function(e) {
    result$docker_compose_installed <- FALSE
  })
  
  # Форматированный вывод
  message("=== Проверка Docker окружения ===")
  message("Docker установлен: ", ifelse(result$docker_installed, "✓", "✗"))
  if (result$docker_installed) {
    message("Версия Docker: ", result$docker_version)
    message("Docker демон запущен: ", ifelse(result$docker_running, "✓", "✗"))
    message("Может скачивать образы: ", ifelse(result$can_pull_images, "✓", "✗"))
    message("Может запускать контейнеры: ", ifelse(result$can_run_containers, "✓", "✗"))
  }
  
  message("Docker Compose установлен: ", ifelse(result$docker_compose_installed, "✓", "✗"))
  if (result$docker_compose_installed) {
    message("Версия Docker Compose: ", result$docker_compose_version)
  }
  
  return(result)
}

#' Сборка Docker образа NetWalker
#'
#' @param tag Тег для образа (по умолчанию: "netwalker:latest")
#' @param dockerfile_path Путь к Dockerfile (по умолчанию: "inst/extras/Dockerfile")
#' @param build_args Дополнительные аргументы для сборки
#'
#' @return Результат сборки
#' @export
build_docker_image <- function(
    tag = "netwalker:latest",
    dockerfile_path = "inst/extras/Dockerfile",
    build_args = NULL
) {
  
  # Проверяем существование Dockerfile
  if (!file.exists(dockerfile_path)) {
    stop("Dockerfile не найден: ", dockerfile_path)
  }
  
  message("Начинаю сборку Docker образа: ", tag)
  message("Использую Dockerfile: ", normalizePath(dockerfile_path))
  
  # Подготавливаем команду
  cmd <- c("build", "-t", tag, "-f", dockerfile_path, ".")
  
  # Добавляем build args если есть
  if (!is.null(build_args) && length(build_args) > 0) {
    for (arg in names(build_args)) {
      cmd <- c(cmd, "--build-arg", paste0(arg, "=", build_args[[arg]]))
    }
  }
  
  # Выполняем сборку
  result <- system2("docker", cmd, stdout = TRUE, stderr = TRUE)
  
  # Проверяем результат
  if (any(grepl("Successfully built", result))) {
    message("✓ Docker образ успешно собран: ", tag)
    
    # Показываем информацию о образе
    system2("docker", c("images", tag))
    
    return(list(
      success = TRUE,
      tag = tag,
      output = result
    ))
  } else {
    message("✗ Ошибка сборки Docker образа")
    return(list(
      success = FALSE,
      tag = tag,
      output = result
    ))
  }
}

#' Запуск контейнера NetWalker
#'
#' @param image Тег образа (по умолчанию: "netwalker:latest")
#' @param port Порт хоста для маппинга (по умолчанию: 3838)
#' @param name Имя контейнера (по умолчанию: "netwalker-app")
#' @param detach Запустить в фоновом режиме? (по умолчанию: TRUE)
#'
#' @return ID контейнера
#' @export
run_docker_container <- function(
    image = "netwalker:latest",
    port = 3838,
    name = "netwalker-app",
    detach = TRUE
) {
  
  # Проверяем существование образа
  check_image <- system2("docker", c("images", "-q", image), stdout = TRUE)
  
  if (length(check_image) == 0) {
    stop("Образ '", image, "' не найден. Сначала выполните build_docker_image()")
  }
  
  message("Запуск контейнера NetWalker...")
  message("Образ: ", image)
  message("Порт: ", port)
  message("Имя контейнера: ", name)
  
  # Подготавливаем команду
  cmd <- c(
    "run",
    if (detach) "-d",
    "-p", paste0(port, ":3838"),
    "--name", name,
    image
  )
  
  # Запускаем контейнер
  container_id <- system2("docker", cmd, stdout = TRUE)
  
  if (length(container_id) > 0) {
    message("✓ Контейнер успешно запущен: ", container_id)
    message("Приложение доступно по адресу: http://localhost:", port)
    
    # Показываем статус контейнера
    Sys.sleep(2)  # Даем время на запуск
    system2("docker", c("ps", "-f", paste0("name=", name)))
    
    return(container_id)
  } else {
    stop("Не удалось запустить контейнер")
  }
}