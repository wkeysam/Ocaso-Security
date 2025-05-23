function Invoke-VoIPConnectionMonitor {
    Write-Log "Iniciando monitoreo de conexiones potencialmente VoIP..."
    # Monitoreo de TCP (SIP usa TCP y UDP)
    $potentialVoIPTCPConnections = Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object {
        ($_.RemotePort -in $Cfg.VoIPPorts) -or ($_.LocalPort -in $Cfg.VoIPPorts)
    }
    if ($potentialVoIPTCPConnections) {
        foreach ($conn in $potentialVoIPTCPConnections) {
            $processId = $conn.OwningProcess
            $processName = (Get-Process -Id $processId -ErrorAction SilentlyContinue).ProcessName
            $msg = "Posible conexión TCP VoIP detectada: Local $($conn.LocalAddress):$($conn.LocalPort) -> Remote $($conn.RemoteAddress):$($conn.RemotePort) (Proceso: $processName, ID: $processId)"
            Write-Log $msg
            Write-Evidence $msg
            Send-SIEMEvent -Tipo "PossibleVoIP_TCP_Connection" -Descripcion $msg -IP $conn.RemoteAddress
        }
    }

    # Monitoreo de UDP (SIP y RTP/RTCP usan UDP)
    $listeningUDPVoIPPorts = Get-NetUDPEndpoint -ErrorAction SilentlyContinue | Where-Object {
        $_.LocalPort -in $Cfg.VoIPPorts
    }
    if ($listeningUDPVoIPPorts) {
        foreach ($ep in $listeningUDPVoIPPorts) {
            $msg = "Posible endpoint UDP VoIP escuchando: Local $($ep.LocalAddress):$($ep.LocalPort)"
            Write-Log $msg
            Write-Evidence $msg
            Send-SIEMEvent -Tipo "PossibleVoIP_UDP_Endpoint" -Descripcion $msg
        }
    }
    if (-not ($potentialVoIPTCPConnections -or $listeningUDPVoIPPorts)) {
        Write-Log "No se detectaron conexiones TCP activas o endpoints UDP escuchando en puertos VoIP configurados."
    }
}

function Invoke-BlockVoIPTraffic {
    Write-Log "Aplicando reglas de firewall para bloquear tráfico VoIP..."
    $ruleGroup = "BlindajeVoIP"

    Get-NetFirewallRule -Group $ruleGroup -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    Write-Log "Reglas de firewall antiguas del grupo '$ruleGroup' eliminadas."

    foreach ($port in $Cfg.VoIPPorts) {
        $ruleNameTCP = "BlockVoIP-TCP-Out-$port"
        $ruleNameUDP = "BlockVoIP-UDP-Out-$port"

        New-NetFirewallRule -DisplayName $ruleNameTCP -Group $ruleGroup -Direction Outbound -Action Block -Protocol TCP -RemotePort $port -Profile Any -Enabled True | Out-Null
        Write-Log "Regla creada: Bloquear TCP saliente al puerto $port ($ruleNameTCP)"

        New-NetFirewallRule -DisplayName $ruleNameUDP -Group $ruleGroup -Direction Outbound -Action Block -Protocol UDP -RemotePort $port -Profile Any -Enabled True | Out-Null
        Write-Log "Regla creada: Bloquear UDP saliente al puerto $port ($ruleNameUDP)"
    }

    if ($Cfg.VoIPServerIPs) {
        foreach ($ip in $Cfg.VoIPServerIPs) {
            if ($Cfg.SecureIPs -and ($ip -in $Cfg.SecureIPs)) {
                Write-Log "La IP de servidor VoIP $ip está en SecureIPs; no se bloquea."
            } else {
                $ruleNameIP = "BlockVoIP-IP-Out-$ip"
                New-NetFirewallRule -DisplayName $ruleNameIP -Group $ruleGroup -Direction Outbound -Action Block -RemoteAddress $ip -Profile Any -Enabled True | Out-Null
                Write-Log "Regla creada: Bloquear tráfico saliente a IP VoIP $ip ($ruleNameIP)"
            }
        }
    }
    Show-Alert "Reglas de firewall para bloquear tráfico VoIP (saliente) aplicadas."
}
Export-ModuleMember -Function 'Invoke-VoIPConnectionMonitor', 'Invoke-BlockVoIPTraffic'