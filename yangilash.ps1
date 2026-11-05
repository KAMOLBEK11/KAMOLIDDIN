# Global Strategiya - avtomatik yangilanish (GitHub: KAMOLBEK11/KAMOLIDDIN, "oyin" tarmog'i)
# OYINNI_BOSHLASH.bat har safar o'yin oldidan shuni ishga tushiradi.
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
try {
    [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
    $ProgressPreference = 'SilentlyContinue'
    $api = Invoke-RestMethod -Uri 'https://api.github.com/repos/KAMOLBEK11/KAMOLIDDIN/commits/oyin' -Headers @{ 'User-Agent' = 'GlobalStrategiya-updater' } -TimeoutSec 20
    $sha = $api.sha
    $vf = Join-Path $root 'versiya.txt'
    $old = ''
    if (Test-Path $vf) { $old = (Get-Content $vf -Raw).Trim() }
    if ($sha -eq $old) { Write-Host "O'yin eng yangi versiyada."; exit 0 }
    Write-Host "Yangilanish topildi: $($api.commit.message.Split("`n")[0])"
    Write-Host "Yuklab olinmoqda..."
    $tmp = Join-Path $env:TEMP 'globalstrategiya_update'
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $tmp | Out-Null
    $zip = Join-Path $tmp 'u.zip'
    Invoke-WebRequest -Uri "https://codeload.github.com/KAMOLBEK11/KAMOLIDDIN/zip/$sha" -OutFile $zip -UseBasicParsing -TimeoutSec 600
    Expand-Archive $zip $tmp -Force
    $src = Get-ChildItem $tmp -Directory | Select-Object -First 1
    robocopy $src.FullName $root /E /XF OYINNI_BOSHLASH.bat /NFL /NDL /NJH /NJS /NP | Out-Null
    Set-Content -Path $vf -Value $sha
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Yangilandi!"
} catch {
    Write-Host "Yangilanishni tekshirib bo'lmadi (internet yo'qmi?). O'yin hozirgi holatda ochiladi."
}
