<#
.SYNOPSIS
  Creates LearnLite's release (upload) keystore and its key.properties
  outside the project folder.

.DESCRIPTION
  - Writes to %USERPROFILE%\.learnlite-signing (not inside OneDrive and not in
    git). Pass -Directory to choose another folder.
  - Generates a random 32-character password with the OS cryptographic RNG.
    The password is passed to keytool through environment variables, so it
    never appears on a command line or in this script's output.
  - Restricts the folder to the current Windows user.
  - Refuses to overwrite an existing keystore: losing or replacing the key
    means an installed or published app can no longer be updated.

  Gradle (android/app/build.gradle.kts) reads key.properties from
  LEARNLITE_KEY_PROPERTIES, then %USERPROFILE%\.learnlite-signing, then
  android/key.properties.

  BACK UP the whole folder (keystore + key.properties) somewhere safe and
  offline, e.g. an encrypted USB drive or a password manager attachment.

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File mobile\tool\create_release_keystore.ps1
#>
param(
    [string]$Directory = (Join-Path $env:USERPROFILE '.learnlite-signing'),
    [string]$Alias = 'learnlite-upload'
)

$ErrorActionPreference = 'Stop'

$keystore = Join-Path $Directory 'learnlite-upload.jks'
$properties = Join-Path $Directory 'key.properties'
if ((Test-Path $keystore) -or (Test-Path $properties)) {
    throw "A LearnLite keystore already exists in $Directory. It was not changed."
}

$candidates = @('C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe')
if ($env:JAVA_HOME) { $candidates = @("$env:JAVA_HOME\bin\keytool.exe") + $candidates }
$keytool = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $keytool) {
    $command = Get-Command keytool -ErrorAction SilentlyContinue
    if ($command) { $keytool = $command.Source }
}
if (-not $keytool) { throw 'keytool was not found. Install Android Studio or a JDK.' }

function New-RandomPassword([int]$length = 32) {
    $alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'.ToCharArray()
    $bytes = New-Object byte[] $length
    # Works in Windows PowerShell 5.1 and PowerShell 7.
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    -join ($bytes | ForEach-Object { $alphabet[$_ % $alphabet.Length] })
}

New-Item -ItemType Directory -Force $Directory | Out-Null
# Only the current user (and SYSTEM/Administrators for backups) can read it.
& icacls $Directory /inheritance:r /grant:r "$($env:USERNAME):(OI)(CI)F" "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" | Out-Null

$env:LL_STOREPASS = New-RandomPassword
# PKCS12 keystores use one password for the store and the key.
$env:LL_KEYPASS = $env:LL_STOREPASS
try {
    # keytool prints progress on stderr; judge success by its exit code only.
    $ErrorActionPreference = 'Continue'
    & $keytool -genkeypair -v `
        -keystore $keystore -storetype PKCS12 `
        -alias $Alias -keyalg RSA -keysize 4096 -validity 10000 `
        -dname 'CN=LearnLite, OU=LearnLite, O=LearnLite' `
        -storepass:env LL_STOREPASS -keypass:env LL_KEYPASS 2>&1 |
        Where-Object { $_ -notmatch 'pass' } | Out-Host
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $keystore)) {
        throw "keytool failed (exit $LASTEXITCODE)."
    }
    $ErrorActionPreference = 'Stop'

    $storeFile = $keystore.Replace('\', '/')
    @(
        '# LearnLite release signing. Keep private; never commit or share.'
        "storeFile=$storeFile"
        "storePassword=$($env:LL_STOREPASS)"
        "keyAlias=$Alias"
        "keyPassword=$($env:LL_KEYPASS)"
    ) | Set-Content -Path $properties -Encoding ascii
}
finally {
    Remove-Item Env:LL_STOREPASS, Env:LL_KEYPASS -ErrorAction SilentlyContinue
}

Write-Host "`nCreated:"
Write-Host "  $keystore"
Write-Host "  $properties"
Write-Host "Certificate fingerprints (add the SHA-1 and SHA-256 to Firebase):"
$env:LL_READPASS = (Get-Content $properties | Where-Object { $_ -like 'storePassword=*' }) -replace '^storePassword=', ''
try {
    $ErrorActionPreference = 'Continue'
    & $keytool -list -v -keystore $keystore -alias $Alias -storepass:env LL_READPASS 2>$null |
        Select-String -Pattern 'SHA1:|SHA256:' | ForEach-Object { "  $($_.Line.Trim())" }
}
finally {
    Remove-Item Env:LL_READPASS -ErrorAction SilentlyContinue
}
Write-Host "`nBack up the folder $Directory now. Without it, updates cannot be signed."
