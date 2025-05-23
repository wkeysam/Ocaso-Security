# HtmlReport.psm1

function Export-HtmlReport {
    Write-Host "[DEBUG] Entrando a Export-HtmlReport (Version Super Minimalista Sin Here-Strings)" -ForegroundColor Yellow

    # Generar un HTML extremadamente simple usando concatenación de cadenas
    $minimalHtml = "<!DOCTYPE html>" + "`r`n" +
                   "<html>" + "`r`n" +
                   "<head>" + "`r`n" + # [cite: 1]
                   '    <meta charset="utf-8">' + "`r`n" + # Usar comillas simples para el valor de charset [cite: 1]
                   "    <title>Reporte de Prueba Super Minimalista</title>" + "`r`n" + # [cite: 1]
                   "</head>" + "`r`n" + # [cite: 1]
                   "<body>" + "`r`n" + # [cite: 1]
                   "    <h1>Prueba Super Minimalista</h1>" + "`r`n" + # [cite: 1]
                   "    <p>Esto es un reporte HTML generado con concatenacion de cadenas.</p>" + "`r`n" + # [cite: 1]
                   "    <p>Fecha: $(Get-Date)</p>" + "`r`n" + # La interpolación aquí debería funcionar [cite: 1]
                   "</body>" + "`r`n" + # [cite: 1]
                   "</html>" # [cite: 1]

    Write-Host "[DEBUG] HTML Super Minimalista Generado:" -ForegroundColor Cyan # [cite: 1]
    Write-Host $minimalHtml # Imprimir el HTML a la consola [cite: 1]

    $tempHtmlPath = "$env:TEMP\debug_blindaje_report_super_minimal_concat.html" # [cite: 1]
    try {
        Set-Content -Path $tempHtmlPath -Value $minimalHtml -Encoding UTF8 -ErrorAction Stop # [cite: 1]
        Write-Host "[DEBUG] HTML super minimalista guardado en: $tempHtmlPath" -ForegroundColor Green # [cite: 1]
    } catch {
        Write-Host "[DEBUG] Error al guardar HTML super minimalista en $tempHtmlPath : $_" -ForegroundColor Red # [cite: 1]
    }
    Write-Log "Export-HtmlReport (modo debug super minimalista concat) ejecutado. Ver consola y $tempHtmlPath." # [cite: 1]
    return 
}

Export-ModuleMember -Function 'Export-HtmlReport'