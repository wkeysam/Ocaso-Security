# ===========================================================
# BlindajeTotal.ps1 – versión consolidada con auto-elevacion
# Requiere Windows 10/11  –  Ultima edicion : 2025-05-21
# ===========================================================
# ▸ USO RAPIDO
#      powershell -file .\BlindajeTotal.ps1                 # Diagnostico + blindaje
#      powershell -file .\BlindajeTotal.ps1 -Diagnostico     # Solo diagnostico
#      powershell -file .\BlindajeTotal.ps1 -Hardening       # Solo blindaje (loop)
#      powershell -file .\BlindajeTotal.ps1 -RestoreRules
#      powershell -file .\BlindajeTotal.ps1 -BlockURL 'https://phishing.dom'
#      powershell -file .\BlindajeTotal.ps1 -MonitorVoIP     # Monitorea conexiones VoIP
#      powershell -file .\BlindajeTotal.ps1 -BlockVoIP       # Bloquea puertos/IPs VoIP
# ===========================================================

[CmdletBinding()]
param(
    [Alias('BlockURL')][string[]]$URLParaBloquear,
    [switch]$Diagnostico,
    [switch]$Hardening,
    [switch]$RestoreRules,
    [ValidateRange(15,3600)][int]$Interval = 60,  # segundos entre barridos si -Hardening
    [switch]$MonitorVoIP,
    [switch]$BlockVoIP
)

###############################################################################
#  AUTO-ELEVACION – relanza el script con privilegios de administrador         #
###############################################################################
if (-not (([Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
    Write-Host "[*] Re-lanzando el script con privilegios de administrador..."
    $argList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"$PSCommandPath") + (
        $PSBoundParameters.GetEnumerator() | ForEach-Object {
            "-$($_.Key)"; if ($_.Value -isnot [switch]) { $_.Value }
        }
    )
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
    exit
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

###############################################################################
#  CONFIGURACION UNICA                                                        #
###############################################################################
$Cfg = [pscustomobject]@{
    Fecha           = (Get-Date).ToString('s')
    HashEsperado    = 'TU_HASH_ORIGINAL_AQUI'  # Reemplazalo tras firmar el script
    UbicacionSegura = 'ES'                   # ISO 3166-1 alpha-2
    HoneypotIP      = '203.0.113.250'        # IP para honeypot (RFC 5737 TEST-NET-3)
    TCPPermitidos   = 80,443,22,53,123,993,995,587,5432 # Puertos TCP permitidos para conexiones salientes establecidas
    DNSPermitidas   = '8.8.8.8','1.1.1.1','9.9.9.9','208.67.222.222','208.67.220.220' # Servidores DNS permitidos
    URLBloqueadas   = @('example.com','malware.bad','tracking.evil.org') # URLs base para bloqueo inicial (ejemplos)
    CamWhitelist    = @("Logitech", "Microsoft", "HD Webcam", "Dell", "HP", "Sony", "Canon", "Nikon") # Fabricantes/nombres de camaras permitidas
    LogPath         = "$env:USERPROFILE\Desktop\blindaje_log.txt"
    EvidPathTxt     = "$env:USERPROFILE\Desktop\blindaje_evidencias.txt"
    EvidPathJson    = "$env:USERPROFILE\Desktop\blindaje_evidencias.json"
    HtmlReport      = "$env:USERPROFILE\Desktop\blindaje_amenazas.html"
    RuleStore       = "$env:ProgramData\BlindajeTotal_rules.txt" # Almacen para IPs bloqueadas persistentes
    EventCodes      = '4624','4625','4672','5156','5157' # Codigos de evento de Windows a monitorear
    SecureIPs       = @('192.168.1.100','203.0.113.10')  # Ejemplo de IPs autorizadas que no se bloquearan aunque una URL resuelva a ellas
    # URLs para SIEM y Emergencias (reemplazar con valores reales)
    SIEM_Json_Endpoint = "https://tu-servidor-siem.com/ingest"
    SIEM_Syslog_Server = "tu-servidor-syslog.local"
    SIEM_Gelf_Endpoint = "http://tu-servidor-graylog:12201/gelf"
    Emergency_Endpoint = "https://TU_ENDPOINT_EMERGENCIA.com/alerta"
    # Configuracion VoIP
    VoIPPorts       = 5060, 5061 # SIP (TCP/UDP), SIPS (TCP/UDP). Añadir más si es necesario.
    VoIPServerIPs   = @('1.2.3.4', '5.6.7.8') # Lista de IPs de servidores VoIP conocidos para bloquear/monitorear (EJEMPLOS)
}


Import-Module -Name "$PSScriptRoot\Modules\Loggin.psm1" -Force
Import-Module -Name "$PSScriptRoot\Modules\Diagnostics.psm1" -Force
Import-Module -Name "$PSScriptRoot\Modules\HtmlReport.psm1" -Force
Import-Module -Name "$PSScriptRoot\Modules\Utilities.psm1" -Force
Import-Module -Name "$PSScriptRoot\Modules\Firewall.psm1" -Force
Import-Module -Name "$PSScriptRoot\Modules\Hardening.psm1"
Import-Module -Name "$PSScriptRoot\Modules\Response.psm1"
Import-Module -Name "$PSScriptRoot\Modules\VoIP.psm1" -Force
Import-Module -Name "$PSScriptRoot\Modules\EventMonitoring.psm1" -Force
Import-Module -Name "$PSScriptRoot\Modules\Maintenance.psm1" -Force
Write-Log "Minimal script test: START"
Write-Host "Minimal script test: END - Check log at $($Cfg.LogPath)" 

