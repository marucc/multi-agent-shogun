@echo off
chcp 932 >nul 2>&1
title multi-agent-shogun Installer

echo.
echo   +============================================================+
echo   |  [SHOGUN] multi-agent-shogun - Auto Installer              |
echo   |           �S�����Z�b�g�A�b�v                               |
echo   +============================================================+
echo.

REM ===== Step 1: Check/Install WSL2 =====
echo   [1/4] Checking WSL2...
echo         WSL2 �m�F��...

wsl.exe --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo   WSL2 not found. Installing automatically...
    echo   WSL2 ��������܂���B�����C���X�g�[����...
    echo.

    REM �Ǘ��Ҍ����Ŏ��s����Ă��邩�m�F
    net session >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo   +============================================================+
        echo   |  [WARN] Administrator privileges required!                 |
        echo   |         �Ǘ��Ҍ������K�v�ł�                               |
        echo   +============================================================+
        echo.
        echo   Right-click install.bat and select "Run as administrator"
        echo   install.bat ���E�N���b�N���u�Ǘ��҂Ƃ��Ď��s�v
        echo.
        pause
        exit /b 1
    )

    echo   Installing WSL2...
    wsl --install --no-launch

    echo.
    echo   +============================================================+
    echo   |  [!] Restart required!                                     |
    echo   |      �ċN�����K�v�ł�                                      |
    echo   +============================================================+
    echo.
    echo   After restart, run install.bat again.
    echo   �ċN����A������x install.bat �����s���Ă��������B
    echo.
    pause
    exit /b 0
)
echo   [OK] WSL2 OK
echo.

REM ===== Step 2: Check/Install Ubuntu =====
echo   [2/4] Checking Ubuntu...
echo         Ubuntu �m�F��...

REM Ubuntu check: use -d Ubuntu directly (avoids UTF-16LE pipe issue with findstr)
wsl.exe -d Ubuntu -- echo test >nul 2>&1
if %ERRORLEVEL% EQU 0 goto :ubuntu_ok

REM echo test failed - check if Ubuntu distro exists but needs initial setup
wsl.exe -d Ubuntu -- exit 0 >nul 2>&1
if %ERRORLEVEL% EQU 0 goto :ubuntu_needs_setup

REM Ubuntu not installed
echo.
echo   Ubuntu not found. Installing automatically...
echo   Ubuntu ��������܂���B�����C���X�g�[����...
echo.

wsl --install -d Ubuntu --no-launch

echo.
echo   +============================================================+
echo   |  [NOTE] Ubuntu initial setup required!                     |
echo   |         Ubuntu �̏����ݒ肪�K�v�ł�                        |
echo   +============================================================+
echo.
echo   1. Open Ubuntu from Start Menu
echo      �X�^�[�g���j���[���� Ubuntu ���J��
echo.
echo   2. Set your username and password
echo      ���[�U�[���ƃp�X���[�h��ݒ�
echo.
echo   3. Run install.bat again
echo      ������x install.bat �����s
echo.
pause
exit /b 0

:ubuntu_needs_setup
REM Ubuntu exists but initial setup not completed
echo.
echo   +============================================================+
echo   |  [WARN] Ubuntu initial setup required!                     |
echo   |         Ubuntu �̏����ݒ肪�K�v�ł�                        |
echo   +============================================================+
echo.
echo   1. Open Ubuntu from Start Menu
echo      �X�^�[�g���j���[�ŁuUbuntu�v���������ĊJ��
echo.
echo   2. Set your username and password
echo      ���[�U�[���ƃp�X���[�h��ݒ�
echo.
echo   3. Run install.bat again
echo      ������x install.bat �����s
echo.
pause
exit /b 1

:ubuntu_ok
echo   [OK] Ubuntu OK
echo.

REM ===== Step 3: Get script path for WSL =====
echo   [3/4] Preparing WSL path...
echo         WSL �p�X������...

REM wslpath ���g���Đ��m�Ƀp�X�ϊ�
set "WSL_PATH="
for /f "usebackq tokens=*" %%a in (`wsl.exe -d Ubuntu wslpath -u "%~dp0" 2^>nul`) do set "WSL_PATH=%%a"

REM wslpath �����s�����ꍇ�̃t�H�[���o�b�N
if defined WSL_PATH goto :wslpath_done
set "WSL_PATH=%~dp0"
set "WSL_PATH=%WSL_PATH:\=/%"
REM Drive letter to WSL mount path (A-Z, case-insensitive)
for %%d in (a b c d e f g h i j k l m n o p q r s t u v w x y z) do (
    call set "WSL_PATH=%%WSL_PATH:%%d:=/mnt/%%d%%"
)
:wslpath_done

REM �����̃X���b�V�����폜
if "%WSL_PATH:~-1%"=="/" set "WSL_PATH=%WSL_PATH:~0,-1%"

echo   [OK] Path: %WSL_PATH%
echo.

REM ===== Step 4: Run first_setup.sh =====
echo   [4/4] Running first_setup.sh...
echo         first_setup.sh ���s��...
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
echo   |       �C���X�g�[������!                                    |
echo   +============================================================+
echo.
echo   +------------------------------------------------------------+
echo   |  [START] NEXT: Start the system                            |
echo   |          ���̃X�e�b�v: �V�X�e���N��                        |
echo   +------------------------------------------------------------+
echo   |                                                            |
echo   |  Open WSL terminal and run:                                |
echo   |  WSL �^�[�~�i�����J���Ď��s:                               |
echo   |                                                            |
echo   |    cd "%WSL_PATH%"
echo   |    ./shutsujin_departure.sh                                |
echo   |                                                            |
echo   +------------------------------------------------------------+
echo.
pause
exit /b 0
