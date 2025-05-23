function Write-Evidence {
    param([string]$Msg)
    $time  = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Msg)
    $hash  = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes)) -replace '-'
    Add-Content -Path $Cfg.EvidPathTxt -Value "[$time] $Msg [$hash]"
    @{ timestamp = $time; mensaje = $Msg; hash = $hash } | ConvertTo-Json -Depth 3 | Add-Content -Path $Cfg.EvidPathJson
}

function Show-Alert {
    param([string]$Msg)
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($Msg, "BLINDAJETOTAL", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
}

function Send-Emergency {
    param([string]$Tipo, [string]$Detalle, [string]$IP = "")
    $payload = @{
        tipo        = $Tipo
        descripcion = $Detalle
        ip          = $IP
        timestamp   = (Get-Date).ToString("o")
        host        = $env:COMPUTERNAME
        usuario     = $env:USERNAME
    } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri $Cfg.Emergency_Endpoint -Method POST -Body $payload -ContentType "application/json"
        Write-Log "Alerta de emergencia enviada: $Tipo - $Detalle"
    } catch {
        Write-Log "Error al enviar alerta de emergencia: $_"
    }
}
function Send-SIEMEvent {
    [CmdletBinding()]
    param(
        [string]$Tipo,
        [string]$Descripcion,
        [string]$IP = "",
        [ValidateSet("json", "syslog", "gelf", "txt")][string]$Formato = "json"
    )
    $evento = @{
        tipo        = $Tipo
        descripcion = $Descripcion
        ip          = $IP
        usuario     = $env:USERNAME
        host        = $env:COMPUTERNAME
        timestamp   = (Get-Date).ToUniversalTime().ToString("o")
        modulo      = "BlindajeTotal"
        nivel       = "ALERTA"
        origen      = "script"
    }
    switch ($Formato) {
        "json" {
            try {
                $payload = $evento | ConvertTo-Json -Depth 3
                Invoke-RestMethod -Uri $Cfg.SIEM_Json_Endpoint -Method POST -Body $payload -ContentType "application/json"
                Write-Log "Evento JSON enviado al SIEM."
            }
            catch {
                Write-Log "Error al enviar evento JSON al SIEM: $_"
            }
        }
        "syslog" {
            try {
                $msg = "<134> $(Get-Date -Format o) ${env:COMPUTERNAME} BlindajeTotal: $($evento.tipo) - $($evento.descripcion)"
                $udp = New-Object System.Net.Sockets.UdpClient
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($msg)
                $udp.Send($bytes, $bytes.Length, $Cfg.SIEM_Syslog_Server, 514) | Out-Null
                $udp.Close()
                Write-Log "Evento enviado por syslog plano (UDP 514) al SIEM."
            }
            catch {
                Write-Log "Error al enviar por syslog al SIEM: $_"
            }
        }
        "gelf" {
            try {
                $gelf = @{
                    version       = "1.1"
                    host          = $evento.host
                    short_message = $evento.descripcion
                    full_message  = $evento | ConvertTo-Json -Depth 3
                    timestamp     = [math]::Round((Get-Date -UFormat %s) + 0.0, 2)
                    level         = 4
                    _tipo         = $evento.tipo
                    _origen       = $evento.origen
                    _usuario      = $evento.usuario
                    _ip           = $evento.ip
                } | ConvertTo-Json -Depth 3
                Invoke-RestMethod -Uri $Cfg.SIEM_Gelf_Endpoint -Method POST -Body $gelf -ContentType "application/json"
                Write-Log "Evento GELF enviado al SIEM."
            }
            catch {
                Write-Log "Error al enviar GELF al SIEM: $_"
            }
        }
        "txt" {
            $line = "[{0}] {1} - {2} - IP: {3} - Usuario: {4} - Host: {5}" -f (Get-Date), $Tipo, $Descripcion, $IP, $env:USERNAME, $env:COMPUTERNAME
            Add-Content -Path "$env:USERPROFILE\Desktop\blindaje_siem_fallback_log.txt" -Value $line
            Write-Log "Evento SIEM guardado localmente en blindaje_siem_fallback_log.txt"
        }
    }
}
Export-ModuleMember -Function 'Write-Evidence', 'Show-Alert', 'Send-Emergency', 'Send-SIEMEvent'