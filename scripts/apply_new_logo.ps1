# Aplica a nova identidade visual do CiNey a partir de cinemax/assets/icon/nova logo.png
# Gera: logo.png (images/icons), app_icon.png, app_icon.ico e ic_launcher.png (mobile + TV)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = 'g:\Filmes e Séries (Criado por Ney)'
$sourcePath = Join-Path $root 'cinemax\assets\icon\nova logo.png'

$src = [System.Drawing.Bitmap]::FromFile($sourcePath)
Write-Host "Fonte: $($src.Width)x$($src.Height)"

# --- 1. Localiza a caixa delimitadora dos pixels laranjas (o quadrado do icone) ---
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
if ($maxX -lt 0) { throw 'Regiao laranja nao encontrada na imagem.' }
Write-Host "Icone detectado: x=$minX..$maxX y=$minY..$maxY"

# --- 2. Recorte quadrado com margem de 3% ---
$boxW = $maxX - $minX + 1
$boxH = $maxY - $minY + 1
$side = [int]([Math]::Max($boxW, $boxH) * 1.03)
$cx = $minX + [int]($boxW / 2)
$cy = $minY + [int]($boxH / 2)
$cropX = [Math]::Max(0, [Math]::Min($src.Width - $side, $cx - [int]($side / 2)))
$cropY = [Math]::Max(0, [Math]::Min($src.Height - $side, $cy - [int]($side / 2)))
Write-Host "Recorte quadrado: ${side}px em ($cropX,$cropY)"

function Save-Resized {
    param([int]$Size, [string]$Path)
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $dest = New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)
    $srcRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $side, $side)
    $g.DrawImage($src, $dest, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Gerado: $Path ($Size x $Size)"
}

# --- 3. Logos do app (UI) e icone mestre ---
Save-Resized -Size 512 -Path (Join-Path $root 'cinemax\assets\images\logo.png')
Save-Resized -Size 512 -Path (Join-Path $root 'cinemax\assets\icons\logo.png')
Save-Resized -Size 1024 -Path (Join-Path $root 'cinemax\assets\icon\app_icon.png')

# --- 4. ic_launcher.png nas densidades Android (mobile + TV) ---
$densities = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($project in @('cinemax', 'cinemax_tv')) {
    foreach ($density in $densities.GetEnumerator()) {
        $path = Join-Path $root "$project\android\app\src\main\res\mipmap-$($density.Key)\ic_launcher.png"
        Save-Resized -Size $density.Value -Path $path
    }
}

# --- 5. app_icon.ico multi-tamanho (entradas PNG) ---
$icoSizes = @(16, 24, 32, 48, 64, 128, 256)
$pngBlobs = @()
foreach ($size in $icoSizes) {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    $dest = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
    $srcRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $side, $side)
    $g.DrawImage($src, $dest, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $pngBlobs += ,$ms.ToArray()
    $ms.Dispose()
}
$icoPath = Join-Path $root 'cinemax\assets\icon\app_icon.ico'
$fs = [System.IO.File]::Create($icoPath)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([uint16]0)              # reservado
$bw.Write([uint16]1)              # tipo: icone
$bw.Write([uint16]$icoSizes.Count)
$offset = 6 + (16 * $icoSizes.Count)
for ($i = 0; $i -lt $icoSizes.Count; $i++) {
    $size = $icoSizes[$i]
    $blob = $pngBlobs[$i]
    $bw.Write([byte]($(if ($size -ge 256) { 0 } else { $size })))
    $bw.Write([byte]($(if ($size -ge 256) { 0 } else { $size })))
    $bw.Write([byte]0)            # paleta
    $bw.Write([byte]0)            # reservado
    $bw.Write([uint16]1)          # planos
    $bw.Write([uint16]32)         # bits por pixel
    $bw.Write([uint32]$blob.Length)
    $bw.Write([uint32]$offset)
    $offset += $blob.Length
}
foreach ($blob in $pngBlobs) { $bw.Write($blob) }
$bw.Dispose(); $fs.Dispose()
Write-Host "Gerado: $icoPath"

$src.Dispose()
Write-Host 'Nova identidade visual aplicada com sucesso.'
