Auto Backup BAK Script
Descripción

auto-backup.ps1 es un script de PowerShell diseñado para automatizar el respaldo de archivos .bkp a un NAS.
El script:

Comprime todos los archivos .bkp de una carpeta origen en un ZIP diario.

Copia el ZIP al NAS usando robocopy sin mapear unidades de red, evitando conflictos de múltiples conexiones.

Mantiene un log detallado de ejecución.

Envía notificaciones por correo y Telegram solo si ocurre algún error durante el proceso.

Este enfoque asegura un respaldo seguro, limpio y automatizado, listo para entornos de producción.

Requisitos

Windows con PowerShell 5 o superior.

Acceso a un NAS compartido.

Permisos para ejecutar scripts de PowerShell (Set-ExecutionPolicy RemoteSigned recomendado).

Servidor SMTP para notificaciones por correo.

Bot de Telegram y Chat ID para notificaciones instantáneas (opcional).

Configuración

Abrir auto-backup.ps1 con un editor de texto.

Configurar las rutas y credenciales:

$SourcePath = ""      # Carpeta donde están los archivos .bkp
$TempZipDir = ""      # Carpeta temporal para ZIP
$NasPath    = "" # Ruta al NAS
$NasUser    = ""
$NasPass    = ""


Configurar SMTP para notificaciones por correo:

$SmtpServer = ""
$MailFrom   = ""
$MailTo     = ""


Configurar Telegram (opcional):

$TelegramBotToken = ""
$TelegramChatId   = ""

Funcionamiento

Compresión:
Todos los archivos .bkp de la carpeta origen se comprimen en un ZIP nombrado con la fecha del día: Backup-YYYYMMDD.zip.

Creación de carpeta NAS:
Si la carpeta correspondiente a la fecha no existe en el NAS, se crea automáticamente.

Copia al NAS:
El ZIP se envía al NAS usando robocopy, sin mapear unidades de red para evitar errores de conexión múltiple.

Limpieza:
Al finalizar correctamente, se eliminan los archivos .bkp originales y el ZIP temporal local.

Notificaciones:
Si ocurre algún error en cualquier etapa, el script envía:

Correo con detalles HTML de los errores y el log.

Mensaje de Telegram con resumen de errores y ruta del log.

Logs

Se generan logs diarios en: C:\Scripts\logs\log-backup-bkp-YYYYMMDD.txt.

El log contiene:

Inicio y fin del proceso.

Archivos añadidos al ZIP.

Errores encontrados durante compresión, creación de carpetas o copia al NAS.

Ejecución

Ejecutar el script desde PowerShell:

powershell -ExecutionPolicy Bypass -File "C:\Ruta\AutoBackup\auto-backup.ps1"


Se recomienda automatizar la ejecución con Tareas Programadas de Windows para respaldos diarios.

Consideraciones

Solo se respaldan archivos .bkp. Puedes cambiar el filtro en la sección de compresión si necesitas otro tipo de archivo.

Si el NAS requiere otro usuario o ya existe una conexión activa, el script evita conflictos al no mapear unidades.

Asegúrate de que el bot de Telegram y el SMTP estén configurados correctamente para recibir notificaciones.
