@echo off
cd /d "%~dp0"
echo ============================================================
echo  Umfrage-Zentrale wird gestartet. Gleich oeffnet sich dein Browser.
echo  Dieses Fenster offen lassen, solange du testest.
echo  Zum Beenden: Fenster schliessen.
echo ============================================================
start "" /min cmd /c "timeout /t 2 >nul & start http://localhost:8766/zentrale.html"
python -m http.server 8766 2>nul || py -m http.server 8766
pause
