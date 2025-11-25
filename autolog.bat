@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

REM Получаем путь к папке скрипта
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

REM Создаем папку logs если её нет
if not exist "logs" mkdir logs

REM Формируем имя файла с датой и временем
set timestamp=%date:~6,4%-%date:~3,2%-%date:~0,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%
set timestamp=%timestamp: =0%
set "LOG_FILE=logs\system_log_%timestamp%.txt"

REM Начинаем запись в лог (с UTF-8 BOM для правильного отображения)
echo ================================ > "%LOG_FILE%"
echo СИСТЕМНАЯ СТАТИСТИКА >> "%LOG_FILE%"
echo ================================ >> "%LOG_FILE%"
echo Дата и время: %date% %time% >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM --- ИНФОРМАЦИЯ О СИСТЕМЕ ---
echo [ИНФОРМАЦИЯ О СИСТЕМЕ] >> "%LOG_FILE%"
echo Имя компьютера: %COMPUTERNAME% >> "%LOG_FILE%"
echo Пользователь: %USERNAME% >> "%LOG_FILE%"
echo Домен: %USERDOMAIN% >> "%LOG_FILE%"
echo Процессор: %PROCESSOR_IDENTIFIER% >> "%LOG_FILE%"
echo Архитектура: %PROCESSOR_ARCHITECTURE% >> "%LOG_FILE%"
echo Количество ядер: %NUMBER_OF_PROCESSORS% >> "%LOG_FILE%"
systeminfo | findstr /C:"OS Name" /C:"OS Version" /C:"System Type" /C:"Total Physical Memory" /C:"Available Physical Memory" /C:"System Boot Time" >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- ВРЕМЯ РАБОТЫ СИСТЕМЫ ---
echo [ВРЕМЯ РАБОТЫ (UPTIME)] >> "%LOG_FILE%"
for /f "skip=1" %%x in ('wmic os get lastbootuptime 2^>nul') do if not defined MyDate set MyDate=%%x
if defined MyDate (
    echo Последняя загрузка: %MyDate:~0,4%-%MyDate:~4,2%-%MyDate:~6,2% %MyDate:~8,2%:%MyDate:~10,2%:%MyDate:~12,2% >> "%LOG_FILE%"
) else (
    net statistics workstation | find "Statistics since" >> "%LOG_FILE%" 2>&1
)
echo. >> "%LOG_FILE%"

REM --- ИСПОЛЬЗОВАНИЕ РЕСУРСОВ (PowerShell) ---
echo [ИСПОЛЬЗОВАНИЕ РЕСУРСОВ] >> "%LOG_FILE%"
powershell -Command "Get-WmiObject Win32_Processor | Select-Object Name, LoadPercentage | Format-List" >> "%LOG_FILE%" 2>&1
powershell -Command "$os = Get-WmiObject Win32_OperatingSystem; $total = [math]::Round($os.TotalVisibleMemorySize/1MB,2); $free = [math]::Round($os.FreePhysicalMemory/1MB,2); $used = $total - $free; Write-Output \"Память: используется $used GB из $total GB (свободно $free GB)\"" >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- ИНФОРМАЦИЯ О ДИСКАХ ---
echo [ИНФОРМАЦИЯ О ДИСКАХ] >> "%LOG_FILE%"
powershell -Command "Get-PSDrive -PSProvider FileSystem | Where-Object {$_.Used -ne $null} | Select-Object Name, @{Name='Used(GB)';Expression={[math]::Round($_.Used/1GB,2)}}, @{Name='Free(GB)';Expression={[math]::Round($_.Free/1GB,2)}}, @{Name='Total(GB)';Expression={[math]::Round(($_.Used+$_.Free)/1GB,2)}} | Format-Table -AutoSize" >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- ЗАПУЩЕННЫЕ ПРОЦЕССЫ (топ по памяти) ---
echo [ТОП-15 ПРОЦЕССОВ ПО ПАМЯТИ] >> "%LOG_FILE%"
powershell -Command "Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First 15 ProcessName, @{Name='Memory(MB)';Expression={[math]::Round($_.WorkingSet/1MB,2)}}, CPU, Id | Format-Table -AutoSize" >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- СЕТЕВЫЕ ИНТЕРФЕЙСЫ ---
echo [СЕТЕВЫЕ ИНТЕРФЕЙСЫ] >> "%LOG_FILE%"
powershell -Command "Get-NetAdapter | Select-Object Name, Status, LinkSpeed, MacAddress | Format-Table -AutoSize" >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

echo [IP-КОНФИГУРАЦИЯ] >> "%LOG_FILE%"
ipconfig | findstr /C:"IPv4" /C:"IPv6" /C:"Default Gateway" /C:"Subnet Mask" /C:"Ethernet adapter" /C:"Wireless" >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- АКТИВНЫЕ СЕТЕВЫЕ ПОДКЛЮЧЕНИЯ ---
echo [АКТИВНЫЕ TCP-ПОДКЛЮЧЕНИЯ] >> "%LOG_FILE%"
netstat -ano | findstr "ESTABLISHED" >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

echo [ПРОСЛУШИВАЕМЫЕ ПОРТЫ] >> "%LOG_FILE%"
netstat -ano | findstr "LISTENING" | findstr /V "127.0.0.1" >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- СТАТИСТИКА СЕТИ ---
echo [СТАТИСТИКА СЕТЕВОГО ТРАФИКА] >> "%LOG_FILE%"
netstat -e >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- ЗАПУЩЕННЫЕ СЛУЖБЫ ---
echo [ЗАПУЩЕННЫЕ СЛУЖБЫ (Running)] >> "%LOG_FILE%"
powershell -Command "Get-Service | Where-Object {$_.Status -eq 'Running'} | Select-Object Name, DisplayName, Status | Format-Table -AutoSize" >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- ИНФОРМАЦИЯ О БАТАРЕЕ (если есть) ---
echo [ИНФОРМАЦИЯ О ПИТАНИИ] >> "%LOG_FILE%"
powershell -Command "$battery = Get-WmiObject Win32_Battery; if($battery) { Write-Output \"Батарея: $($battery.EstimatedChargeRemaining)% заряда, Статус: $($battery.BatteryStatus)\" } else { Write-Output 'Батарея не обнаружена (стационарный ПК)' }" >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

echo ================================ >> "%LOG_FILE%"
echo Лог сохранён: %LOG_FILE% >> "%LOG_FILE%"
echo Время завершения: %date% %time% >> "%LOG_FILE%"
echo ================================ >> "%LOG_FILE%"

echo.
echo [✓] Лог создан: %LOG_FILE%

REM --- GIT COMMIT ---
echo.
echo ================================
echo GIT COMMIT
echo ================================

REM Проверяем наличие .git
if not exist ".git" (
    echo [X] ОШИБКА: Папка .git не найдена!
    echo [!] Убедитесь, что скрипт находится в Git-репозитории
    pause
    exit /b 1
)

REM Проверяем, установлен ли git
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] ОШИБКА: Git не найден в PATH!
    echo [!] Установите Git или добавьте его в PATH
    pause
    exit /b 1
)

echo [*] Текущая директория: %CD%
echo.

REM Проверяем статус Git
echo [*] Проверяем статус репозитория...
git status
echo.

REM Проверяем конфигурацию Git
echo [*] Проверяем конфигурацию Git...
git config user.name >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Git user.name не настроен, устанавливаем...
    git config user.name "System Logger"
)
git config user.email >nul 2>&1
if %errorlevel% neq 0 (
    echo [!] Git user.email не настроен, устанавливаем...
    git config user.email "logger@localhost"
)

echo Git User: 
git config user.name
git config user.email
echo.

REM Добавляем все изменения
echo [*] Добавляем файлы в индекс...
git add -A
echo Код возврата git add: %errorlevel%
echo.

REM Показываем что добавлено
echo [*] Файлы в индексе:
git diff --cached --name-only
echo.

REM Проверяем, есть ли изменения для коммита
git diff --cached --quiet
if %errorlevel% neq 0 (
    REM Есть изменения, делаем коммит
    set COMMIT_MSG=Auto-commit: System log %timestamp%
    
    echo [*] Создаём коммит с сообщением: !COMMIT_MSG!
    git commit -m "!COMMIT_MSG!"
    set git_result=!errorlevel!
    
    echo Код возврата git commit: !git_result!
    
    if !git_result! equ 0 (
        echo.
        echo [OK] Git коммит выполнен успешно!
        echo [i] Последний коммит:
        git log -1 --oneline
    ) else (
        echo.
        echo [X] Ошибка при создании коммита!
        echo [!] Попробуйте выполнить коммит вручную:
        echo     git add -A
        echo     git commit -m "manual commit"
    )
) else (
    echo [i] Нет изменений для коммита (все файлы уже закоммичены)
)

echo.
echo [✓] Готово! 
timeout /t 5 /nobreak >nul