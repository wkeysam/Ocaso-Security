function Resolve-GeoIP {
    param([string]$IP)
    try {
        $response = Invoke-RestMethod "http://ip-api.com/json/$IP" -ErrorAction Stop
        if ($response.status -eq 'success') {
            Write-Log "GeoIP para ${IP}: $($response.city), $($response.regionName), $($response.country) [ISP: $($response.isp)]"
            Send-SIEMEvent -Tipo "GeoIP Lookup" -Descripcion "IP: $IP, Pais: $($response.country), Ciudad: $($response.city), ISP: $($response.isp)" -IP $IP
            if ($response.countryCode -ne $Cfg.UbicacionSegura) {
                $msg = "[ALERTA GEOIP] Conexion a $IP detectada fuera de la ubicacion segura. Pais: $($response.country) (Esperado: $($Cfg.UbicacionSegura))"
                Write-Log $msg
                Show-Alert $msg
                Send-Emergency -Tipo "Conexion Fuera de Zona Segura" -Detalle "IP: $IP, Pais: $($response.country)" -IP $IP
            }
        } else {
            Write-Log "GeoIP para $IP falló: $($response.message)"
        }
    } catch {
        Write-Log "Excepcion en Resolve-GeoIP para ${IP}: $_"
    }
}

function Disable-UnlistedCameras {
    Write-Log "Verificando cámaras conectadas..."
    $cams = Get-PnpDevice -Class Camera -Status OK -ErrorAction SilentlyContinue
    if (-not $cams) {
        Write-Log "No se detectaron cámaras activas."
        return
    }
    foreach ($cam in $cams) {
        $camName = $cam.FriendlyName
        $authorized = $false
        foreach ($patron in $Cfg.CamWhitelist) {
            if ($camName.ToLower() -like "*$($patron.ToLower())*") {
                $authorized = $true
                Write-Log "Cámara autorizada: $($camName) (Patron: $patron)"
                break
            }
        }
        if (-not $authorized) {
            try {
                Disable-PnpDevice -InstanceId $cam.InstanceId -Confirm:$false -ErrorAction Stop
                $msg = "[ALERTA CAMARA] Cámara NO AUTORIZADA deshabilitada: $($camName) (ID: $($cam.InstanceId))"
                Write-Log $msg
                Show-Alert $msg
                Write-Evidence "Cámara no autorizada deshabilitada: $($camName) (ID: $($cam.InstanceId))"
                Send-SIEMEvent -Tipo "Camara Deshabilitada" -Descripcion $msg
            } catch {
                Write-Log "Error al intentar deshabilitar la cámara no autorizada: $($camName) - $_"
            }
        } else {
            Write-Log "Cámara autorizada detectada y verificada: $($camName)"
        }
    }
}


function Clear-Proxies {
    Write-Log "Limpiando configuraciones de proxy del sistema..."
    try {
        netsh winhttp reset proxy | Out-Null
        Write-Log "Proxy WinHTTP reseteado."
    } catch {
        Write-Log "Error al resetear proxy WinHTTP (puede que no estuviera configurado): $_"
    }
    $regPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings"
    )
    foreach ($path in $regPaths) {
        try {
            if (Test-Path $path) {
                Set-ItemProperty -Path $path -Name ProxyEnable -Value 0 -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $path -Name ProxyServer -ErrorAction SilentlyContinue
                Remove-ItemProperty -Path $path -Name AutoConfigURL -ErrorAction SilentlyContinue
                Write-Log "Proxy de Internet Settings en '$path' limpiado."
            }
        } catch {
            Write-Log "Error limpiando proxy en registro '$path': $_"
        }
    }
    foreach ($varName in @("HTTP_PROXY", "HTTPS_PROXY", "FTP_PROXY", "NO_PROXY")) {
        try {
            [Environment]::SetEnvironmentVariable($varName, $null, [System.EnvironmentVariableTarget]::User)
            [Environment]::SetEnvironmentVariable($varName, $null, [System.EnvironmentVariableTarget]::Machine)
            Write-Log "Variable de entorno '$varName' eliminada para User y Machine."
        } catch {
            Write-Log "Error eliminando variable de entorno proxy '$varName': $_"
        }
    }
    Write-Log "Limpieza de configuraciones de proxy completada."
    Show-Alert "Configuraciones de proxy del sistema han sido limpiadas."
}





function Set-SafeDNS {
    Write-Log "Verificando y configurando servidores DNS seguros..."
    $adapters = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue
    foreach ($adapter in $adapters) {
        $iface = $adapter.InterfaceAlias
        $currentDnsServers = $adapter.ServerAddresses
        $allDnsAreSafe = $true
        if ($currentDnsServers.Count -eq 0) {
            $allDnsAreSafe = $false
        } else {
            foreach($dns in $currentDnsServers){
                if($dns -notin $Cfg.DNSPermitidas){
                    $allDnsAreSafe = $false
                    break
                }
            }
        }
        if (-not $allDnsAreSafe) {
            Write-Log "DNS no seguros detectados en '$iface': $($currentDnsServers -join ', '). Configurando a DNS permitidos: $($Cfg.DNSPermitidas -join ', ')"
            try {
                Set-DnsClientServerAddress -InterfaceAlias $iface -ServerAddresses $Cfg.DNSPermitidas -ErrorAction Stop
                Write-Log "Servidores DNS para el adaptador '$iface' forzados a la lista blanca: $($Cfg.DNSPermitidas -join ', ')."
                Show-Alert "DNS para '$iface' configurados a servidores seguros."
                Send-SIEMEvent -Tipo "DNS Configurado a Seguro" -Descripcion "Adaptador '$iface' tenia DNS no seguros ($($currentDnsServers -join ', ')). Establecido a ($($Cfg.DNSPermitidas -join ', '))."
            } catch {
                Write-Log "Error al configurar DNS para '$iface': $_"
                Show-Alert "Error al configurar DNS seguros para '$iface'."
            }
        } else {
            Write-Log "Servidores DNS en '$iface' ya son seguros: $($currentDnsServers -join ', ')."
        }
    }
}

function Invoke-Hardening {
    Write-Log "========== INICIO DE BARRIDO DE HARDENING =========="
    Get-NetFirewallRule -DisplayName "Honeypot Trap Inbound" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "Honeypot Trap Inbound" -RemoteAddress $Cfg.HoneypotIP -LocalPort 8080 -Protocol TCP -Direction Inbound -Action Allow -Profile Any -ErrorAction SilentlyContinue | Out-Null
    Write-Log "Regla de Honeypot Inbound para IP $($Cfg.HoneypotIP) en puerto 8080 creada/verificada."
    Get-DnsClientServerAddress -AddressFamily IPv4 | ForEach-Object {
        foreach ($dns in $_.ServerAddresses) {
            if ($dns -notin $Cfg.DNSPermitidas) {
               $msg = "[ALERTA DNS] DNS PELIGROSO DETECTADO: $dns en el adaptador '$($_.InterfaceAlias)'. Deshabilitando adaptador!"
                Write-Log $msg
                Show-Alert $msg
                Send-Emergency -Tipo "DNS Peligroso Detectado" -Detalle "DNS: $dns en adaptador '$($_.InterfaceAlias)'. Adaptador deshabilitado."
                Disable-NetAdapter -Name $_.InterfaceAlias -Confirm:$false -ErrorAction SilentlyContinue
                Write-Evidence "DNS Peligroso $dns en '$($_.InterfaceAlias)'. Adaptador deshabilitado."
                break
            }
        }
    }
    Set-DefaultDeny # Esta función debería estar en Firewall.psm1
    Write-Log "Analizando conexiones TCP establecidas..."
    Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue | Where-Object {
        $_.RemoteAddress -notmatch "^(127\.|::1|fe80::|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)" -and
        $_.RemotePort -notin $Cfg.TCPPermitidos
    } | Sort-Object -Property RemoteAddress -Unique | ForEach-Object {
        $ipRemota = $_.RemoteAddress
        $puertoRemoto = $_.RemotePort
        $procesoAppId = (Get-NetTCPConnection -LocalPort $_.LocalPort -RemoteAddress $ipRemota -RemotePort $puertoRemoto -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess)
        $nombreProceso = if ($procesoAppId) { (Get-Process -Id $procesoAppId -ErrorAction SilentlyContinue).ProcessName } else { "N/A" }
        $msg = "[ALERTA CONEXION] Conexion activa a IP/Puerto NO ESTANDAR: $ipRemota`:$puertoRemoto (Proceso: $nombreProceso)"
        Write-Log $msg
        Show-Alert $msg
        Send-Emergency -Tipo "Conexion Activa No Estandar" -Detalle "$ipRemota`:$puertoRemoto (Proceso: $nombreProceso)" -IP $ipRemota
        Write-Evidence "Conexion activa no estandar: $ipRemota`:$puertoRemoto (Proceso: $nombreProceso)"
        if ($Cfg.SecureIPs -notcontains $ipRemota) {
            Block-IP -IP $ipRemota -RuleName "Blindaje-Reactivo-$ipRemota" # Block-IP debería estar en Firewall.psm1
        } else {
            Write-Log "IP $ipRemota está en SecureIPs, no se bloquea reactivamente."
        }
        Resolve-GeoIP $ipRemota # Resolve-GeoIP está definida en este mismo módulo
    }
    Disable-UnlistedCameras # Definida en este mismo módulo
    Clear-Proxies # Definida en este mismo módulo
    Set-SafeDNS # Definida en este mismo módulo
    Invoke-HeuristicAnalysis # Definida en este mismo módulo (separada, no anidada)
    Write-Log "Barrido de hardening completado. Siguiente barrido en $Interval segundos si -Hardening está en modo loop."
    Write-Log "========== FIN DE BARRIDO DE HARDENING =========="
}

Export-ModuleMember -Function 'Invoke-Hardening', 'Invoke-HeuristicAnalysis', 'Disable-UnlistedCameras', 'Clear-Proxies', 'Set-SafeDNS', 'Resolve-GeoIP'



