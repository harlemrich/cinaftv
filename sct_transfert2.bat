@echo off
setlocal

set SERVER=31.220.79.175
set USER=root

echo ----------------------------------------
echo       📦 SCP - Transfert de dossier
echo ----------------------------------------
echo Choisissez une option :
echo 1 - Envoyer un dossier vers le serveur
echo 2 - Télécharger un dossier depuis le serveur
set /p CHOIX=Votre choix (1 ou 2) : 

if "%CHOIX%"=="1" (
    set LOCAL_DIR=C:\Users\user\Desktop\file-server-main
    set REMOTE_DIR=/root/file-server-main

    echo.
    echo 🔧 Création du dossier distant si nécessaire...
    ssh %USER%@%SERVER% "mkdir -p %REMOTE_DIR%"

    echo.
    echo 📂 Transfert en cours...
    echo [DEBUG] LOCAL_DIR = %LOCAL_DIR%
    echo [DEBUG] REMOTE_DIR = %REMOTE_DIR%
    scp -r "%LOCAL_DIR%\." %USER%@%SERVER%:%REMOTE_DIR%

    echo.
    echo 🔍 Vérification sur le serveur distant...
    ssh %USER%@%SERVER% "if [ -d '%REMOTE_DIR%' ]; then echo ✅ Le dossier a bien été transféré dans %REMOTE_DIR%; ls -la %REMOTE_DIR%; else echo ❌ Le dossier n’a pas été trouvé sur le serveur !; fi"

    echo.
    echo 🟢 Fin du transfert.
    pause
    exit /b
)

echo ❌ Option invalide. Fin du script.
pause
exit /b
