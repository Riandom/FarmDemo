$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$projectRoot = Split-Path -Parent $PSScriptRoot
$itemDir = Join-Path $projectRoot "assets/sprites/placeholder/items"
$cropDir = Join-Path $projectRoot "assets/sprites/placeholder/crops"

$seedTemplate = Join-Path $itemDir "seed_wheat.png"
$cropTemplate = Join-Path $itemDir "crop_wheat.png"
$stageTemplates = @(0, 1, 2, 3) | ForEach-Object { Join-Path $cropDir ("wheat_stage_{0}.png" -f $_) }

$crops = @(
    @{ stem = "wheat"; seed = "#8DBE45"; crop = "#E7C559" }
    @{ stem = "turnip"; seed = "#C7E36A"; crop = "#E7F0D1" }
    @{ stem = "cabbage"; seed = "#78C657"; crop = "#5DA44F" }
    @{ stem = "strawberry"; seed = "#E98AA0"; crop = "#E84B63" }
    @{ stem = "pea"; seed = "#8DE77B"; crop = "#5FCF6A" }
    @{ stem = "tomato"; seed = "#D6D04B"; crop = "#D94A43" }
    @{ stem = "corn"; seed = "#E5C94C"; crop = "#F0D866" }
    @{ stem = "pepper"; seed = "#E7744C"; crop = "#D63D29" }
    @{ stem = "watermelon"; seed = "#5CBF5C"; crop = "#E85F72" }
    @{ stem = "cucumber"; seed = "#7FCB67"; crop = "#4FAE55" }
    @{ stem = "pumpkin"; seed = "#E3A249"; crop = "#D8792B" }
    @{ stem = "sweet_potato"; seed = "#C78458"; crop = "#B25A34" }
    @{ stem = "eggplant"; seed = "#8C69C9"; crop = "#6E48A8" }
    @{ stem = "carrot"; seed = "#F0B255"; crop = "#E07D2B" }
    @{ stem = "rice"; seed = "#D9C778"; crop = "#C9B15D" }
)

function Get-TintColor([string]$hex) {
    return [System.Drawing.ColorTranslator]::FromHtml($hex)
}

function Ensure-Directory([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }
}

function Save-TintedImage([string]$sourcePath, [string]$destPath, [System.Drawing.Color]$targetColor, [double]$minFactor = 0.38) {
    $sourceBitmap = [System.Drawing.Bitmap]::new($sourcePath)
    $bitmap = [System.Drawing.Bitmap]::new($sourceBitmap)
    $sourceBitmap.Dispose()
    try {
        for ($x = 0; $x -lt $bitmap.Width; $x++) {
            for ($y = 0; $y -lt $bitmap.Height; $y++) {
                $pixel = $bitmap.GetPixel($x, $y)
                if ($pixel.A -eq 0) {
                    continue
                }

                $brightness = ($pixel.R + $pixel.G + $pixel.B) / 765.0
                $factor = [Math]::Max($minFactor, $brightness)
                $r = [Math]::Min(255, [int]($targetColor.R * $factor))
                $g = [Math]::Min(255, [int]($targetColor.G * $factor))
                $b = [Math]::Min(255, [int]($targetColor.B * $factor))
                $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($pixel.A, $r, $g, $b))
            }
        }

        $sourceFullPath = [System.IO.Path]::GetFullPath($sourcePath)
        $destFullPath = [System.IO.Path]::GetFullPath($destPath)
        if ($sourceFullPath -eq $destFullPath) {
            $tempPath = "{0}.tmp" -f $destPath
            $bitmap.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
            Move-Item -LiteralPath $tempPath -Destination $destPath -Force
        }
        else {
            $bitmap.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
    }
    finally {
        $bitmap.Dispose()
    }
}

function Get-StageColor([System.Drawing.Color]$baseColor, [int]$stageIndex) {
    $factors = @(0.45, 0.65, 0.82, 1.0)
    $factor = $factors[$stageIndex]
    $r = [Math]::Min(255, [int]($baseColor.R * $factor))
    $g = [Math]::Min(255, [int]($baseColor.G * $factor))
    $b = [Math]::Min(255, [int]($baseColor.B * $factor))
    return [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
}

Ensure-Directory $itemDir
Ensure-Directory $cropDir

foreach ($crop in $crops) {
    $stem = $crop.stem
    $seedColor = Get-TintColor $crop.seed
    $cropColor = Get-TintColor $crop.crop

    Save-TintedImage $seedTemplate (Join-Path $itemDir ("seed_{0}.png" -f $stem)) $seedColor 0.42
    Save-TintedImage $cropTemplate (Join-Path $itemDir ("crop_{0}.png" -f $stem)) $cropColor 0.38

    for ($stage = 0; $stage -lt 4; $stage++) {
        $stageColor = Get-StageColor $cropColor $stage
        Save-TintedImage $stageTemplates[$stage] (Join-Path $cropDir ("{0}_stage_{1}.png" -f $stem, $stage)) $stageColor 0.34
    }
}

Write-Host ("[generate_crop_placeholders] generated assets for {0} crops" -f $crops.Count)
