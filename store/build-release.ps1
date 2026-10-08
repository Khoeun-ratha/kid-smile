<#
  Builds the signed Google Play bundle for Kid Smile.

    .\store\build-release.ps1          # build the current version
    .\store\build-release.ps1 -Bump    # 1.0.0+1 -> 1.0.1+2, then build

  Needs mobile\android\key.properties (see store\keystore-info.txt).
  The finished bundle is copied to the Desktop as kid-smile-<version>.aab.
#>
param([switch]$Bump)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$mobile = Join-Path $repo 'mobile'
$pubspec = Join-Path $mobile 'pubspec.yaml'

if (-not (Test-Path (Join-Path $mobile 'android\key.properties'))) {
    throw "mobile\android\key.properties is missing - without it the bundle would be signed with the debug key, which Google Play rejects. See store\keystore-info.txt."
}

$text = [IO.File]::ReadAllText($pubspec)
$match = [regex]::Match($text, '(?m)^version:[ \t]*(\d+)\.(\d+)\.(\d+)\+(\d+)[ \t]*(?=\r?$)')
if (-not $match.Success) { throw "Couldn't read 'version: x.y.z+n' from pubspec.yaml" }
$major = [int]$match.Groups[1].Value
$minor = [int]$match.Groups[2].Value
$patch = [int]$match.Groups[3].Value
$code = [int]$match.Groups[4].Value

if ($Bump) {
    $patch++
    $code++
    $text = $text.Substring(0, $match.Index) + "version: $major.$minor.$patch+$code" + $text.Substring($match.Index + $match.Length)
    [IO.File]::WriteAllText($pubspec, $text)
    Write-Host "Version raised to $major.$minor.$patch+$code - commit pubspec.yaml after uploading."
}
$version = "$major.$minor.$patch"

Push-Location $mobile
try {
    flutter build appbundle --release
    if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }
} finally {
    Pop-Location
}

$aab = Join-Path $mobile 'build\app\outputs\bundle\release\app-release.aab'
$owner = (keytool -printcert -jarfile $aab | Select-String -Pattern 'Owner:' | Select-Object -First 1).ToString().Trim()
if ($owner -notmatch 'CN=Kid Smile') { throw "Bundle is not signed with the Kid Smile upload key ($owner)" }

$out = Join-Path ([Environment]::GetFolderPath('Desktop')) "kid-smile-$version-build$code.aab"
Copy-Item $aab $out -Force
Write-Host ""
Write-Host "Built Kid Smile $version (version code $code), signed by $owner"
Write-Host "Upload this file to Google Play: $out"
