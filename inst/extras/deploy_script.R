#!/usr/bin/env Rscript
#
# Скрипт развертывания NetWalker
# Использование: Rscript deploy_script.R [команда]
# Команды: build, run, stop, deploy, clean, status
#

# ====================================================
# КОНФИГУРАЦИЯ
# ====================================================

CONFIG <- list(
  app_name = "netwalker",
  app_version = "1.0.0",
  docker_image = "netwalker:latest",
  container_name = "netwalker-app",
  host_port = 3838,
  container_port = 3838,
  data_dir = "/srv/shiny-server/netwalker/data",
  log_dir = "/var/log/shiny-server",
  docker_compose_file = "inst/extras/docker-compose.yml",
  dockerfile = "inst/extras/Dockerfile"
)

# ====================================================
# ФУНКЦИИ РАЗВЕРТЫВАНИЯ
# ====================================================

#' Логирование сообщений
log_message <- function(level, message) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(sprintf("[%s] [%s] %s\n", timestamp, toupper(level), message))
}

#' Проверка наличия Docker
check_docker <- function() {
  log_message("info", "Проверка Docker окружения...")
  
  # Проверка Docker
  docker_check <- system2("docker", "--version", stdout = TRUE, stderr = TRUE)
  if (length(docker_check) == 0) {
    log_message("error", "Docker не установлен!")
    return(FALSE)
  }
  log_message("info", paste("Docker:", docker_check[1]))
  
  # Проверка Docker Compose
  compose_check <- tryCatch({
    system2("docker-compose", "--version", stdout = TRUE, stderr = TRUE)
  }, error = function(e) NULL)
  
  if (!is.null(compose_check)) {
    log_message("info", paste("Docker Compose:", compose_check[1]))
  } else {
    log_message("warning", "Docker Compose не найден, некоторые функции недоступны")
  }
  
  return(TRUE)
}

#' Сборка Docker образа
build_docker <- function() {
  log_message("info", "Начинаю сборку Docker образа...")
  
  # Проверяем существование Dockerfile
  if (!file.exists(CONFIG$dockerfile)) {
    log_message("error", paste("Dockerfile не найден:", CONFIG$dockerfile))
    return(FALSE)
  }
  
  # Команда сборки
  cmd <- sprintf("docker build -t %s -f %s ../..", 
                 CONFIG$docker_image, CONFIG$dockerfile)
  
  log_message("info", paste("Выполняю:", cmd))
  
  # Выполняем сборку
  result <- system(cmd)
  
  if (result == 0) {
    log_message("success", "Docker образ успешно собран!")
    
    # Показываем информацию о образе
    system(sprintf("docker images %s", CONFIG$docker_image))
    
    return(TRUE)
  } else {
    log_message("error", "Ошибка сборки Docker образа!")
    return(FALSE)
  }
}

#' Запуск приложения через Docker Compose
run_docker_compose <- function() {
  log_message("info", "Запуск NetWalker через Docker Compose...")
  
  if (!file.exists(CONFIG$docker_compose_file)) {
    log_message("error", paste("docker-compose.yml не найден:", CONFIG$docker_compose_file))
    return(FALSE)
  }
  
  # Переходим в директорию с docker-compose.yml
  old_dir <- getwd()
  setwd(dirname(CONFIG$docker_compose_file))
  
  tryCatch({
    # Запускаем в фоновом режиме
    log_message("info", "Запускаю docker-compose up -d...")
    result <- system("docker-compose up -d")
    
    if (result == 0) {
      log_message("success", "NetWalker успешно запущен!")
      log_message("info", paste("Приложение доступно по адресу: http://localhost:", CONFIG$host_port))
      
      # Показываем статус
      Sys.sleep(3)
      system("docker-compose ps")
      
      return(TRUE)
    } else {
      log_message("error", "Ошибка запуска docker-compose!")
      return(FALSE)
    }
  }, finally = {
    setwd(old_dir)
  })
}

#' Запуск одиночного контейнера
run_docker_simple <- function() {
  log_message("info", "Запуск NetWalker в одиночном контейнере...")
  
  # Останавливаем старый контейнер если есть
  system(sprintf("docker stop %s 2>/dev/null || true", CONFIG$container_name))
  system(sprintf("docker rm %s 2>/dev/null || true", CONFIG$container_name))
  
  # Команда запуска
  cmd <- sprintf(
    'docker run -d \
    --name %s \
    -p %d:%d \
    -v %s-data:/srv/shiny-server/netwalker/data \
    -v /var/run/docker.sock:/var/run/docker.sock \
    --restart unless-stopped \
    %s',
    CONFIG$container_name,
    CONFIG$host_port,
    CONFIG$container_port,
    CONFIG$app_name,
    CONFIG$docker_image
  )
  
  log_message("info", paste("Выполняю:", gsub("\\s+", " ", cmd)))
  
  # Запускаем контейнер
  container_id <- system(cmd, intern = TRUE)
  
  if (length(container_id) > 0 && nchar(container_id[1]) > 0) {
    log_message("success", paste("Контейнер запущен:", container_id[1]))
    
    # Ждем запуска и проверяем статус
    Sys.sleep(5)
    
    # Проверяем логи
    log_message("info", "Проверка логов контейнера...")
    system(sprintf("docker logs --tail 10 %s", CONFIG$container_name))
    
    log_message("info", paste("Приложение доступно: http://localhost:", CONFIG$host_port))
    
    return(TRUE)
  } else {
    log_message("error", "Не удалось запустить контейнер!")
    return(FALSE)
  }
}

#' Остановка приложения
stop_application <- function() {
  log_message("info", "Остановка NetWalker...")
  
  # Пробуем остановить через docker-compose
  if (file.exists(CONFIG$docker_compose_file)) {
    setwd(dirname(CONFIG$docker_compose_file))
    system("docker-compose down 2>/dev/null || true")
    setwd("../../..")
  }
  
  # Останавливаем одиночный контейнер если есть
  system(sprintf("docker stop %s 2>/dev/null || true", CONFIG$container_name))
  system(sprintf("docker rm %s 2>/dev/null || true", CONFIG$container_name))
  
  log_message("success", "NetWalker остановлен")
  return(TRUE)
}

#' Проверка статуса приложения
check_status <- function() {
  log_message("info", "Проверка статуса NetWalker...")
  
  cat("\n")
  cat("=== СТАТУС NETWALKER ===\n")
  cat(sprintf("Версия: %s\n", CONFIG$app_version))
  cat(sprintf("Образ Docker: %s\n", CONFIG$docker_image))
  cat(sprintf("Порт: %d\n", CONFIG$host_port))
  cat("\n")
  
  # Проверяем запущенные контейнеры
  cat("Запущенные контейнеры:\n")
  cat("-----------------------\n")
  system(sprintf("docker ps --filter 'name=%s' --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'", 
                 CONFIG$container_name))
  
  cat("\n")
  
  # Проверяем образы
  cat("Образы Docker:\n")
  cat("----------------\n")
  system(sprintf("docker images %s", CONFIG$app_name))
  
  cat("\n")
  
  # Проверяем доступность приложения
  log_message("info", "Проверка доступности приложения...")
  tryCatch({
    response <- httr::GET(sprintf("http://localhost:%d", CONFIG$host_port))
    
    if (httr::status_code(response) == 200) {
      log_message("success", "✓ Приложение работает и доступно")
    } else {
      log_message("warning", paste("Приложение отвечает с кодом:", httr::status_code(response)))
    }
  }, error = function(e) {
    log_message("error", "✗ Приложение недоступно")
  })
  
  return(TRUE)
}

#' Очистка Docker ресурсов
clean_docker <- function() {
  log_message("info", "Очистка Docker ресурсов...")
  
  cat("\nВыберите действие:\n")
  cat("1. Очистить остановленные контейнеры\n")
  cat("2. Очистить неиспользуемые образы\n")
  cat("3. Очистить volumes\n")
  cat("4. Полная очистка\n")
  cat("0. Отмена\n")
  
  choice <- readline(prompt = "Ваш выбор: ")
  
  switch(choice,
         "1" = {
           log_message("info", "Очистка остановленных контейнеров...")
           system("docker container prune -f")
         },
         "2" = {
           log_message("info", "Очистка неиспользуемых образов...")
           system("docker image prune -af")
         },
         "3" = {
           log_message("info", "Очистка volumes...")
           system("docker volume prune -f")
         },
         "4" = {
           log_message("info", "Полная очистка...")
           system("docker system prune -af")
         },
         {
           log_message("info", "Очистка отменена")
           return(FALSE)
         }
  )
  
  log_message("success", "Очистка завершена")
  return(TRUE)
}

#' Полное развертывание
full_deploy <- function() {
  log_message("info", "Начинаю полное развертывание NetWalker...")
  
  # 1. Проверка окружения
  if (!check_docker()) {
    return(FALSE)
  }
  
  # 2. Сборка образа
  if (!build_docker()) {
    return(FALSE)
  }
  
  # 3. Запуск приложения
  if (file.exists(CONFIG$docker_compose_file)) {
    success <- run_docker_compose()
  } else {
    success <- run_docker_simple()
  }
  
  if (success) {
    log_message("success", "=")
    log_message("success", "РАЗВЕРТЫВАНИЕ УСПЕШНО ЗАВЕРШЕНО!")
    log_message("success", "=")
    log_message("info", paste("NetWalker доступен по адресу: http://localhost:", CONFIG$host_port))
    log_message("info", "Для просмотра логов: docker-compose logs -f")
  }
  
  return(success)
}

# ====================================================
# ОСНОВНАЯ ЛОГИКА
# ====================================================

main <- function() {
  # Парсинг аргументов командной строки
  args <- commandArgs(trailingOnly = TRUE)
  
  if (length(args) == 0) {
    # Если аргументов нет, запускаем полное развертывание
    args <- "deploy"
  }
  
  command <- args[1]
  
  # Выполняем команду
  switch(command,
         "build" = build_docker(),
         "run" = {
           if (file.exists(CONFIG$docker_compose_file)) {
             run_docker_compose()
           } else {
             run_docker_simple()
           }
         },
         "stop" = stop_application(),
         "deploy" = full_deploy(),
         "status" = check_status(),
         "clean" = clean_docker(),
         "help" = {
           cat("Использование: Rscript deploy_script.R [команда]\n")
           cat("\nКоманды:\n")
           cat("  build   - Сборка Docker образа\n")
           cat("  run     - Запуск приложения\n")
           cat("  stop    - Остановка приложения\n")
           cat("  deploy  - Полное развертывание (build + run)\n")
           cat("  status  - Проверка статуса\n")
           cat("  clean   - Очистка Docker ресурсов\n")
           cat("  help    - Эта справка\n")
         },
         {
           log_message("error", paste("Неизвестная команда:", command))
           cat("Используйте 'help' для справки\n")
           return(FALSE)
         }
  )
}

# Запуск скрипта
if (!interactive()) {
  main()
}