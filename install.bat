@echo off
chcp 65001 >nul 2>&1
title multi-agent-shogun Installer

echo.
echo   +============================================================+
echo   |  [SHOGUN] multi-agent-shogun - Auto Installer              |
echo   |           全自動セットアップ                               |
echo   +============================================================+
echo.

REM ===== Step 1: Check/Install WSL2 =====
echo   [1/4] Checking WSL2...
echo         WSL2 確認中...

wsl.exe --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo   WSL2 not found. Installing automatically...
    echo   WSL2 が見つかりません。自動インストール中...
    echo.

    REM 管理者権限で実行されているか確認
    net session >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo   +============================================================+
        echo   |  [WARN] Administrator privileges required!                 |
        echo   |         管理者権限が必要です                               |
        echo   +============================================================+
        echo.
        echo   Right-click install.bat and select "Run as administrator"
        echo   install.bat を右クリック→「管理者として実行」
        echo.
        pause
        exit /b 1
    )

    echo   Installing WSL2...
    wsl --install --no-launch

    echo.
    echo   +============================================================+
    echo   |  [!] Restart required!                                     |
    echo   |      再起動が必要です                                      |
    echo   +============================================================+
    echo.
    echo   After restart, run install.bat again.
    echo   再起動後、もう一度 install.bat を実行してください。
    echo.
    pause
    exit /b 0
)
echo   [OK] WSL2 OK
echo.

REM ===== Step 2: Check/Install Ubuntu =====
echo   [2/4] Checking Ubuntu...
echo         Ubuntu 確認中...

REM Ubuntu check: use -d Ubuntu directly (avoids UTF-16LE pipe issue with findstr)
wsl.exe -d Ubuntu -- echo test >nul 2>&1
if %ERRORLEVEL% EQU 0 goto :ubuntu_ok

REM echo test failed - check if Ubuntu distro exists but needs initial setup
wsl.exe -d Ubuntu -- exit 0 >nul 2>&1
if %ERRORLEVEL% EQU 0 goto :ubuntu_needs_setup

REM Ubuntu not installed
echo.
echo   Ubuntu not found. Installing automatically...
echo   Ubuntu が見つかりません。自動インストール中...
echo.

wsl --install -d Ubuntu --no-launch

echo.
echo   +============================================================+
echo   |  [NOTE] Ubuntu initial setup required!                     |
echo   |         Ubuntu の初期設定が必要です                        |
echo   +============================================================+
echo.
echo   1. Open Ubuntu from Start Menu
echo      スタートメニューから Ubuntu を開く
echo.
echo   2. Set your username and password
echo      ユーザー名とパスワードを設定
echo.
echo   3. Run install.bat again
echo      もう一度 install.bat を実行
echo.
pause
exit /b 0

:ubuntu_needs_setup
REM Ubuntu exists but initial setup not completed
echo.
echo   +============================================================+
echo   |  [WARN] Ubuntu initial setup required!                     |
echo   |         Ubuntu の初期設定が必要です                        |
echo   +============================================================+
echo.
echo   1. Open Ubuntu from Start Menu
echo      スタートメニューで「Ubuntu」を検索して開く
echo.
echo   2. Set your username and password
echo      ユーザー名とパスワードを設定
echo.
echo   3. Run install.bat again
echo      もう一度 install.bat を実行
echo.
pause
exit /b 1

:ubuntu_ok
echo   [OK] Ubuntu OK
echo.

REM ===== Step 3: Get script path for WSL =====
echo   [3/4] Preparing WSL path...
echo         WSL パス準備中...

REM wslpath を使って正確にパス変換
set "WSL_PATH="
for /f "usebackq tokens=*" %%a in (`wsl.exe -d Ubuntu wslpath -u "%~dp0" 2^>nul`) do set "WSL_PATH=%%a"

REM wslpath が失敗した場合のフォールバック
if defined WSL_PATH goto :wslpath_done
set "WSL_PATH=%~dp0"
set "WSL_PATH=%WSL_PATH:\=/%"
REM Drive letter to WSL mount path (A-Z, case-insensitive)
for %%d in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do (
    call set "WSL_PATH=%%WSL_PATH:%%d:=/mnt/%%d%%"
)
:wslpath_done

REM 末尾のスラッシュを削除
if "%WSL_PATH:~-1%"=="/" set "WSL_PATH=%WSL_PATH:~0,-1%"

echo   [OK] Path: %WSL_PATH%
echo.

REM ===== Step 4: Run first_setup.sh =====
echo   [4/4] Running first_setup.sh...
echo         first_setup.sh 実行中...
echo.

REM Set Ubuntu as default WSL distribution
wsl --set-default Ubuntu

wsl.exe -d Ubuntu -- bash -c "cd \"%WSL_PATH%\" && chmod +x *.sh && ./first_setup.sh"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo   +============================================================+
    echo   |  [NG] Setup failed!                                        |
    echo   +============================================================+
    echo.
    pause
    exit /b 1
)

echo.
echo   +============================================================+
echo   |  [OK] Installation completed!                              |
echo   |       インストール完了！                                    |
echo   +============================================================+
echo.
echo   +------------------------------------------------------------+
echo   |  [START] NEXT: Start the system                            |
echo   |          次のステップ: システム起動                        |
echo   +------------------------------------------------------------+
echo   |                                                            |
echo   |  Open WSL terminal and run:                                |
echo   |  WSL ターミナルを開いて実行:                               |
echo   |                                                            |
echo   |    cd "%WSL_PATH%"
echo   |    ./shutsujin_departure.sh                                |
echo   |                                                            |
echo   +------------------------------------------------------------+
echo.
pause
exit /b 0
