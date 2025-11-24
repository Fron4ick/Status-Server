@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM Ждем 60 секунд после запуска
timeout /t 60 /nobreak >nul

REM Получаем текущую дату и время для имени файла
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set LOG_DATE=%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2%
set LOG_TIME=%datetime:~8,2%-%datetime:~10,2%-%datetime:~12,2%
set LOG_FILENAME=system_log_%LOG_DATE%_%LOG_TIME%.txt

REM Определяем путь к папке logs
set SCRIPT_DIR=%~dp0
set LOG_DIR=%SCRIPT_DIR%logs
set LOG_FILE=%LOG_DIR%\%LOG_FILENAME%

REM Создаем папку logs если её нет
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM Начинаем запись логов
echo ================================================ > "%LOG_FILE%"
echo SYSTEM STATISTICS LOG >> "%LOG_FILE%"
echo Generated: %LOG_DATE% %LOG_TIME:~0,2%:%LOG_TIME:~3,2%:%LOG_TIME:~6,2% >> "%LOG_FILE%"
echo ================================================ >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM Информация о системе
echo [SYSTEM INFORMATION] >> "%LOG_FILE%"
echo ------------------------------ >> "%LOG_FILE%"
systeminfo | findstr /C:"OS Name" /C:"OS Version" /C:"System Type" /C:"Total Physical Memory" /C:"Available Physical Memory" /C:"System Boot Time" >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM Время работы системы
echo [SYSTEM UPTIME] >> "%LOG_FILE%"
echo ------------------------------ >> "%LOG_FILE%"
wmic os get lastbootuptime /value >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM Использование процессора
echo [CPU USAGE] >> "%LOG_FILE%"
echo ------------------------------ >> "%LOG_FILE%"
wmic cpu get name,loadpercentage /value >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM Использование памяти
echo [MEMORY USAGE] >> "%LOG_FILE%"
echo ------------------------------ >> "%LOG_FILE%"
wmic OS get FreePhysicalMemory,TotalVisibleMemorySize /value >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM Состояние дисков
echo [DISK USAGE] >> "%LOG_FILE%"
echo ------------------------------ >> "%LOG_FILE%"
wmic logicaldisk get name,size,freespace,filesystem >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM Запущенные процессы (топ по памяти)
echo [TOP PROCESSES BY MEMORY] >> "%LOG_FILE%"
echo ------------------------------ >> "%LOG_FILE%"
wmic process get name,processid,workingsetsize /format:csv | sort /r | findstr /v "^$" | more +1 > "%LOG_DIR%\temp_processes.txt"
set count=0
for /f "tokens=*" %%a in (%LOG_DIR%\temp_processes.txt) do (
    set /a count+=1
    if !count! leq 20 echo %%a >> "%LOG_FILE%"
)
del "%LOG_DIR%\temp_processes.txt"
echo. >> "%LOG_FILE%"

REM Сетевые подключения
echo [NETWORK CONNECTIONS] >> "%LOG_FILE%"
echo ------------------------------ >> "%LOG_FILE%"
netstat -ano | findstr ESTABLISHED >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM Сетевые интерфейсы и IP адреса
echo [NETWORK INTERFACES] >> "%LOG_FILE%"
echo ------------------------------ >> "%LOG_FILE%"
ipconfig /all | findstr /C:"Ethernet adapter" /C:"Wireless" /C:"IPv4" /C:"Default Gateway" /C:"DHCP" >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM Статистика сетевого трафика
echo [NETWORK STATISTICS] >> "%LOG_FILE%"
echo ------------------------------ >> "%LOG_FILE%"
netstat -e >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM Службы (только запущенные)
echo [RUNNING SERVICES] >> "%LOG_FILE%"
echo ------------------------------ >> "%LOG_FILE%"
sc query state= all | findstr /C:"SERVICE_NAME" /C:"RUNNING" >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM Запланированные задачи (активные)
echo [SCHEDULED TASKS] >> "%LOG_FILE%"
echo ------------------------------ >> "%LOG_FILE%"
schtasks /query /fo LIST | findstr /C:"TaskName" /C:"Next Run Time" /C:"Status" | findstr /v "Disabled" >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

REM Последние события из журнала (ошибки и предупреждения)
echo [RECENT SYSTEM EVENTS - ERRORS] >> "%LOG_FILE%"
echo ------------------------------ >> "%LOG_FILE%"
wevtutil qe System /c:10 /rd:true /f:text /q:"*[System[(Level=2)]]" >> "%LOG_FILE%" 2>nul
echo. >> "%LOG_FILE%"

echo [RECENT SYSTEM EVENTS - WARNINGS] >> "%LOG_FILE%"
echo ------------------------------ >> "%LOG_FILE%"
wevtutil qe System /c:10 /rd:true /f:text /q:"*[System[(Level=3)]]" >> "%LOG_FILE%" 2>nul
echo. >> "%LOG_FILE%"

echo ================================================ >> "%LOG_FILE%"
echo LOG COMPLETED >> "%LOG_FILE%"
echo ================================================ >> "%LOG_FILE%"

REM Git коммит
cd /d "%SCRIPT_DIR%"
git add logs/%LOG_FILENAME%
git commit -m "Auto-log: System statistics %LOG_DATE% %LOG_TIME%"

Опционально: отправка в удалённый репозиторий
git push origin main

echo Log created: %LOG_FILE%
echo Git commit completed.

endlocal