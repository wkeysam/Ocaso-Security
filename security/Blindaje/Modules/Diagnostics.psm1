function Invoke-Response {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("BloquearIP", "DeshabilitarCamara", "ReiniciarAdaptador", "CerrarProceso")]
        [string]$Accion,
        [Parameter(Mandatory)]
        [string]$Objetivo
    )
    function Test-SafeWiFi {
    Write-Host "`n--- ANÁLISIS DE ENTORNO WIFI ---`n" -ForegroundColor Magenta
    try {
        $wifiInterfaces = Get-NetAdapter -Physical | Where-Object {$_.MediaType -eq "Native 802.11"}
        if (-not $wifiInterfaces) {
            Write-Host "No se encontraron adaptadores WiFi físicos activos."  -ForegroundColor Yellow
            return
        }

        foreach ($wifiAdapter in $wifiInterfaces) {
            Write-Host "Analizando adaptador WiFi: $($wifiAdapter.Name)"
            $netshOutput = netsh wlan show interfaces
            $interfaceSection = $netshOutput | Select-String -Pattern "Nombre\s*:\s*$($wifiAdapter.NetConnectionID)" -Context 0,15

            if ($interfaceSection) {
                $ssid = ($interfaceSection | Select-String "SSID" | Select-Object -First 1).ToString().Split(':',2)[-1].Trim()
                $signalText = ($interfaceSection | Select-String "Señal" | Select-Object -First 1).ToString().Split(':',2)[-1].Trim()
                $signal = ($signalText -replace "[^0-9]","") -as [int]
                $auth = ($interfaceSection | Select-String "Autenticaci" | Select-Object -First 1).ToString().Split(':',2)[-1].Trim()
                $cipher = ($interfaceSection | Select-String "Cifrado" | Select-Object -First 1).ToString().Split(':',2)[-1].Trim()

                $ssid = if ([string]::IsNullOrWhiteSpace($ssid)) { "Desconocido" } else { $ssid }
                $auth = if ([string]::IsNullOrWhiteSpace($auth)) { "Desconocida" } else { $auth }
                $cipher = if ([string]::IsNullOrWhiteSpace($cipher)) { "Desconocido" } else { $cipher }

                Write-Host "  Conectado a SSID: $ssid"
                Write-Host "  Señal: $signal%"
                Write-Host "  Autenticación: $auth"
                Write-Host "  Cifrado: $cipher"

                if ($signal -lt 30) {
                    $msg = "[ADVERTENCIA WIFI] Señal WiFi baja: $signal% en SSID '$ssid' para adaptador '$($wifiAdapter.Name)'."
                    Write-Host $msg -ForegroundColor Red
                    Show-Alert $msg
                    Send-SIEMEvent -Tipo "WiFi Señal Baja" -Descripcion $msg
                }
                if ($auth -notin ("WPA2-Personal", "WPA3-Personal", "WPA2-Enterprise", "WPA3-Enterprise", "WPA2-PSK", "WPA3-PSK") -or
                    $cipher -notin ("CCMP", "AES", "GCMP")) {
                     $msg = "[ALERTA WIFI] ALERTA WIFI INSEGURO: SSID '$ssid' usa autenticacion/cifrado debil ($auth / $cipher) en '$($wifiAdapter.Name)'."
                     Write-Host $msg -ForegroundColor Red
                     Show-Alert $msg
                     Send-Emergency -Tipo "WiFi Inseguro Detectado" -Detalle $msg
                     Write-Evidence "WiFi Inseguro: SSID=$ssid, Auth=$auth, Cipher=$cipher, Adapter=$($wifiAdapter.Name)"
                } else {
                     Write-Host "  Configuración de seguridad WiFi parece adecuada ($auth / $cipher)." -ForegroundColor Green
                }
            } else {
                 Write-Host "  Adaptador WiFi '$($wifiAdapter.Name)' no está conectado o no se pudo obtener información de 'netsh wlan show interfaces' para NetConnectionID." -ForegroundColor Yellow
            }
        }
    } catch {
        Write-Log "Error en Test-SafeWiFi: $_"
        Write-Host "Error al analizar entorno WiFi: $_" -ForegroundColor Red
    }
    Write-Host "`n[+] Análisis WiFi finalizado." -ForegroundColor Magenta
}
}
Export-ModuleMember -Function 'Invoke-Diagnostics', 'Test-SafeWiFi'