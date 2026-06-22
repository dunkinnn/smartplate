Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile("C:\flutter_projects\smart_plate\assets\images\app-logo.png")
Write-Host "Width:" $img.Width "px"
Write-Host "Height:" $img.Height "px"
$img.Dispose()
