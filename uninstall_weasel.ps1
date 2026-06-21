param(
  [string]$RimeUserDir = "$env:APPDATA\Rime"
)

$ErrorActionPreference = "Stop"

$schemaIds = @("mars_pinyin_mild", "mars_pinyin", "mars_pinyin_heavy")
$ownedFiles = @(
  "mars_pinyin.schema.yaml",
  "mars_pinyin_mild.schema.yaml",
  "mars_pinyin_heavy.schema.yaml",
  "mars_pinyin_mild.dict.yaml",
  "mars_pinyin_classic.dict.yaml",
  "mars_pinyin_heavy.dict.yaml",
  "opencc\mars_mild.json",
  "opencc\mars_classic.json",
  "opencc\mars_heavy.json",
  "opencc\mars_phrases_mild.txt",
  "opencc\mars_phrases_classic.txt",
  "opencc\mars_phrases_heavy.txt",
  "opencc\mars_chars_mild.txt",
  "opencc\mars_chars_classic.txt",
  "opencc\mars_chars_heavy.txt",
  "lua\mars_variants.lua",
  "lua\mars_candidates.lua",
  "lua\mars_methods_data.lua",
  "lua\mars_stage2_processor.lua",
  "lua\mars_stage2_processor_v42.lua",
  "lua\mars_stage2_translator.lua",
  "lua\mars_stage2_translator_v42.lua"
)

$defaultCustom = Join-Path $RimeUserDir "default.custom.yaml"
if (Test-Path $defaultCustom) {
  $timestamp = Get-Date -Format "yyyyMMddHHmmss"
  Copy-Item $defaultCustom "$defaultCustom.bak.$timestamp" -Force
  $lines = Get-Content $defaultCustom -Encoding UTF8
  $filtered = foreach ($line in $lines) {
    $isOwnedSchema = $false
    foreach ($schema in $schemaIds) {
      if ($line -match "^\s*-\s*schema:\s*$([regex]::Escape($schema))\s*$") {
        $isOwnedSchema = $true
        break
      }
    }
    if (-not $isOwnedSchema) {
      $line
    }
  }
  Set-Content -Path $defaultCustom -Value $filtered -Encoding UTF8
}

foreach ($relativePath in $ownedFiles) {
  $path = Join-Path $RimeUserDir $relativePath
  if (Test-Path $path) {
    Remove-Item -LiteralPath $path -Force
  }
}

Write-Host "Mars language Rime files removed from: $RimeUserDir"
Write-Host "Please redeploy Weasel from the tray menu."
