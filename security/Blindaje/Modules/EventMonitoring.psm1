function Start-EventWatcher {
    Write-Log "Iniciando monitor de eventos críticos de Windows..."
    $existingWatcher = Get-EventSubscriber -SourceIdentifier "BlindajeEvent" -ErrorAction SilentlyContinue
    if ($existingWatcher) {
        Write-Log "El monitor de eventos 'BlindajeEvent' ya existe. Eliminando para re-registro."
         Unregister-Event -SourceIdentifier "BlindajeEvent" -ErrorAction SilentlyContinue
    }
    $eventConditions = $Cfg.EventCodes | ForEach-Object { "TargetInstance.EventCode='$($_)'" }
    $filter = "SELECT * FROM __InstanceCreationEvent WITHIN 5 WHERE TargetInstance ISA 'Win32_NTLogEvent' AND TargetInstance.LogFile='Security' AND ($( $eventConditions -join ' OR ' ))"

    try {
        Register-WmiEvent -Query $filter -SourceIdentifier "BlindajeEvent" -Action {
            $evt = $Event.SourceEventArgs.NewEvent.TargetInstance
            $insertionStrings = $evt.InsertionStrings -join "; "
            $logMessage = "Evento de Seguridad $($evt.EventCode) (ID: $($evt.RecordNumber)): Usuario: $($evt.User), Mensaje: $insertionStrings"

            Write-Log $logMessage
            Show-Alert "Evento de Seguridad Crítico Detectado: Código $($evt.EventCode)"
            Send-Emergency -Tipo "Evento Seguridad Windows $($evt.EventCode)" -Detalle "Log: $($evt.LogFile), User: $($evt.User), Source: $($evt.SourceName), Message: $insertionStrings"
            Write-Evidence "Evento Seguridad Windows: Code=$($evt.EventCode), User=$($evt.User), Record=$($evt.RecordNumber), Strings=$insertionStrings"
            Send-SIEMEvent -Tipo "WinEvent-$($evt.EventCode)" -Descripcion "User: $($evt.User), Source: $($evt.SourceName), Message: $insertionStrings"
        } -ErrorAction Stop | Out-Null
        Write-Log "Monitor de eventos críticos 'BlindajeEvent' iniciado para códigos: $($Cfg.EventCodes)."
    } catch {
        Write-Log "Error al registrar el monitor de eventos WMI 'BlindajeEvent': $_"
        Show-Alert "FALLO CRITICO: No se pudo iniciar el monitor de eventos de seguridad."
    }
}
Export-ModuleMember -Function 'Start-EventWatcher'