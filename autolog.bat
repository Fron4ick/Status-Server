@echo off
chcp 1251 >nul
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

REM Начинаем запись в лог
echo ======================================== > "%LOG_FILE%"
echo СИСТЕМНАЯ СТАТИСТИКА >> "%LOG_FILE%"
echo ======================================== >> "%LOG_FILE%"
echo Дата и время: %date% %time% >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM --- ИНФОРМАЦИЯ О СИСТЕМЕ ---
echo [ИНФОРМАЦИЯ О СИСТЕМЕ] >> "%LOG_FILE%"
systeminfo >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- ВРЕМЯ РАБОТЫ СИСТЕМЫ ---
echo [ВРЕМЯ РАБОТЫ СИСТЕМЫ] >> "%LOG_FILE%"
net statistics workstation | find "Статистика с" >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- ЗАГРУЗКА ПРОЦЕССОРА И ПАМЯТИ ---
echo [ИСПОЛЬЗОВАНИЕ РЕСУРСОВ] >> "%LOG_FILE%"
tasklist /v >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- ИНФОРМАЦИЯ О ДИСКАХ ---
echo [ИНФОРМАЦИЯ О ДИСКАХ] >> "%LOG_FILE%"
fsutil volume diskfree c: >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"
echo Все диски: >> "%LOG_FILE%"
wmic logicaldisk get name,size,freespace >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- ЗАПУЩЕННЫЕ ПРОЦЕССЫ (топ по памяти) ---
echo [ТОП-20 ПРОЦЕССОВ ПО ПАМЯТИ] >> "%LOG_FILE%"
tasklist /v /fo csv | find /v "Mem" > "%TEMP%\tasks.csv" 2>&1
for /f "skip=1 tokens=1,5 delims=," %%a in ('type "%TEMP%\tasks.csv" ^| sort /r') do (
    echo %%a %%b >> "%LOG_FILE%"
)
del "%TEMP%\tasks.csv" >nul 2>&1
echo. >> "%LOG_FILE%"

REM --- СЕТЕВЫЕ ПОДКЛЮЧЕНИЯ ---
echo [СЕТЕВЫЕ ИНТЕРФЕЙСЫ] >> "%LOG_FILE%"
ipconfig /all >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

echo [АКТИВНЫЕ СЕТЕВЫЕ ПОДКЛЮЧЕНИЯ] >> "%LOG_FILE%"
netstat -an | findstr /C:"ESTABLISHED" /C:"LISTENING" >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- СТАТИСТИКА СЕТИ ---
echo [СТАТИСТИКА СЕТЕВОГО ТРАФИКА] >> "%LOG_FILE%"
netstat -e >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- СЛУЖБЫ WINDOWS ---
echo [ЗАПУЩЕННЫЕ СЛУЖБЫ] >> "%LOG_FILE%"
sc query state= all | findstr /C:"SERVICE_NAME" /C:"STATE" >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- ДРАЙВЕРЫ ---
echo [ЗАГРУЖЕННЫЕ ДРАЙВЕРЫ] >> "%LOG_FILE%"
driverquery >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- ПОДКЛЮЧЕННЫЕ USB УСТРОЙСТВА ---
echo [USB УСТРОЙСТВА] >> "%LOG_FILE%"
wmic path Win32_USBHub get Description,DeviceID >> "%LOG_FILE%" 2>&1
echo. >> "%LOG_FILE%"

REM --- ТЕМПЕРАТУРА И БАТАРЕЯ (если применимо) ---
echo [ИНФОРМАЦИЯ О ПИТАНИИ] >> "%LOG_FILE%"
powercfg /batteryreport /duration 1 /output "%TEMP%\battery_temp.html" >nul 2>&1
if exist "%TEMP%\battery_temp.html" (
    echo Батарея: Отчет сгенерирован >> "%LOG_FILE%"
    del "%TEMP%\battery_temp.html" >nul 2>&1
) else (
    echo Батарея: Не обнаружена ^(стационарный ПК^) >> "%LOG_FILE%"
)
echo. >> "%LOG_FILE%"

echo ======================================== >> "%LOG_FILE%"
echo Лог успешно создан: %LOG_FILE% >> "%LOG_FILE%"
echo ======================================== >> "%LOG_FILE%"

echo Лог создан: %LOG_FILE%

REM --- GIT COMMIT ---
echo.
echo Выполняется коммит в Git...

REM Проверяем наличие .git
if not exist ".git" (
    echo ОШИБКА: Папка .git не найдена!
    pause
    exit /b 1
)

REM Проверяем, установлен ли git
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo ОШИБКА: Git не найден в PATH!
    pause
    exit /b 1
)

REM Добавляем все изменения
echo Добавляем файлы...
git add -A

REM Проверяем, есть ли изменения
git diff-index --quiet HEAD --
if %errorlevel% neq 0 (
    REM Формируем сообщение коммита
    set COMMIT_MSG=Auto-commit: System log %timestamp%
    
    REM Делаем коммит
    echo Создаём коммит...
    git commit -m "!COMMIT_MSG!"
    
    if !errorlevel! equ 0 (
        echo Git коммит выполнен успешно!
        echo Сообщение: !COMMIT_MSG!
    ) else (
        echo Ошибка при создании коммита!
    )
) else (
    echo Нет изменений для коммита.
)

echo.
echo Готово! Нажмите любую клавишу для выхода...
pause >nul