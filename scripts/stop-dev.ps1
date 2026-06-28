$apiPort = 8000
$tunnelPort = 3307

$apiPids = (Get-NetTCPConnection -LocalPort $apiPort -State Listen -ErrorAction SilentlyContinue).OwningProcess | Select-Object -Unique
if ($apiPids) {
    foreach ($p in $apiPids) {
        Write-Host "Stopping API (PID $p)..."
        Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "API not running."
}

$tunnelPids = (Get-NetTCPConnection -LocalPort $tunnelPort -State Listen -ErrorAction SilentlyContinue).OwningProcess | Select-Object -Unique
if ($tunnelPids) {
    foreach ($p in $tunnelPids) {
        Write-Host "Stopping SSH tunnel (PID $p)..."
        Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "SSH tunnel not running."
}
