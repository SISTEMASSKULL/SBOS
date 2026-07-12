# bauth.ps1 — Descargar y ejecutar bAuth Desktop
# Ejecutar desde cualquier carpeta, cualquier número de veces.

$base = "$env:USERPROFILE"
$tar  = "$base\bauth_desktop.tar.gz"

Set-Location $base
scp skull@144.91.76.130:/tmp/bauth_desktop.tar.gz "$tar"
Remove-Item -Recurse -Force "$base\desktop" -ErrorAction SilentlyContinue
tar xzf "$tar"
Set-Location "$base\desktop"
flutter pub get
flutter run -d windows
