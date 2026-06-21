param(
  [string]$RimeUserDir = "$env:APPDATA\Rime",
  [switch]$SkipWeaselCheck
)

$ErrorActionPreference = "Stop"

function Find-WeaselInstallation {
  $roots = @()
  $programFiles = [Environment]::GetEnvironmentVariable("ProgramFiles")
  $programFilesX86 = [Environment]::GetEnvironmentVariable("ProgramFiles(x86)")
  $localAppData = [Environment]::GetEnvironmentVariable("LOCALAPPDATA")
  if ($programFiles) { $roots += (Join-Path $programFiles "Rime") }
  if ($programFilesX86) { $roots += (Join-Path $programFilesX86 "Rime") }
  if ($localAppData) { $roots += (Join-Path $localAppData "Programs\Rime") }
  $roots = $roots | Where-Object { Test-Path $_ }

  foreach ($root in $roots) {
    $deployer = Get-ChildItem -Path $root -Filter "WeaselDeployer.exe" -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($deployer) {
      return $deployer.FullName
    }
  }

  $registryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
  )
  foreach ($registryPath in $registryPaths) {
    $entry = Get-ItemProperty $registryPath -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "Weasel|小狼毫" } | Select-Object -First 1
    if ($entry) {
      return $entry.InstallLocation
    }
  }
  return $null
}

function Add-SchemaEntry {
  param(
    [string[]]$Lines,
    [string]$Schema
  )

  $Lines = @($Lines | Where-Object { $null -ne $_ })
  if ($Lines.Count -eq 0) {
    $Lines = @("# encoding: utf-8")
  }

  $joined = $Lines -join "`n"
  if ($joined -match "schema:\s*$([regex]::Escape($Schema))(\s|$)") {
    return $Lines
  }

  $schemaListIndex = -1
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match "^\s*schema_list:\s*$") {
      $schemaListIndex = $i
      break
    }
  }

  if ($schemaListIndex -ge 0) {
    $before = @()
    if ($schemaListIndex -gt 0) {
      $before = $Lines[0..$schemaListIndex]
    } else {
      $before = @($Lines[$schemaListIndex])
    }
    $after = @()
    if ($schemaListIndex + 1 -lt $Lines.Count) {
      $after = $Lines[($schemaListIndex + 1)..($Lines.Count - 1)]
    }
    return @($before + "    - schema: $Schema" + $after)
  }

  $patchIndex = -1
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match "^patch:\s*$") {
      $patchIndex = $i
      break
    }
  }

  if ($patchIndex -ge 0) {
    $before = $Lines[0..$patchIndex]
    $after = @()
    if ($patchIndex + 1 -lt $Lines.Count) {
      $after = $Lines[($patchIndex + 1)..($Lines.Count - 1)]
    }
    return @($before + "  schema_list:" + "    - schema: $Schema" + $after)
  }

  return @($Lines + "" + "patch:" + "  schema_list:" + "    - schema: $Schema")
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path (Join-Path $scriptDir "rime")) {
  $packageRoot = $scriptDir
} else {
  $packageRoot = Split-Path -Parent $scriptDir
}
$rimeSource = Join-Path $packageRoot "rime"
if (-not (Test-Path $rimeSource)) {
  throw "Cannot find rime directory at $rimeSource"
}

if (-not $SkipWeaselCheck) {
  $weaselInstallation = Find-WeaselInstallation
  if (-not $weaselInstallation) {
    Write-Error "未检测到小狼毫 Weasel。请先从 https://rime.im 下载安装，再运行此脚本。"
    exit 1
  }
}

New-Item -ItemType Directory -Force -Path $RimeUserDir | Out-Null
$timestamp = Get-Date -Format "yyyyMMddHHmmss"

$schemaSource = Join-Path $rimeSource "mars_pinyin.schema.yaml"
if (-not (Test-Path $schemaSource)) {
  throw "Missing core schema: $schemaSource"
}
Copy-Item -Path $schemaSource -Destination $RimeUserDir -Force

$luaSource = Join-Path $rimeSource "lua"
$luaTarget = Join-Path $RimeUserDir "lua"
New-Item -ItemType Directory -Force -Path $luaTarget | Out-Null
foreach ($luaFile in @(
  "mars_candidates.lua",
  "mars_methods_data.lua",
  "mars_stage2_processor.lua",
  "mars_stage2_processor_v42.lua",
  "mars_stage2_translator.lua",
  "mars_stage2_translator_v42.lua"
)) {
  $source = Join-Path $luaSource $luaFile
  if (-not (Test-Path $source)) {
    throw "Missing core Lua file: $source"
  }
  Copy-Item -Path $source -Destination $luaTarget -Force
}

# Remove files owned by the retired mild/heavy packages during upgrades.
foreach ($legacyFile in @(
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
  "lua\mars_variants.lua"
)) {
  $legacyPath = Join-Path $RimeUserDir $legacyFile
  if (Test-Path $legacyPath) {
    Remove-Item -LiteralPath $legacyPath -Force
  }
}

$skinSource = Join-Path $rimeSource "weasel.custom.yaml"
$skinTarget = Join-Path $RimeUserDir "weasel.custom.yaml"
if ((Test-Path $skinSource) -and -not (Test-Path $skinTarget)) {
  Copy-Item $skinSource $skinTarget -Force
  Write-Host "Installed Mars language skins: $skinTarget"
} elseif (Test-Path $skinTarget) {
  Write-Host "Existing skin settings preserved: $skinTarget"
}

$defaultCustom = Join-Path $RimeUserDir "default.custom.yaml"
if (Test-Path $defaultCustom) {
  Copy-Item $defaultCustom "$defaultCustom.bak.$timestamp" -Force
  $lines = @(Get-Content $defaultCustom -Encoding UTF8)
  if ($lines.Count -eq 0) {
    $lines = @("# encoding: utf-8")
  }
} else {
  $lines = @("# encoding: utf-8")
}

$lines = @($lines | Where-Object {
  $_ -notmatch '^\s*-\s*schema:\s*mars_pinyin_(mild|heavy)\s*$'
})
$lines = Add-SchemaEntry -Lines $lines -Schema "mars_pinyin"

Set-Content -Path $defaultCustom -Value $lines -Encoding UTF8

Write-Host "Mars language Rime schemas installed to: $RimeUserDir"
Write-Host "Schema added: mars_pinyin (two-stage)"
Write-Host "Please redeploy Weasel from the tray menu, then select a Mars language schema."
