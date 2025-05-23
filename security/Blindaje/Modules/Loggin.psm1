function Write-Log {
    param([string]$Msg)
    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content -Path $Cfg.LogPath -Value "[$stamp] $Msg"
}
Export-ModuleMember -Function 'Write-Log'