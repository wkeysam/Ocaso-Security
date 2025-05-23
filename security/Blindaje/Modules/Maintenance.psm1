function Invoke-Restore {
    Write-Log "Iniciando restauración de reglas de firewall desde $Cfg.RuleStore..."
    if (Test-Path $Cfg.RuleStore) {
        $ipsRestauradas = 0
        Get-Content $Cfg.RuleStore | ForEach-Object {
            $ip = $_.Trim()
            if ($ip -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                Block-IP -IP $ip -RuleName "Blindaje-Restore-$ip"
                $ipsRestauradas++
            } else {
                Write-Log "Formato de IP inválido en RuleStore, omitiendo: '$ip'"
            }
        }
        Write-Log "$ipsRestauradas IPs/reglas procesadas para restauración desde $Cfg.RuleStore."
        if ($ipsRestauradas -gt 0) { Show-Alert "$ipsRestauradas reglas de firewall restauradas."}
    } else {
        Write-Log "Archivo de almacenamiento de reglas ($Cfg.RuleStore) no encontrado. No hay reglas para restaurar."
    }
}
function Test-Signature {
    Write-Log "Verificando firma digital del script..."
    $sig = Get-AuthenticodeSignature -LiteralPath $PSCommandPath -ErrorAction SilentlyContinue
    if ($sig.Status -eq "Valid") {
        Write-Log "Firma digital del script: VALIDA. Emisor: $($sig.SignerCertificate.Subject)"
         if ($Cfg.HashEsperado -ne 'TU_HASH_ORIGINAL_AQUI' -and $sig.SignedHash -ne $Cfg.HashEsperado) {
           Write-Log "ALERTA: El hash firmado ($($sig.SignedHash)) no coincide con el HashEsperado ($($Cfg.HashEsperado))!"
           Show-Alert "ALERTA DE SEGURIDAD: Firma digital válida, pero el hash firmado no coincide con el esperado."
            exit
         }
    } elseif ($sig.Status -eq "NotSigned") {
        Write-Log "ADVERTENCIA: El script no está firmado digitalmente."
        Show-Alert "ADVERTENCIA: El script BlindajeTotal.ps1 no está firmado."
         Write-Log "ERROR CRITICO: El script debe estar firmado digitalmente. Abortando."
         Show-Alert "ERROR CRITICO: El script BlindajeTotal.ps1 NO está firmado. No se puede ejecutar."
         exit
    } else {
        Write-Log "ERROR CRITICO: Firma digital INVÁLIDA/DESCONOCIDA (Estado: $($sig.Status))."
        Show-Alert "ERROR CRITICO: Firma digital INVÁLIDA (Estado: $($sig.Status)). Abortando."
        Send-Emergency -Tipo "Firma Script Invalida" -Detalle "Estado: $($sig.Status) para $PSCommandPath"
        exit
    }
}
Export-ModuleMember -Function Test-Signature, Invoke-Restore, Block-URLTraffic, Get-IPsFromURL, Send-SIEMEvent, Send-Emergency, Show-Alert