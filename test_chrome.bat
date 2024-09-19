@echo off
echo Running Chrome with debug flags...
"C:\ChromeForTesting\chrome.exe" --version
"C:\ChromeForTesting\chrome.exe" --no-sandbox --disable-gpu --verbose --log-level=0 https://www.example.com
echo Chrome process completed.
pause