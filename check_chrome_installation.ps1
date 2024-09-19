$chromePath = "C:\ChromeForTesting\chrome.exe"
   $chromeDriverPath = "C:\ChromeForTesting\chromedriver.exe"

   function Check-File($path) {
       if (Test-Path $path) {
           $fileInfo = Get-Item $path
           Write-Host "File exists: $path"
           Write-Host "File size: $($fileInfo.Length) bytes"
           Write-Host "Last modified: $($fileInfo.LastWriteTime)"
           Write-Host "File version: $((Get-Item $path).VersionInfo.FileVersion)"
       } else {
           Write-Host "File does not exist: $path"
       }
   }

   Write-Host "Checking Chrome for Testing installation:"
   Check-File $chromePath
   Write-Host ""
   Write-Host "Checking ChromeDriver installation:"
   Check-File $chromeDriverPath