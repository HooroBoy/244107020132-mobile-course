<#
.SYNOPSIS
    Kirim notifikasi uji FCM HTTP v1 untuk Campus Notify (versi tanpa dependensi).

.DESCRIPTION
    Padanan tools/send_fcm.py untuk Windows yang belum punya paket Python
    `requests`/`google-auth`. Hanya memakai PowerShell + openssl.exe (biasanya
    sudah ada bila Git/Laragon/XAMPP terpasang) + curl.exe bawaan Windows 10+.

    Payload, topik, dan channel_id sengaja sama dengan versi Python supaya hasil
    pengujian kedua alat bisa dibandingkan.

.PRASYARAT
    .secrets/service-account.json
    (Firebase Console -> Project settings -> Service accounts -> Generate new private key)

.CONTOH
    powershell -ExecutionPolicy Bypass -File tools/send_fcm.ps1
    powershell -ExecutionPolicy Bypass -File tools/send_fcm.ps1 -Id 7
    powershell -ExecutionPolicy Bypass -File tools/send_fcm.ps1 -Token "<FCM token>"
    powershell -ExecutionPolicy Bypass -File tools/send_fcm.ps1 -DataOnly
#>
param(
    [string]$Id = '3',
    [string]$Token = '',
    [switch]$DataOnly
)

$ErrorActionPreference = 'Stop'

$Topic = 'pengumuman-kampus'
# Harus sama dengan kAnnouncementChannel.id di lib/messaging/push_service.dart.
$ChannelId = 'pengumuman_v2'

$root = Split-Path -Parent $PSScriptRoot
$credPath = Join-Path $root '.secrets\service-account.json'

if (-not (Test-Path $credPath)) {
    throw "Service account tidak ditemukan: $credPath`nUnduh dari Firebase Console -> Project settings -> Service accounts -> Generate new private key."
}

$openssl = (Get-Command openssl -ErrorAction SilentlyContinue).Source
if (-not $openssl) {
    throw 'openssl tidak ditemukan di PATH. Pasang Git for Windows (menyertakan openssl) atau gunakan tools/send_fcm.py.'
}

$sa = Get-Content $credPath -Raw | ConvertFrom-Json
$project = $sa.project_id

function ConvertTo-Base64Url([byte[]]$Bytes) {
    [Convert]::ToBase64String($Bytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')
}

function ConvertTo-Base64UrlString([string]$Text) {
    ConvertTo-Base64Url ([Text.Encoding]::UTF8.GetBytes($Text))
}

# --- 1. Tanda tangani JWT RS256 dengan kunci service account -----------------
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$header = ConvertTo-Base64UrlString '{"alg":"RS256","typ":"JWT"}'
$claims = ConvertTo-Base64UrlString (@{
    iss   = $sa.client_email
    scope = 'https://www.googleapis.com/auth/firebase.messaging'
    aud   = 'https://oauth2.googleapis.com/token'
    iat   = $now
    exp   = $now + 3600
} | ConvertTo-Json -Compress)

$tmp = Join-Path ([IO.Path]::GetTempPath()) 'campusnotif-fcm'
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$keyFile = Join-Path $tmp 'key.pem'
$inFile = Join-Path $tmp 'jwt.txt'
$sigFile = Join-Path $tmp 'jwt.sig'

$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($keyFile, $sa.private_key, $utf8)
[IO.File]::WriteAllText($inFile, "$header.$claims", $utf8)

& $openssl dgst -sha256 -sign $keyFile -out $sigFile $inFile
if ($LASTEXITCODE -ne 0) { throw 'openssl gagal menandatangani JWT.' }

$assertion = "$header.$claims." + (ConvertTo-Base64Url ([IO.File]::ReadAllBytes($sigFile)))

# --- 2. Tukar JWT dengan access token ---------------------------------------
$tokenResponse = & curl.exe -s -X POST 'https://oauth2.googleapis.com/token' `
    -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$assertion" |
    ConvertFrom-Json

if (-not $tokenResponse.access_token) {
    throw "Gagal memperoleh access token: $($tokenResponse | ConvertTo-Json -Compress)"
}

# --- 3. Susun pesan (sama dengan build_message di send_fcm.py) --------------
$route = "/pengumuman/$Id"
$message = @{
    data    = @{ route = $route; id = "$Id" }
    android = @{
        priority     = 'high'
        notification = @{ channel_id = $ChannelId }
    }
}

if ($Token) {
    $message['token'] = $Token
} else {
    $message['topic'] = $Topic
}

if (-not $DataOnly) {
    $message['notification'] = @{
        title = 'Jadwal kuliah berubah'
        body  = "Kelas Mobile pindah ke Ruang A2 jam 13.00 (id $Id)"
    }
}

$payload = @{ message = $message } | ConvertTo-Json -Depth 8 -Compress
$bodyFile = Join-Path $tmp 'body.json'
[IO.File]::WriteAllText($bodyFile, $payload, $utf8)

# --- 4. Kirim ---------------------------------------------------------------
$target = if ($Token) { $Token.Substring(0, [Math]::Min(12, $Token.Length)) + '...' } else { "topic $Topic" }
Write-Output "project : $project"
Write-Output "target  : $target"
Write-Output "data    : route=$route id=$Id"
Write-Output "channel : $ChannelId"

$response = & curl.exe -s -w "`nHTTP:%{http_code}" -X POST `
    "https://fcm.googleapis.com/v1/projects/$project/messages:send" `
    -H "Authorization: Bearer $($tokenResponse.access_token)" `
    -H 'Content-Type: application/json; charset=utf-8' `
    --data-binary "@$bodyFile"

# curl mengembalikan baris-baris; gabungkan dulu agar -match bekerja pada
# satu string (pada array, -notmatch mengembalikan elemen yang tidak cocok).
$responseText = ($response | Out-String).Trim()
Write-Output $responseText
if ($responseText -notmatch 'HTTP:200') { exit 1 }
