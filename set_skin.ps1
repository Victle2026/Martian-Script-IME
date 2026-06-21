param(
  [Parameter(Mandatory = $true)]
  [ValidateSet(
    "mars_jirai",
    "mars_sweet_cool",
    "mars_y2k",
    "mars_pixel",
    "mars_emo_kawaii",
    "mars_millennium"
  )]
  [string]$Skin,

  [ValidateSet(
    "mars_jirai",
    "mars_sweet_cool",
    "mars_y2k",
    "mars_pixel",
    "mars_emo_kawaii",
    "mars_millennium"
  )]
  [string]$DarkSkin = $Skin,

  [ValidateSet("Vertical", "Horizontal")]
  [string]$Layout = "Vertical",

  [string]$RimeUserDir = "$env:APPDATA\Rime"
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path (Join-Path $scriptDir "rime\weasel.custom.yaml")) {
  $packageRoot = $scriptDir
} else {
  $packageRoot = Split-Path -Parent $scriptDir
}
$skinSource = Join-Path $packageRoot "rime\weasel.custom.yaml"
$skinTarget = Join-Path $RimeUserDir "weasel.custom.yaml"
if (-not (Test-Path $skinSource)) {
  throw "Cannot find skin template: $skinSource"
}

New-Item -ItemType Directory -Force -Path $RimeUserDir | Out-Null
$timestamp = Get-Date -Format "yyyyMMddHHmmss"
if (Test-Path $skinTarget) {
  Copy-Item $skinTarget "$skinTarget.bak.skin.$timestamp" -Force
}

$content = if (Test-Path $skinTarget) {
  [IO.File]::ReadAllText($skinTarget, [Text.Encoding]::UTF8)
} else {
  ""
}
if ($content -notmatch '(?m)^\s*mars_jirai:\s*$') {
  Copy-Item $skinSource $skinTarget -Force
  $content = [IO.File]::ReadAllText($skinTarget, [Text.Encoding]::UTF8)
}

$lightPattern = '(?m)^(\s*color_scheme:\s*)\S+'
$darkPattern = '(?m)^(\s*color_scheme_dark:\s*)\S+'
$layoutPattern = '(?m)^(\s*horizontal:\s*)\S+(?:\s*#.*)?$'
if (-not [regex]::IsMatch($content, $lightPattern)) {
  throw "Missing style/color_scheme in $skinTarget"
}
if (-not [regex]::IsMatch($content, $darkPattern)) {
  throw "Missing style/color_scheme_dark in $skinTarget"
}
if (-not [regex]::IsMatch($content, $layoutPattern)) {
  throw "Missing style/horizontal in $skinTarget"
}

$content = [regex]::Replace(
  $content,
  $lightPattern,
  { param($match) $match.Groups[1].Value + $Skin }
)
$content = [regex]::Replace(
  $content,
  $darkPattern,
  { param($match) $match.Groups[1].Value + $DarkSkin }
)
$horizontal = if ($Layout -eq "Horizontal") { "true" } else { "false" }
$content = [regex]::Replace(
  $content,
  $layoutPattern,
  {
    param($match)
    $comment = if ($Layout -eq "Horizontal") {
      " # horizontal candidate list"
    } else {
      " # vertical candidate list; keeps long candidates visible"
    }
    $match.Groups[1].Value + $horizontal + $comment
  }
)
[IO.File]::WriteAllText($skinTarget, $content, [Text.UTF8Encoding]::new($true))

Write-Host "Skin updated: light=$Skin, dark=$DarkSkin, layout=$Layout"
Write-Host "Right-click the Weasel tray icon and choose Redeploy."
