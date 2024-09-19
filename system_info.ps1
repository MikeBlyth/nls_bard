Write-Host "System Information:"
Write-Host "-------------------"
Write-Host "OS Version:" (Get-WmiObject -class Win32_OperatingSystem).Version
Write-Host "OS Architecture:" (Get-WmiObject Win32_OperatingSystem).OSArchitecture
Write-Host ".NET Framework Version:" (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue).Version
Write-Host "PowerShell Version:" $PSVersionTable.PSVersion

Write-Host "`nEnvironment Variables:"
Write-Host "----------------------"
Get-ChildItem Env: | Format-Table -AutoSize

Write-Host "`nChrome Installations:"
Write-Host "---------------------"
Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty '(Default)'