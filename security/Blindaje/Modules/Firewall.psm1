function Block-IP {
    param([string]$IP, [string]$RuleName)
    try {
        if (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue) {
            Write-Log "Regla de firewall '$RuleName' para IP $IP ya existe."
            return
        }
        New-NetFirewallRule -DisplayName $RuleName -RemoteAddress $IP -Action Block -Direction Outbound -Profile Any -Protocol Any -ErrorAction Stop | Out-Null
        Write-Log "IP bloqueada $IP (Regla: $RuleName)"
        Write-Evidence "Bloqueo IP Manual/Automatico: $IP (Regla: $RuleName)"
        Send-SIEMEvent -Tipo "IP Bloqueada" -Descripcion "IP: $IP, Regla: $RuleName" -IP $IP
        netsh interface portproxy add v4tov4 listenaddress=192.168.1.10 listenport=8080 connectaddress=10.0.0.5 connectport=80
        if ($Cfg.RuleStore -and (Test-Path (Split-Path $Cfg.RuleStore -Parent))) {
             Add-Content -Path $Cfg.RuleStore -Value $IP
        } else {
            Write-Log "Directorio para RuleStore no existe o RuleStore no configurado. No se guardó la IP $IP."
        }
    } catch {
        Write-Log "Error al bloquear IP $IP (Regla: $RuleName): $_"
    }
}

function Get-IPsFromURL {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Url)
    try {
        if ($Url -notmatch "^http[s]?://") {
            $Url = "http://" + $Url
        }
        $uri = [System.Uri]$Url
        Write-Log "Resolviendo IPs para $($uri.Host)..."
        $ips = (Resolve-DnsName -Name $uri.Host -Type A -ErrorAction SilentlyContinue).IPAddress
        if (-not $ips) {
            Write-Log "No se encontraron IPs (IPv4) para $($uri.Host) usando Resolve-DnsName."
            $ips = ([System.Net.Dns]::GetHostAddresses($uri.Host) | Where-Object {$_.AddressFamily -eq 'InterNetwork'} | ForEach-Object { $_.IPAddressToString })
             if (-not $ips) { Write-Log "No se encontraron IPs para $($uri.Host) tampoco con System.Net.Dns." }
        }
        return $ips | Select-Object -Unique
    } catch {
        Write-Log "Error al resolver URL ${Url}: $_"
        Show-Alert "Error al resolver URL: ${Url}"
        return @()
    }
}

function Block-URLTraffic {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Url)
    $ips = Get-IPsFromURL -Url $Url
    if ($ips) {
        Write-Log "IPs obtenidas para $Url : $($ips -join ', ')"
        foreach ($ip in $ips) {
            if ($Cfg.SecureIPs -and ($ip -in $Cfg.SecureIPs)) {
                Write-Log "La IP $ip (resultante de $Url) esta en la lista de IPs seguras; no se bloquea."
            } else {
                Block-IP -IP $ip -RuleName "Blindaje-URL-$($Url.Replace('http://','').Replace('https://','').Split('/')[0])-$ip"
                Write-Log "Bloqueo de trafico aplicado a $ip (originado por URL: $Url)"
            }
        }
    } else {
        Write-Log "[ADVERTENCIA] No se pudo obtener ninguna IP para la URL $Url. No se pueden aplicar bloqueos basados en IP."
    }
}

function Set-DefaultDeny {
    Write-Log "Configurando firewall en modo default-deny para trafico saliente..."
    Get-NetFirewallRule -Group "BlindajeDefault" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName "BlindajeDefault-BlockAllOutbound" -Group "BlindajeDefault" `
        -Direction Outbound -Action Block -Profile Any -Enabled True -ErrorAction Stop | Out-Null
    Write-Log "Regla 'BlindajeDefault-BlockAllOutbound' creada."
    foreach ($dnsServer in $Cfg.DNSPermitidas) {
        New-NetFirewallRule -DisplayName "BlindajeDefault-AllowDNS-$dnsServer" -Group "BlindajeDefault" `
            -Direction Outbound -Action Allow -RemoteAddress $dnsServer -Protocol UDP -RemotePort 53 -Profile Any -Enabled True | Out-Null
        New-NetFirewallRule -DisplayName "BlindajeDefault-AllowDoT-$dnsServer" -Group "BlindajeDefault" `
            -Direction Outbound -Action Allow -RemoteAddress $dnsServer -Protocol TCP -RemotePort 853 -Profile Any -Enabled True | Out-Null
    }
    foreach ($port in $Cfg.TCPPermitidos) {
         New-NetFirewallRule -DisplayName "BlindajeDefault-AllowTCP-$port" -Group "BlindajeDefault" `
            -Direction Outbound -Action Allow -RemotePort $port -Protocol TCP -Profile Any -Enabled True | Out-Null
    }
    if ($Cfg.SecureIPs) {
        foreach ($secureIp in $Cfg.SecureIPs) {
            New-NetFirewallRule -DisplayName "BlindajeDefault-AllowSecureIP-$secureIp" -Group "BlindajeDefault" `
                -Direction Outbound -Action Allow -RemoteAddress $secureIp -Profile Any -Enabled True | Out-Null
        }
    }
    New-NetFirewallRule -DisplayName "BlindajeDefault-AllowLoopback" -Group "BlindajeDefault" `
        -Direction Outbound -Action Allow -RemoteAddress LocalSubnet -Profile Any -Enabled True | Out-Null
    if (Test-Path $Cfg.RuleStore) {
        Get-Content $Cfg.RuleStore | Sort-Object -Unique | Where-Object { $_ -match '\d+\.\d+\.\d+\.\d+' } | ForEach-Object {
            # No action needed here
        }
    }
    Write-Log "Modo default-deny para tráfico saliente aplicado con excepciones basicas."
    Show-Alert "Firewall configurado en modo Default-Deny (saliente). Se aplican excepciones para DNS y puertos comunes."
}
#==============================================================================
# FUNCIONES PARA REDIRECCIÓN DE PUERTOS TCP (PORT PROXY)
#==============================================================================

function Set-TcpPortRedirection {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ListenAddress,

        [Parameter(Mandatory=$true)]
        [uint16]$ListenPort,

        [Parameter(Mandatory=$true)]
        [string]$ConnectAddress,

        [Parameter(Mandatory=$true)]
        [uint16]$ConnectPort
    )

    $ruleDescription = "TCP Redirection: $ListenAddress`:$ListenPort -> $ConnectAddress`:$ConnectPort"
    Write-Log "Intentando configurar $ruleDescription"

    if ($PSCmdlet.ShouldProcess("Interfaz de red para $ListenAddress`:$ListenPort", "Configurar redirección TCP hacia $ConnectAddress`:$ConnectPort")) {
        try {
            # Primero, intentamos eliminar cualquier regla existente para esta combinación de escucha para evitar errores
            netsh interface portproxy delete v4tov4 listenaddress=$ListenAddress listenport=$ListenPort ErrorAction SilentlyContinue | Out-Null

            # Luego, añadimos la nueva regla
            netsh interface portproxy add v4tov4 listenaddress=$ListenAddress listenport=$ListenPort connectaddress=$ConnectAddress connectport=$ConnectPort ErrorAction Stop | Out-Null
            
            Write-Log "[ÉXITO] $ruleDescription configurada."
            Write-Host "[+] $ruleDescription configurada exitosamente." -ForegroundColor Green
            Write-Evidence "Redirección TCP configurada: $ListenAddress`:$ListenPort -> $ConnectAddress`:$ConnectPort"
            # Considera enviar un evento SIEM si es relevante para tu estrategia de monitoreo
            # Send-SIEMEvent -Tipo "Redirección TCP Configurada" -Descripcion $ruleDescription -IP $ConnectAddress
        }
        catch {
            $errorMessage = "Error al configurar $ruleDescription : $($_.Exception.Message)"
            Write-Log "[ERROR] $errorMessage"
            Write-Warning $errorMessage
        }
    }
}

function Remove-TcpPortRedirection {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ListenAddress,

        [Parameter(Mandatory=$true)]
        [uint16]$ListenPort
    )

    $ruleDescription = "Eliminación de Redirección TCP para $ListenAddress`:$ListenPort"
    Write-Log "Intentando $ruleDescription"

    if ($PSCmdlet.ShouldProcess("Interfaz de red para $ListenAddress`:$ListenPort", "Eliminar redirección TCP")) {
        try {
            netsh interface portproxy delete v4tov4 listenaddress=$ListenAddress listenport=$ListenPort ErrorAction Stop | Out-Null
            Write-Log "[ÉXITO] $ruleDescription completada."
            Write-Host "[+] Redirección TCP para $ListenAddress`:$ListenPort eliminada exitosamente." -ForegroundColor Green
            Write-Evidence "Redirección TCP eliminada: $ListenAddress`:$ListenPort"
        }
        catch {
            $errorMessage = "Error al realizar $ruleDescription : $($_.Exception.Message)"
            Write-Log "[ERROR] $errorMessage"
            # Podrías querer ser menos verboso aquí si la regla no existía
            if ($_.Exception.Message -notmatch "Elemento no encontrado") {
                 Write-Warning $errorMessage
            } else {
                 Write-Log "La redirección para $ListenAddress`:$ListenPort no existía o ya fue eliminada."
                 Write-Host "[*] La redirección para $ListenAddress`:$ListenPort no existía." -ForegroundColor Yellow
            }
        }
    }
}

function Get-TcpPortRedirections {
    [CmdletBinding()]
    param()

    Write-Log "Obteniendo configuraciones de redirección TCP (portproxy)..."
    try {
        $output = netsh interface portproxy show v4tov4 ErrorAction Stop
        if ($output) {
            Write-Host "Configuraciones de Portproxy v4tov4:" -ForegroundColor Cyan
            $output # Muestra la salida directamente
            # Podrías parsear esto para un formato más estructurado si es necesario
        } else {
            Write-Host "No hay redirecciones de portproxy v4tov4 configuradas." -ForegroundColor Yellow
        }
        return $output # Devuelve la salida cruda para posible procesamiento
    }
    catch {
        $errorMessage = "Error al obtener configuraciones de portproxy: $($_.Exception.Message)"
        Write-Log "[ERROR] $errorMessage"
        Write-Warning $errorMessage
        return $null
    }
}
Export-ModuleMember -Function 'Block-IP', 'Get-IPsFromURL', 'Block-URLTraffic', 'Set-DefaultDeny', 'Set-TcpPortRedirection', 'Remove-TcpPortRedirection', 'Get-TcpPortRedirections'
