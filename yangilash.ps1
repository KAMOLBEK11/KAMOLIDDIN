# Global Strategiya - avtomatik yangilanish (GitHub: KAMOLBEK11/KAMOLIDDIN, "oyin" tarmog'i)
# OYINNI_BOSHLASH.bat har safar o'yin oldidan shuni ishga tushiradi.
#
# Faqat O'ZGARGAN fayllarni yuklaydi. Butun loyiha ~150 MB, lekin odatda
# bir yangilanishda bir necha fayl o'zgaradi - shuning uchun bir necha soniya ketadi.
# Birinchi marta yoki juda ko'p fayl o'zgarsa - butun ZIP yuklanadi.

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ErrorActionPreference = 'Stop'

function Hajm($b) {
    if ($b -ge 1MB) { return "{0:N1} MB" -f ($b / 1MB) }
    return "{0:N0} KB" -f ($b / 1KB)
}

try {
    [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
    $ProgressPreference = 'SilentlyContinue'
    $hdr = @{ 'User-Agent' = 'GlobalStrategiya-updater' }

    $api = Invoke-RestMethod -Uri 'https://api.github.com/repos/KAMOLBEK11/KAMOLIDDIN/commits/oyin' -Headers $hdr -TimeoutSec 20
    $sha = $api.sha
    $vf  = Join-Path $root 'versiya.txt'
    $old = ''
    if (Test-Path $vf) { $old = (Get-Content $vf -Raw).Trim() }

    if ($sha -eq $old) { Write-Host "O'yin eng yangi versiyada."; exit 0 }

    Write-Host "Yangilanish topildi: $($api.commit.message.Split("`n")[0])"

    # --- faqat o'zgargan fayllarni olishga urinamiz ---
    $qisman = $false
    $fayllar = @()
    if ($old -and $old -match '^[0-9a-f]{40}$') {
        try {
            $cmp = Invoke-RestMethod -Headers $hdr -TimeoutSec 30 `
                -Uri "https://api.github.com/repos/KAMOLBEK11/KAMOLIDDIN/compare/$old...$sha"
            # GitHub ro'yxatda eng ko'pi 300 ta fayl beradi; shuncha bo'lsa qisqargan
            # bo'lishi mumkin - ishonchsiz, to'liq ZIP olamiz
            if ($cmp.files -and $cmp.files.Count -gt 0 -and $cmp.files.Count -lt 300) {
                $fayllar = $cmp.files
                $qisman  = $true
            }
        } catch {
            Write-Host "  (farqni aniqlab bo'lmadi, to'liq yuklanadi)"
        }
    }

    if ($qisman) {
        Write-Host "  $($fayllar.Count) ta fayl o'zgargan - faqat shular yuklanadi"
        $n = 0
        foreach ($f in $fayllar) {
            $n++
            $yol = Join-Path $root ($f.filename -replace '/', '\')
            $pct = [int](100 * $n / $fayllar.Count)

            # nomi o'zgargan bo'lsa eskisini o'chiramiz
            if ($f.previous_filename) {
                Remove-Item (Join-Path $root ($f.previous_filename -replace '/', '\')) `
                    -Force -ErrorAction SilentlyContinue
            }
            if ($f.status -eq 'removed') {
                Remove-Item $yol -Force -ErrorAction SilentlyContinue
                continue
            }
            # OYINNI_BOSHLASH.bat ishlab turganda o'zini almashtira olmaydi
            if ($f.filename -eq 'OYINNI_BOSHLASH.bat') { continue }

            $papka = Split-Path -Parent $yol
            if ($papka -and -not (Test-Path $papka)) { New-Item -ItemType Directory $papka -Force | Out-Null }

            # bo'shliq va boshqa belgilar uchun har bo'lakni alohida kodlaymiz
            $enc = (($f.filename -split '/') | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
            $url = "https://raw.githubusercontent.com/KAMOLBEK11/KAMOLIDDIN/$sha/$enc"

            Write-Host ("  [{0,3}%] {1}" -f $pct, $f.filename)
            $ok = $false
            foreach ($urinish in 1..3) {
                try {
                    Invoke-WebRequest -Uri $url -OutFile $yol -UseBasicParsing -TimeoutSec 300 -Headers $hdr
                    $ok = $true
                    break
                } catch {
                    if ($urinish -eq 3) { throw }
                    Start-Sleep -Seconds 2
                }
            }
            if (-not $ok) { throw "Yuklab bo'lmadi: $($f.filename)" }
        }
        Set-Content -Path $vf -Value $sha
        Write-Host "Yangilandi!"
        exit 0
    }

    # --- to'liq ZIP (birinchi marta yoki juda ko'p o'zgarish) ---
    Write-Host "  To'liq yuklanmoqda (~150 MB, internetga qarab 3-10 daqiqa)..."
    $tmp = Join-Path $env:TEMP 'globalstrategiya_update'
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $tmp | Out-Null
    $zip = Join-Path $tmp 'u.zip'

    # progress ko'rinishi uchun oqim bilan yuklaymiz
    $req  = [Net.HttpWebRequest]::Create("https://codeload.github.com/KAMOLBEK11/KAMOLIDDIN/zip/$sha")
    $req.UserAgent = 'GlobalStrategiya-updater'
    $req.Timeout = 60000
    $resp = $req.GetResponse()
    $total = $resp.ContentLength
    $in  = $resp.GetResponseStream()
    $out = [IO.File]::Create($zip)
    $buf = New-Object byte[] 262144
    $got = 0
    $oxirgi = -1
    while (($o = $in.Read($buf, 0, $buf.Length)) -gt 0) {
        $out.Write($buf, 0, $o)
        $got += $o
        if ($total -gt 0) {
            $pct = [int](100 * $got / $total)
            if ($pct -ne $oxirgi -and $pct % 2 -eq 0) {
                $oxirgi = $pct
                Write-Host ("`r  {0,3}%  {1} / {2}   " -f $pct, (Hajm $got), (Hajm $total)) -NoNewline
            }
        } else {
            Write-Host ("`r  {0}   " -f (Hajm $got)) -NoNewline
        }
    }
    $out.Close(); $in.Close(); $resp.Close()
    Write-Host ""

    Write-Host "  Ochilmoqda..."
    Expand-Archive $zip $tmp -Force
    $src = Get-ChildItem $tmp -Directory | Select-Object -First 1
    robocopy $src.FullName $root /E /XF OYINNI_BOSHLASH.bat /NFL /NDL /NJH /NJS /NP | Out-Null
    Set-Content -Path $vf -Value $sha
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Yangilandi!"
}
catch {
    Write-Host ""
    Write-Host "Yangilanishni tekshirib bo'lmadi: $($_.Exception.Message)"
    Write-Host "O'yin hozirgi holatda ochiladi."
}
