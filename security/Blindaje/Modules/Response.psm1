function Invoke-Response {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("BloquearIP", "DeshabilitarCamara", "ReiniciarAdaptador", "CerrarProceso")]
        [string]$Accion,
        [Parameter(Mandatory)]
        [string]$Objetivo
    )
    switch ($Accion) {
        "BloquearIP" {
            try {
                New-NetFirewallRule -DisplayName "RespuestaAuto-$Objetivo" -RemoteAddress $Objetivo -Action Block -Direction Outbound -Profile Any -Protocol Any -ErrorAction Stop | Out-Null
                Write-Log "IP bloqueada automaticamente: ${Objetivo}"
                Write-Evidence ("Respuesta Automatica - IP Bloqueada | {0}" -f $Objetivo)
                Show-Alert "IP bloqueada (Respuesta Automatica): ${Objetivo}"
            } catch {
                Write-Log "Error al bloquear IP (Respuesta Automatica) ${Objetivo}: $_"
                Show-Alert "Error al bloquear IP (Respuesta Automatica): ${Objetivo}"
            }
        }
        "DeshabilitarCamara" {
            try {
                $cam = Get-PnpDevice -Class Camera | Where-Object { $_.FriendlyName -like "*$Objetivo*" }
                if ($cam) {
                    Disable-PnpDevice -InstanceId $cam.InstanceId -Confirm:$false -ErrorAction Stop
                    Write-Log "[CAMARA] Camara deshabilitada (Respuesta Automatica): ${Objetivo}"
                    Write-Evidence "Respuesta Automatica - Camara bloqueada: ${Objetivo}"
                    Show-Alert "[CAMARA] Camara desactivada (Respuesta Automatica): ${Objetivo}"
                } else {
                    Write-Log "[ADVERTENCIA] No se encontro camara coincidente para Respuesta Automatica: ${Objetivo}"
                    Show-Alert "[ADVERTENCIA] No se encontro camara con nombre para Respuesta Automatica: ${Objetivo}"
                }
            } catch {
                Write-Log "Error al deshabilitar camara (Respuesta Automatica) ${Objetivo}: $_"
                Show-Alert "Error al deshabilitar camara (Respuesta Automatica): ${Objetivo}"
            }
        }
        "ReiniciarAdaptador" {
            try {
                Restart-NetAdapter -Name $Objetivo -Confirm:$false -ErrorAction Stop
                Write-Log "Adaptador de red reiniciado (Respuesta Automatica): ${Objetivo}"
                Write-Evidence "Respuesta Automatica - Reinicio de adaptador de red: ${Objetivo}"
                Show-Alert "Adaptador reiniciado correctamente (Respuesta Automatica): ${Objetivo}"
            } catch {
                Write-Log "Error al reiniciar adaptador (Respuesta Automatica) ${Objetivo}: $_"
                Show-Alert "Error al reiniciar adaptador (Respuesta Automatica): ${Objetivo}"
            }
        }
        "CerrarProceso" {
            try {
                $proc = Get-Process | Where-Object { $_.ProcessName -like "*$Objetivo*" }
                if ($proc) {
                    $proc | Stop-Process -Force -ErrorAction Stop
                    Write-Log "Proceso finalizado (Respuesta Automatica): ${Objetivo}"
                    Write-Evidence "Respuesta Automatica - Proceso cerrado por seguridad: ${Objetivo}"
                    Show-Alert "Proceso finalizado (Respuesta Automatica): ${Objetivo}"
                } else {
                    Write-Log "[ADVERTENCIA] No se encontro proceso para Respuesta Automatica: ${Objetivo}"
                    Show-Alert "[ADVERTENCIA] Proceso no encontrado para Respuesta Automatica: ${Objetivo}"
                }
            } catch {
                Write-Log "Error al cerrar proceso (Respuesta Automatica) ${Objetivo}: $_"
                Show-Alert "Error al cerrar proceso (Respuesta Automatica): ${Objetivo}"
            }
        }
    }
}
Export-ModuleMember -Function 'Invoke-Response'