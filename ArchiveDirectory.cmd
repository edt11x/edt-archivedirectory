@echo off

TITLE ArchiveAllDirectories

@rem I am not very good at DOS Batch / Command files, so there are probably a lot
@rem more comments in the script than people would normally expect, and possibly
@rem a lot more mistakes.

@rem Setlocal EnableDelayedExpansion is needed for this and probably most batch and
@rem command files. Normally the variables are set when the script is read, not when
@rem the line is executed, which is what I would normally expect. So I think, for
@rem almost any batch or command file I write, I want "Setlocal EnableDelayedExpansion".
Setlocal EnableDelayedExpansion

@rem This mimics my archivedirectory Linux shell script, but in a Command/Batch file
@rem syntax. It does require that 7-Zip, Par2 and GPG are installed on the Windows
@rem machine and available in the path. All three of those utilities do not require
@rem formal installation. They can be placed in a directory and have the path updated.
@rem
@rem This is still a work in progress.

GOTO start

:die
GOTO usage

:usage
@echo off
echo Usage: archivedirectory [-d dest_dir] [-p prefix] [-e] -a dir_to_archive
exit /b 1

:man
@echo off
@echo NAME
@echo     archivedirectory - archive the specified directory
@echo.
@echo SYNOPSIS
@echo     archivedirectory [-d dest_dir] [-p prefix] [-e] -a dir_to_archive
@echo.
@echo     -a directory_to_archive -- specify the directory to archive
@echo     -d directory -- specify the destination dir to place the archive
@echo     -p prefix -- set a prefix to be prepended on the archive
@echo     -e -- encrypt the archive, otherwise just 7z and generate forward ECC
@echo.
@echo DESCRIPTION
@echo.
@echo This script archives a directory. A couple of goals for this:
@echo.
@echo     * Create archives that can be extracted across Windwos, Mac and Linux
@echo     * Encrypt the data at rest
@echo     * Provide some level of corruption resistance
@echo.
@echo Originally, I used tar as the default base archiver across Windows,
@echo Mac and Linux. Unfortunately, tar is not as well suppored on Windows
@echo as it is on other OSs. After some bumps in the road, I finally
@echo gave in and decided that 7zip would be the default archive utililty
@echo on Windows and tar would be the default on Mac OS and Linux. 7zip
@echo is well supported on Windows and has good support on Linux and Mac OS.
@echo "tar" is universally supported on Linux and Mac OS, and is supported
@echo on Windows, with some limitations.
@echo.
@echo The 7-Zip file format is largely portable across Windows, Mac and Linux.
@echo I have had problems extracting complicated zip archives on Linux,
@echo finding that I could not extract some directories or files. Zip files
@echo abillity to correctly restore file attributes like ownership and mode
@echo is also less supported on Linux. With all the malware,
@echo comprimises, etc. I think all data needs to be encrypted at rest. You
@echo can not know if a computer or network has been comprimised. The F-35,
@echo OPM, and Anthem data breaches are all good examples. Also, people lose
@echo thumb drives and computers all the time. GPG is widely available and
@echo known for good encryption and is available across Windows, Mac, and
@echo Linux. As for corruption resistance, I have a large number of computers
@echo that I deal with and two that are actively used, one Windows 7 and one
@echo Linux, are corrupting sectors at a very low rate, low enough on the
@echo Windows 7 box that the sysadmins do not care. Yet blocks in the middle
@echo of large text files are being replaced with all 0xFFs. To address this
@echo forward error correction is done after archiving, compressing and
@echo encrypting. For forward error correction, I used the the par2 command
@echo line tool. It is well understood and works across Windows, Mac and
@echo Linux.
@echo.
@echo This windows command script bails out if any command returns a failure.
@echo If I am creating an encrypted archive, I want to know all steps were
@echo successful.
@echo.
@echo EXAMPLES
@echo.
@echo     C> archivedirectory -d \mybackups -e -a .\directory_to_archive
@echo.
@echo This will create a time and date stamped directory in \mybackups that
@echo includes the original name, in that directory will be the gpg
@echo encrypted compressed tar file and the par2 recovery files. par2 is set
@echo at 100 percent. This script will append to a file called
@echo "archive_list" in the chosen backup directory, \mybackups in this
@echo example a line with the name of the encrypted archive and the
@echo password. The user needs to manually backup these passwords in a safe
@echo place, such as a password vault.
@echo.
exit /b 1

@rem This is probably my fourth attempt at a mechanism to decide if a
@rem file system entity is a directory or not. Simpler methods do not
@rem correctly detect directories on some network shares.
:sub_check_if_dir
set IS_A_DIR=NO
for /f "tokens=1,2 delims=d" %%A in ("-%~a1") do if "%%B" neq "" (
  echo %1 is a folder
  set IS_A_DIR=YES
) else if "%%A" neq "-" (
  echo %1 is a file
) else (
  echo %1 does not exist
)
exit /B

:start
@rem We will print a banner so we know we are alive
echo ============================
echo === ArchiveDirectory.cmd ===
echo ============================
set ENCRYPT_ARCHIVE=0
set ARCHIVE_TO=%USERPROFILE%\files\backups
set ARCHIVE_FROM=""
set ARCHIVE_PREFIX=

@rem There has to be at least one argument
if "%1"=="" goto usage

@rem get the arguments
:argloop
IF NOT "%1"=="" (
    IF "%1"=="-a" (
        set ARCHIVE_FROM=%2
        SHIFT
        SHIFT
    )
    IF "%1"=="-d" (
        set ARCHIVE_TO=%2
        SHIFT
        SHIFT
    )
    IF "%1"=="-p" (
        set ARCHIVE_PREFIX=%2_
        SHIFT
        SHIFT
    )
    IF "%1"=="-e" (
        set ENCRYPT_ARCHIVE=1
        SHIFT
    )
    IF "%1"=="-h" (
        goto man
    )
    GOTO :ARGLOOP
)

@rem Let them pass a double quoted directory so that it ends up as one
@rem variable, but then strip the beginning and ending double quotes from
@rem the variable for easier processing.
SET ARCHIVE_FROM=######%ARCHIVE_FROM%######
SET ARCHIVE_FROM=%ARCHIVE_FROM:"######=%
SET ARCHIVE_FROM=%ARCHIVE_FROM:######"=%
SET ARCHIVE_FROM=%ARCHIVE_FROM:######=%

@rem Directory to archive can not be blank or only spaces.
SET CHECK_FROM=!ARCHIVE_FROM!
SET CHECK_FROM=!CHECK_FROM: =!

IF [%CHECK_FROM%] == [] (
    echo Need to specify a directory to archive
    GOTO :die
)

set hour=%time:~0,2%
if "%hour:~0,1%" == " " set hour=0%hour:~1,1%
set min=%time:~3,2%
if "%min:~0,1%" == " " set min=0%min:~1,1%
set secs=%time:~6,2%
if "%secs:~0,1%" == " " set secs=0%secs:~1,1%
set year=%date:~-4%
set month=%date:~-10,2%
if %month:~0,1% == " " set month=0%month:~1,1%
set day=%date:~-7,2%
if %day:~0,1% == " " set day=0%day:~1,1%

@rem remove any trailing slash
IF %ARCHIVE_FROM:~-1%==\ SET ARCHIVE_FROM=%ARCHIVE_FROM:~0,-1%
set ARCHIVE_BASE=%ARCHIVE_PREFIX%%ARCHIVE_FROM%_%COMPUTERNAME%_%year%%month%%day%_%hour%_%min%_%secs%
set ARCHIVE_NAME=%ARCHIVE_BASE%.7z
set ARCHIVE_TO_DIR=%ARCHIVE_TO%\%ARCHIVE_BASE%
set ARCHIVE_FULL_PATH=%ARCHIVE_TO_DIR%\%ARCHIVE_NAME%

echo ARCHIVE_BASE - %ARCHIVE_BASE%
echo ARCHIVE_NAME - %ARCHIVE_NAME%
echo ARCHIVE_FROM - %ARCHIVE_FROM%

IF EXIST "%ARCHIVE_FROM%" GOTO havedir
echo Need to specify a directory to archive, %ARCHIVE_FROM% is not a directory
GOTO :die
:havedir

@rem Now we need to generate a password, whether or not we are going to use it.
@rem We will do it regardless just to simplify the batch file and the indentation.
@rem This part of the script is taken from a Stack Overflow question
@rem http://superuser.com/questions/349474/how-do-you-make-a-letter-password-generator-in-batch

@rem set the length of the password
Set _RNDLength=63
@rem If you just use alphanumeric characters, A-Z, a-z, 0-9, the full password
@rem can be selected in most GUI environments by double clicking on it.
@rem If we add in other characters, you get into states where the password
@rem can not be easily selected without multiple operations.
@rem list of possible characters in the password
Set _Alphanumeric=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789
@rem concatenate 987654321 to the end of the possible characters
Set _Str=%_Alphanumeric%987654321
@rem start of loop to generate the password
:_LenLoop
IF NOT "%_Str:~18%"=="" SET _Str=%_Str:~9%& SET /A _Len+=9& GOTO :_LenLoop
SET _tmp=%_Str:~9,1%
SET /A _Len=_Len+_tmp
Set _count=0
SET _RndAlphaNum=
:_loop
Set /a _count+=1
SET _RND=%Random%
Set /A _RND=_RND%%%_Len%
SET _RndAlphaNum=!_RndAlphaNum!!_Alphanumeric:~%_RND%,1!
If !_count! lss %_RNDLength% goto _loop
Echo Random string is !_RndAlphaNum!

if %ENCRYPT_ARCHIVE% == 0 GOTO no_encrypt
    set ARCHIVE_LIST=%ARCHIVE_TO%\archive_list
    set ARCHIVE_GPG=%ARCHIVE_FULL_PATH%.gpg
    set ARCHIVE_PAR2=%ARCHIVE_GPG%.par2
    set ARCHIVE_PASSWD=%_RndAlphaNum%
    GOTO done_encrypt

:no_encrypt
    set ARCHIVE_PAR2=%ARCHIVE_FULL_PATH%.par2
    GOTO done_encrypt

:done_encrypt

echo.
echo Checking main archive directory %ARCHIVE_TO%
@rem recursively create the place to archive the directory
@rem The Windows "mkdir" automatically creates any parts of
@rem the path that do not exist.
CALL :sub_check_if_dir "%ARCHIVE_TO%"
IF %IS_A_DIR%==YES (
    goto arc_to_dir
) ELSE (
    echo Creating the main archive directory %ARCHIVE_TO%
    mkdir "%ARCHIVE_TO%"
)
@rem check to make sure that the directory was created.
@rem This is a Windows trick to find out if a directory exists.
@rem We are looking for the Windows NUL device, basically an
@rem equivalent of /dev/null in Linux. However, for whatever
@rem strange reason, we can look for it in any directory.
@rem Seems weird, but we use this to check to see if the
@rem directory exists. And.. the trick does not work on the
@rem network.
CALL :sub_check_if_dir "%ARCHIVE_TO%"
IF %IS_A_DIR%==YES (
    goto arc_to_dir
) ELSE (
    Echo Directory to archive to does not exist
    goto die
)

:arc_to_dir
@rem recursively create the archive to directory
echo.
echo Attempting to create the new archive directory %ARCHIVE_TO_DIR%
mkdir "%ARCHIVE_TO_DIR%"
CALL :sub_check_if_dir "%ARCHIVE_TO_DIR%"
IF %IS_A_DIR%==YES (
    goto chk_full_path
) ELSE (
    Echo Can not create %ARCHIVE_TO_DIR%
    goto die
)

:chk_full_path
echo.
echo Checking full path %ARCHIVE_FULL_PATH%
IF EXIST "%ARCHIVE_FULL_PATH%" (
    Echo Archive %ARCHIVE_FULL_PATH% already exists
    goto die
) ELSE (
    goto chk_par2
)

:chk_par2
IF EXIST "%ARCHIVE_PAR2%" (
    Echo Archive PAR2 %ARCHIVE_PAR2% already exists
    goto die
) ELSE (
    goto run_7z
)

:run_7z
@rem
@rem Some explanations of the 7zip command line
@rem
@rem -m0=lzma2, switch to the LZMA2 algorithm, this is known to give good compression.
@rem            Many will argue the merits of the different algorithms, LZMA2 is one
@rem            of the respected algorithms.
@rem
@rem            From:
@rem            http://stackoverflow.com/questions/3057171/lzma-compression-settings-details
@rem
@rem            LZMA2 is modified version of LZMA. It provides the following advantages
@rem            over LZMA:
@rem
@rem            1. Better compression ratio for data than can't be compressed. LZMA2
@rem               can store such blocks of data in uncompressed form. Also it decompresses
@rem               such data faster.
@rem            2. Better multithreading support. If you compress big file, LZMA2 can
@rem               split that file to chunks and compress these chunks in multiple threads. 
@rem
@rem            Note: LZMA2 also supports all LZMA parameters, but lp + lc cannot be
@rem            larger than 4.
@rem
@rem -mx=9      Set the level of compression to 9 or Ultra. Compression vs. Time trade
@rem            off variable. -mx=9 often referred to as Ultra compression.
@rem -mfb=273   The number of fast bytes. 273 is the maximum values found in examples.
@rem            Bigger numbers provide slightly better compression strength at the
@rem            expense of longer compression time. A bigger value of the fast bytes
@rem            parameter can slightly increase compression ratio when files being
@rem            compressed contain long identical sequences of bytes.
@rem -ms=on     Solid Archive. In solid mode, files are grouped together. Usually,
@rem            compressing in solid mode improves the compression ratio. In solid
@rem            mode, replacing a file, may mean decompressing and re-compressing
@rem            multiple files. Additional syntax on this command allows you to
@rem            specify the file grouping. For example, you may chose to group up
@rem            to one hundred 10 Mbyte files together.
@rem -md=128M   The dictionary size. The maximum size of the dictionary in the 32 bit
@rem            version of 7zip is 128 Mbytes, so we set that value.
@rem -mmc=1000  Set the number of match cycles
echo.
echo Run 7zip
echo 7z a -m0=lzma2 -mx=9 -mfb=273 -ms=on -md=128M -mmc=1000 "%ARCHIVE_FULL_PATH%" "%ARCHIVE_FROM%"
7z a -m0=lzma2 -mx=9 -mfb=273 -ms=on -md=128M -mmc=1000 "%ARCHIVE_FULL_PATH%" "%ARCHIVE_FROM%"
if errorlevel 1 (
    Echo 7z a -m0=lzma2 -mx=9 -mfb=273 -ms=on -md=128M -mmc=1000 %ARCHIVE_FULL_PATH% %ARCHIVE_FROM% was unsuccessful
    goto die
) ELSE (
    goto make_readme
)

:make_readme
cd /d "%ARCHIVE_TO_DIR%"
if %ENCRYPT_ARCHIVE% == 0 GOTO no_enc2

IF EXIST "%ARCHIVE_GPG%" (
    Echo Archive GPG %ARCHIVE_GPG% already exists
    goto die
) ELSE (
    goto readme
)

:readme

Echo This directory contains files and/or directories that have been archived with > "%ARCHIVE_TO_DIR%\README.txt"
Echo encryption and forward error correction. The files have been archived with 7z, >> "%ARCHIVE_TO_DIR%\README.txt"
Echo compressed and encrypted with GPG. Forward error >> "%ARCHIVE_TO_DIR%\README.txt"
Echo correction is applied using PAR2. PAR2 is the old Usenet parity 2 format, which >> "%ARCHIVE_TO_DIR%\README.txt"
Echo provides protection against bit rot. This seems to be a way to portably archive >> "%ARCHIVE_TO_DIR%\README.txt"
Echo data across Windows, MacOS and Linux, even older versions of Linux. To restore >> "%ARCHIVE_TO_DIR%\README.txt"
Echo the files, the command line will be: >> "%ARCHIVE_TO_DIR%\README.txt"
Echo. >> "%ARCHIVE_TO_DIR%\README.txt"
Echo gpg --decrypt "%ARCHIVE_GPG%" ^| 7z x -si >> "%ARCHIVE_TO_DIR%\README.txt"
Echo. >> "%ARCHIVE_TO_DIR%\README.txt"
Echo You can check the archives integrity with: >> "%ARCHIVE_TO_DIR%\README.txt"
Echo. >> "%ARCHIVE_TO_DIR%\README.txt"
Echo par2 verify "%ARCHIVE_PAR2%" >> "%ARCHIVE_TO_DIR%\README.txt"
Echo. >> "%ARCHIVE_TO_DIR%\README.txt"

@rem we do not want to store the password until it is likely
@rem that we will create the encrypted archive
Echo %ARCHIVE_GPG% %ARCHIVE_PASSWD% >> %ARCHIVE_LIST%
cd /d "%ARCHIVE_TO_DIR%"

echo.
echo Run GPG to encrypt the archive
echo gpg --batch --passphrase %ARCHIVE_PASSWD% --cipher-algo AES256 --symmetric "%ARCHIVE_NAME%"
gpg --batch --passphrase %ARCHIVE_PASSWD% --cipher-algo AES256 --symmetric "%ARCHIVE_NAME%"
if errorlevel 1 (
    Echo GPG encryption failed
    goto die
) ELSE (
    goto par2
)

:par2
echo.
echo Run PAR2 to create the forward error correction
echo par2 create -r100 "%ARCHIVE_GPG%"
par2 create -r100 "%ARCHIVE_GPG%"
if errorlevel 1 (
    Echo PAR2 generation failed
    goto die
) ELSE (
    goto par2_verify
)

:par2_verify
echo.
echo Verify the forward error correction
par2 verify "%ARCHIVE_PAR2%"
if errorlevel 1 (
    Echo PAR2 verification failed
    goto die
) ELSE (
    goto gpg_verify
)

:gpg_verify
echo.
echo Verify the created GPG file
IF EXIST tmp.7z del tmp.7z
cd /d "%ARCHIVE_TO_DIR%"
gpg --batch --passphrase %ARCHIVE_PASSWD% --decrypt "%ARCHIVE_GPG%" > tmp.7z
7z l tmp.7z
if errorlevel 1 (
    Echo Archive verification failed
    goto die
) ELSE (
    goto arc_verified
)

:arc_verified
IF EXIST tmp.7z del tmp.7z
echo.
echo Delete the .7z file
echo del "%ARCHIVE_FULL_PATH%"
del "%ARCHIVE_FULL_PATH%"

goto done

@rem This is the case, where we are not going to encrypt the archive, just 7z it and apply the forward error correction.
@rem We are creating a readme that does not refer to the encryption.
:no_enc2

Echo This directory contains files and/or directories that have been archived with >> "%ARCHIVE_TO_DIR%\README.txt"
Echo 7z and forward error correction.  Forward error correction is applied using >> "%ARCHIVE_TO_DIR%\README.txt"
Echo PAR2. PAR2 is the old Usenet parity 2 format, which provides protection against >> "%ARCHIVE_TO_DIR%\README.txt"
Echo bit rot. This seems to be a way to portably archive data across Windows, MacOS >> "%ARCHIVE_TO_DIR%\README.txt"
Echo and Linux, even older versions of Linux. To restore the files, the command line >> "%ARCHIVE_TO_DIR%\README.txt"
Echo will be: >> "%ARCHIVE_TO_DIR%\README.txt"
Echo. >> "%ARCHIVE_TO_DIR%\README.txt"
Echo 7z x "%ARCHIVE_FULL_PATH%" >> "%ARCHIVE_TO_DIR%\README.txt"
Echo. >> "%ARCHIVE_TO_DIR%\README.txt"
Echo You can check the archives integrity with: >> "%ARCHIVE_TO_DIR%\README.txt"
Echo. >> "%ARCHIVE_TO_DIR%\README.txt"
Echo par2 verify "%ARCHIVE_PAR2%" >> "%ARCHIVE_TO_DIR%\README.txt"
Echo. >> "%ARCHIVE_TO_DIR%\README.txt"

par2 create -r100 "%ARCHIVE_FULL_PATH%"
if errorlevel 1 (
    Echo Par2 creation failed
    goto die
) ELSE (
    goto par2_ver2
)

:par2_ver2
par2 verify "%ARCHIVE_PAR2%"
if errorlevel 1 (
    Echo Par2 verification failed
    goto die
) ELSE (
    goto done
)

:done
Echo.
Echo Completed Successfully.
exit /b 0

