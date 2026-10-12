# Gera o icone monocromatico de notificacao (silhueta da logo CiNey).
# O Android tinge o small icon; por isso ele precisa ser branco com alpha.
# A silhueta usa os pixels laranjas da logo: o "C" e o play viram recortes.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = 'g:\Filmes e Séries (Criado por Ney)'
$sourcePath = Join-Path $root 'cinemax\assets\icon\nova logo.png'

$src = [System.Drawing.Bitmap]::FromFile($sourcePath)

# Mesma deteccao de caixa laranja do apply_new_logo.ps1
$rect = New-Object System.Drawing.Rectangle(0, 0, $src.Width, $src.Height)
$data = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bytes = New-Object byte[] ($data.Stride * $data.Height)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
$stride = $data.Stride
$src.UnlockBits($data)

$minX = $src.Width; $minY = $src.Height; $maxX = -1; $maxY = -1
for ($y = 0; $y -lt $src.Height; $y++) {
    $row = $y * $stride
    for ($x = 0; $x -lt $src.Width; $x++) {
        $i = $row + ($x * 4)
        $b = $bytes[$i]; $g = $bytes[$i + 1]; $r = $bytes[$i + 2]; $a = $bytes[$i + 3]
        if ($a -gt 200 -and $r -gt 180 -and $g -gt 40 -and $g -lt 175 -and $b -lt 90) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}
if ($maxX -lt 0) { throw 'Regiao laranja nao encontrada.' }

$boxW = $maxX - $minX + 1
$boxH = $maxY - $minY + 1
$side = [int]([Math]::Max($boxW, $boxH) * 1.03)
$cx = $minX + [int]($boxW / 2)
$cy = $minY + [int]($boxH / 2)
$cropX = [Math]::Max(0, [Math]::Min($src.Width - $side, $cx - [int]($side / 2)))
$cropY = [Math]::Max(0, [Math]::Min($src.Height - $side, $cy - [int]($side / 2)))

# Constroi a silhueta: laranja vira branco opaco; o resto fica transparente
$silhouette = New-Object System.Drawing.Bitmap($side, $side)
for ($y = 0; $y -lt $side; $y++) {
    $srcY = $cropY + $y
    $row = $srcY * $stride
    for ($x = 0; $x -lt $side; $x++) {
        $srcX = $cropX + $x
        $i = $row + ($srcX * 4)
        $b = $bytes[$i]; $g = $bytes[$i + 1]; $r = $bytes[$i + 2]; $a = $bytes[$i + 3]
        $isOrange = ($a -gt 200 -and $r -gt 180 -and $g -gt 40 -and $g -lt 175 -and $b -lt 90)
        if ($isOrange) {
            $silhouette.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, 255, 255, 255))
        } else {
            $silhouette.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
        }
    }
}
$src.Dispose()

# Densidades do small icon de notificacao (24dp)
$densities = @{ 'mdpi' = 24; 'hdpi' = 36; 'xhdpi' = 48; 'xxhdpi' = 72; 'xxxhdpi' = 96 }
foreach ($project in @('cinemax', 'cinemax_tv')) {
    foreach ($density in $densities.GetEnumerator()) {
        $size = $density.Value
        $bmp = New-Object System.Drawing.Bitmap($size, $size)
        $g2 = [System.Drawing.Graphics]::FromImage($bmp)
        $g2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g2.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g2.Clear([System.Drawing.Color]::Transparent)
        $dest = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
        $srcRect = New-Object System.Drawing.Rectangle(0, 0, $side, $side)
        $g2.DrawImage($silhouette, $dest, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
        $g2.Dispose()
        $outDir = Join-Path $root "$project\android\app\src\main\res\drawable-$($density.Key)"
        if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
        $outPath = Join-Path $outDir 'ic_notification.png'
        $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        Write-Host "Gerado: $outPath ($size x $size)"
    }
}
$silhouette.Dispose()
Write-Host 'Icone de notificacao gerado com sucesso.'
