$port = 8092
$folder = "C:\Work\Presentation"

# Wi-Fi 및 로컬 IP 감지
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.*"
} | Select-Object -ExpandProperty IPAddress -First 1)

if (-not $ip) { $ip = "192.168.45.228" }

$localUrl = "http://localhost:${port}/"
$tabletUrl = "http://${ip}:${port}/"

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)

try {
    $listener.Start()
    Clear-Host
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host "  🐿️ 말랑이의 말하기 탐험대 웹 서버가 시작되었습니다!              " -ForegroundColor Green
    Write-Host "==================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  💻 [현재 PC 브라우저 접속 웹링크]" -ForegroundColor Gray
    Write-Host "  👉 $localUrl" -ForegroundColor White
    Write-Host ""
    Write-Host "  📱 [아이 태블릿 / 스마트폰 접속 웹링크]" -ForegroundColor Yellow
    Write-Host "  👉 $tabletUrl" -ForegroundColor Yellow -BackgroundColor DarkBlue
    Write-Host ""
    Write-Host "  ※ 아이 태블릿이나 폰이 이 PC와 같은 Wi-Fi에 연결되어 있으면 바로 열립니다." -ForegroundColor White
    Write-Host "  종료하려면 이 창을 닫거나 Ctrl + C 를 누르세요." -ForegroundColor DarkGray
    Write-Host "==================================================================" -ForegroundColor Cyan

    Start-Process $localUrl

    while ($true) {
        try {
            $client = $listener.AcceptTcpClient()
            $client.ReceiveTimeout = 3000
            $client.SendTimeout = 3000
            $stream = $client.GetStream()
            $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8)

            $requestLine = $reader.ReadLine()
            if (-not $requestLine) {
                $client.Close()
                continue
            }

            $parts = $requestLine.Split(" ")
            $urlPath = if ($parts.Length -ge 2) { $parts[1].Split("?")[0].TrimStart('/') } else { "" }
            if ([string]::IsNullOrWhiteSpace($urlPath)) {
                $urlPath = "index.html"
            }

            # 헤더 비우기
            while (-not [string]::IsNullOrWhiteSpace($reader.ReadLine())) {}

            $filePath = Join-Path $folder $urlPath

            if (Test-Path $filePath -PathType Leaf) {
                $bytes = [System.IO.File]::ReadAllBytes($filePath)
                $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                $mime = switch ($ext) {
                    ".html" { "text/html; charset=utf-8" }
                    ".css"  { "text/css; charset=utf-8" }
                    ".js"   { "application/javascript; charset=utf-8" }
                    ".json" { "application/json; charset=utf-8" }
                    ".png"  { "image/png" }
                    ".svg"  { "image/svg+xml" }
                    ".ico"  { "image/x-icon" }
                    Default { "application/octet-stream" }
                }

                $header = "HTTP/1.1 200 OK`r`nContent-Type: $mime`r`nContent-Length: $($bytes.Length)`r`nAccess-Control-Allow-Origin: *`r`nConnection: close`r`n`r`n"
                $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
                $stream.Write($headerBytes, 0, $headerBytes.Length)
                $stream.Write($bytes, 0, $bytes.Length)
            } else {
                $body = "404 Not Found"
                $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
                $header = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain`r`nContent-Length: $($bodyBytes.Length)`r`nConnection: close`r`n`r`n"
                $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
                $stream.Write($headerBytes, 0, $headerBytes.Length)
                $stream.Write($bodyBytes, 0, $bodyBytes.Length)
            }

            $stream.Flush()
            $client.Close()
        } catch {
            # 요청 처리 중 예외 발생 시 안전하게 닫기
            if ($client) { $client.Close() }
        }
    }
} finally {
    $listener.Stop()
}
