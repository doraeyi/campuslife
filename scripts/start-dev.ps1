$tunnelPort = 3307
$apiPort = 8000
$apiDir = Join-Path $PSScriptRoot "..\api"

$tunnelOpen = Test-NetConnection -ComputerName 127.0.0.1 -Port $tunnelPort -WarningAction SilentlyContinue -InformationLevel Quiet
if (-not $tunnelOpen) {
    Write-Host "Starting SSH tunnel to NAS MySQL (3307 -> NAS:3306)..."
    Start-Process -FilePath "ssh" `
        -ArgumentList "-N", "-L", "${tunnelPort}:127.0.0.1:3306", "-p", "1122", "liam@kaikaizhen.myasustor.com" `
        -WindowStyle Hidden
} else {
    Write-Host "SSH tunnel already running on port $tunnelPort."
}

$apiRunning = Test-NetConnection -ComputerName 127.0.0.1 -Port $apiPort -WarningAction SilentlyContinue -InformationLevel Quiet
if (-not $apiRunning) {
    Write-Host "Starting FastAPI on port $apiPort..."
    Start-Process -FilePath "$apiDir\venv\Scripts\python.exe" `
        -ArgumentList "-m", "uvicorn", "main:app", "--port", "$apiPort" `
        -WorkingDirectory $apiDir `
        -WindowStyle Hidden `
        -RedirectStandardOutput "$apiDir\uvicorn.log" `
        -RedirectStandardError "$apiDir\uvicorn.err.log"
} else {
    Write-Host "API already running on port $apiPort."
}

Write-Host "Ready. Swagger docs: http://127.0.0.1:$apiPort/docs"
