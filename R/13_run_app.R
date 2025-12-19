#' Запуск Shiny-приложения NetWalker
#'
#' Эта функция запускает веб-приложение для визуализации маршрутизации Интернета.
#' Приложение позволяет выполнять traceroute, визуализировать маршруты на карте
#' и анализировать граф автономных систем.
#'
#' @param port Порт для запуска приложения (по умолчанию: 3838)
#' @param host Хост для приложения (по умолчанию: "127.0.0.1")
#' @param launch.browser Запустить в браузере? (TRUE/FALSE или путь к браузеру)
#' @param max_upload_size Максимальный размер загружаемых файлов в МБ (по умолчанию: 10)
#'
#' @return Запускает Shiny-приложение
#' @export
#'
#' @examples
#' \dontrun{
#' # Запустить приложение на порту 3838
#' run_netwalker_app()
#'
#' # Запустить на порту 8080
#' run_netwalker_app(port = 8080)
#'
#' # Запустить для доступа по сети
#' run_netwalker_app(host = "0.0.0.0", port = 80)
#' }
run_netwalker_app <- function(
    port = 3838, 
    host = "127.0.0.1", 
    launch.browser = TRUE,
    max_upload_size = 10
) {
  
  # Проверка установки необходимых пакетов
  required_packages <- c("shiny", "leaflet", "visNetwork", "dplyr", "DT")
  missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
  
  if (length(missing_packages) > 0) {
    stop(
      "Для запуска приложения необходимы следующие пакеты: ",
      paste(missing_packages, collapse = ", "),
      "\nУстановите их командой: install.packages(c('", 
      paste(missing_packages, collapse = "', '"), "'))"
    )
  }
  
  # Установка максимального размера загружаемых файлов
  options(shiny.maxRequestSize = max_upload_size * 1024^2)
  
  # Получение пути к приложению
  app_dir <- system.file("shinyapp", package = "netwalker")
  
  if (app_dir == "") {
    stop(
      "Не найдена директория с Shiny-приложением.\n",
      "Убедитесь, что пакет установлен правильно и содержит папку 'inst/shinyapp'."
    )
  }
  
  message("=========================================")
  message("Запуск NetWalker Application")
  message("Версия: ", utils::packageVersion("netwalker"))
  message("Директория приложения: ", app_dir)
  message("Приложение доступно по адресу: http://", host, ":", port)
  message("Для остановки нажмите Ctrl+C в консоли R")
  message("=========================================")
  
  # Запуск приложения
  shiny::runApp(
    appDir = app_dir,
    port = port,
    host = host,
    launch.browser = launch.browser,
    display.mode = "normal"
  )
}

#' Проверка состояния приложения
#'
#' Проверяет, запущено ли приложение на указанном порту
#'
#' @param port Порт для проверки
#' @param host Хост для проверки
#' @return TRUE если приложение отвечает, FALSE если нет
#' @export
check_app_status <- function(port = 3838, host = "127.0.0.1") {
  tryCatch({
    response <- httr::GET(paste0("http://", host, ":", port))
    return(httr::status_code(response) == 200)
  }, error = function(e) {
    return(FALSE)
  })
}

#' Остановка приложения NetWalker
#'
#' Останавливает все запущенные экземпляры приложения NetWalker
#'
#' @export
stop_netwalker_app <- function() {
  # Получаем информацию о запущенных процессах R
  processes <- system("ps aux | grep 'netwalker' | grep -v grep", intern = TRUE)
  
  if (length(processes) > 0) {
    message("Найдено запущенных процессов NetWalker: ", length(processes))
    
    # Извлекаем PID процессов
    pids <- sapply(strsplit(processes, "\\s+"), function(x) x[2])
    
    # Останавливаем процессы
    for (pid in pids) {
      tryCatch({
        system(paste("kill", pid), ignore.stderr = TRUE)
        message("Остановлен процесс PID: ", pid)
      }, error = function(e) {
        message("Не удалось остановить процесс PID: ", pid)
      })
    }
    
    message("Все процессы NetWalker остановлены.")
  } else {
    message("Нет запущенных процессов NetWalker.")
  }
}

#' Получить информацию о системе для отладки
#'
#' @return Список с информацией о системе
#' @export
get_system_info <- function() {
  sys_info <- list(
    r_version = R.version.string,
    platform = R.version$platform,
    os = Sys.info()["sysname"],
    shiny_version = utils::packageVersion("shiny"),
    netwalker_version = utils::packageVersion("netwalker"),
    installed_packages = installed.packages()[, "Package"],
    shiny_app_path = system.file("shinyapp", package = "netwalker"),
    working_directory = getwd(),
    hostname = Sys.info()["nodename"],
    time = Sys.time()
  )
  
  return(sys_info)
}