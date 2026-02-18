# ===============================================================
# auto-backup.ps1
# Enviar archivos .bkp al NAS como ZIP usando robocopy (sin mapear drive)
# Notificación por correo y Telegram SOLO si hay errores
# ===============================================================

$SourcePath = ""  # Carpeta con archivos .bkp
$TempZipDir = ""
$NasPath    = ""
$NasUser    = ""
$NasPass    = ""

# ================= LOG =================
$LogFolder = "C:\Scripts\logs"
if (-not (Test-Path $LogFolder)) { New-Item -ItemType Directory -Path $LogFolder | Out-Null }
$FechaActual = Get-Date
$LogFile     = Join-Path $LogFolder ("log-backup-bkp-{0:yyyyMMdd}.txt" -f $FechaActual)

function Log {
    param([string]$msg)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
    Add-Content -Path $LogFile -Value $line
    Write-Host $msg
}

# ================= SMTP =================
$SmtpServer = ""
$MailFrom   = ""
$MailTo     = ""

function Send-Mail {
    param ([string]$Subject, [string]$Body)
    Send-MailMessage `
        -From $MailFrom `
        -To $MailTo `
        -Subject $Subject `
        -Body $Body `
        -BodyAsHtml `
        -SmtpServer $SmtpServer `
        -Port 25 `
        -Encoding UTF8
}

# ================= TELEGRAM =================
$TelegramBotToken = ""
$TelegramChatId   = ""

function Send-Telegram {
    param ([string]$Message)
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $uri = "https://api.telegram.org/bot$TelegramBotToken/sendMessage"
        $body = @{
            chat_id = $TelegramChatId
            text    = $Message
        }
        Invoke-RestMethod -Uri $uri -Method Post -Body $body | Out-Null
        Log "Telegram enviado"
    } catch {
        Log "ERROR TELEGRAM: $($_.Exception.Message)"
    }
}

# ================= Carpetas y nombres =================
if (-not (Test-Path $TempZipDir)) { New-Item -ItemType Directory -Path $TempZipDir | Out-Null }

$FechaCarpeta = $FechaActual.ToString("yyyyMMdd")
$ZipFileName  = "Backup-$FechaCarpeta.zip"
$TempZip      = Join-Path $TempZipDir $ZipFileName
$DestFolder   = Join-Path $NasPath $FechaCarpeta
$DestZip      = Join-Path $DestFolder $ZipFileName

Log "=== INICIO BACKUP ARCHIVOS BAK ==="

$ErrorFiles = @()

# ================= COMPRIMIR TODOS LOS .BKP =================
try {
    if (Test-Path $TempZip) { Remove-Item $TempZip -Force }

    $shell = New-Object -ComObject Shell.Application
    $zipFolder = $shell.NameSpace($TempZip)
    if (-not $zipFolder) {
        # Crear ZIP vacío
        Set-Content -Path $TempZip -Value ("PK" + [char]5 + [char]6 + ("`0" * 18))
        $zipFolder = $shell.NameSpace($TempZip)
    }

    $Files = Get-ChildItem -Path $SourcePath -Filter "*.bkp" -File
    foreach ($file in $Files) {
        try {
            $srcFolder = $shell.NameSpace($file.DirectoryName)
            $srcItem   = $srcFolder.ParseName($file.Name)
            Log "Añadiendo $($file.Name) al ZIP..."
            $zipFolder.CopyHere($srcItem, 0x14)
            Start-Sleep 1
        } catch {
            $ErrorFiles += "$($file.Name) - $($_.Exception.Message)"
            Log "ERROR al añadir $($file.Name) al ZIP"
        }
    }
} catch {
    $ErrorFiles += "ERROR general al comprimir - $($_.Exception.Message)"
    Log "ERROR general al comprimir archivos"
}

# ================= CREAR CARPETA NAS =================
try {
    if (-not (Test-Path $DestFolder)) {
        New-Item -ItemType Directory -Path $DestFolder -Force | Out-Null
    }
} catch {
    $ErrorFiles += "ERROR al crear carpeta NAS - $($_.Exception.Message)"
    Log "ERROR al crear carpeta NAS"
}

# ================= COPIAR ZIP AL NAS =================
try {
    Log "Copiando ZIP al NAS..."
    Start-Process robocopy -ArgumentList "`"$TempZipDir`" `"$DestFolder`" $ZipFileName /R:1 /W:1" -Wait
    Log "ZIP copiado correctamente al NAS."

    # Limpiar archivos locales
    foreach ($file in $Files) { Remove-Item $file.FullName -Force }
    Remove-Item $TempZip -Force
} catch {
    $ErrorFiles += "ERROR al copiar al NAS - $($_.Exception.Message)"
    Log "ERROR al copiar ZIP al NAS"
}

Log "=== FIN BACKUP ARCHIVOS BAK ==="

# ================= NOTIFICACIONES SOLO SI HAY ERRORES =================
if ($ErrorFiles.Count -gt 0) {

    $Servidor = $env:COMPUTERNAME
    $Fecha    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # -------- CORREO HTML --------
    $BodyHtml  = "<h2>ERROR EN BACKUP BAK</h2>"
    $BodyHtml += "<p><b>Servidor:</b> $Servidor</p>"
    $BodyHtml += "<p><b>Fecha:</b> $Fecha</p>"
    $BodyHtml += "<p><b>Ruta origen:</b><br>$SourcePath</p>"
    $BodyHtml += "<p><b>Backup NAS:</b><br>$DestFolder</p>"
    $BodyHtml += "<h3>Errores detectados</h3><ul style='color:red'>"
    foreach ($e in $ErrorFiles) { $BodyHtml += "<li>$e</li>" }
    $BodyHtml += "</ul><p>Log: $LogFile</p>"

    Send-Mail -Subject "ERROR BACKUP BAK - $Servidor" -Body $BodyHtml

    # -------- TELEGRAM TEXTO PLANO --------
    $BodyTelegram  = "REPORTE BACKUP BAK`n"
    $BodyTelegram += "Servidor: $Servidor`n"
    $BodyTelegram += "Fecha: $Fecha`n`n"
    $BodyTelegram += "Errores:`n"
    foreach ($e in $ErrorFiles) { $BodyTelegram += "- $e`n" }
    $BodyTelegram += "`nLog: $LogFile"

    Send-Telegram -Message $BodyTelegram
}

Write-Host "Proceso finalizado"
