param(
    [Parameter(Mandatory=$true)][string]$Installer,
    [Parameter(Mandatory=$true)][string]$ProductionInstaller,
    [Parameter(Mandatory=$true)][string]$Payload,
    [Parameter(Mandatory=$true)][string]$Root
)
$ErrorActionPreference = 'Stop'
$expectedRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'output\installer'))
if ([System.IO.Path]::GetFullPath($Root) -ne $expectedRoot) { throw 'Installer tests must stay within qa/output/installer.' }
$installDir = Join-Path $Root 'Install 用户 空格'
$desktopLink = Join-Path $Root 'Desktop\Cardline.lnk'
$menuLink = Join-Path $Root 'Start Menu\Cardline\Cardline.lnk'
$dataDir = Join-Path $Root 'LocalAppData\Cardline'
$results = New-Object System.Collections.Generic.List[object]
$shell = New-Object -ComObject WScript.Shell

function Check([bool]$ok, [string]$name) {
    $results.Add([pscustomobject]@{ check=$name; passed=$ok })
    if (-not $ok) { throw ('FAIL: ' + $name) }
    Write-Output ('PASS: ' + $name)
}
function Install([string[]]$options = @(), [bool]$useRegisteredDirectory = $false) {
    $arguments = @('/S') + $options
    if (-not $useRegisteredDirectory) { $arguments += '/D=' + $installDir }
    $process = Start-Process -FilePath $Installer -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    Check ($process.ExitCode -eq 0) 'Actual QA installer exits successfully'
}
function Uninstall {
    $process = Start-Process -FilePath (Join-Path $installDir 'Uninstall.exe') -ArgumentList '/S' -WindowStyle Hidden -Wait -PassThru
    Check ($process.ExitCode -eq 0) 'Actual QA uninstaller exits successfully'
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    while ((Test-Path -LiteralPath (Join-Path $installDir 'Cardline.exe')) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
    Check (-not (Test-Path -LiteralPath (Join-Path $installDir 'Cardline.exe'))) 'Uninstall removes program executable'
    $remaining = @(Get-ChildItem -LiteralPath (Join-Path $Payload 'Converters') -File -Recurse | Where-Object {
        $relative = $_.FullName.Substring($Payload.TrimEnd('\').Length + 1)
        Test-Path -LiteralPath (Join-Path $installDir $relative)
    })
    Check ($remaining.Count -eq 0) 'Uninstall removes each converter file owned by this package'
}
function VerifyShortcut([string]$path, [string]$target) {
    Check (Test-Path -LiteralPath $path) ('Shortcut exists: ' + [System.IO.Path]::GetFileName($path))
    $shortcut = $shell.CreateShortcut($path)
    Check ($shortcut.TargetPath -eq $target) 'Shortcut targets the installed executable, including Unicode and spaces'
    Check ($shortcut.WorkingDirectory -eq $installDir) 'Shortcut working directory matches the installation'
    Check ($shortcut.IconLocation -eq ($target + ',0')) 'Shortcut uses the installed Cardline icon'
}

New-Item -ItemType Directory -Force -Path (Join-Path $dataDir 'Inbox'), $installDir | Out-Null
$settingsPath = Join-Path $dataDir 'settings.json'
$imagePath = Join-Path $dataDir 'Inbox\retained.png'
Add-Type -AssemblyName System.Drawing
$image = New-Object System.Drawing.Bitmap(2, 2)
try { $image.SetPixel(0, 0, [Drawing.Color]::OrangeRed); $image.Save($imagePath, [Drawing.Imaging.ImageFormat]::Png) }
finally { $image.Dispose() }
$settings = [ordered]@{ CollectionPaused=$true; ListenClipboard=$false; AutoCheckUpdates=$false; WatchFolder=''; HotkeyKey=119; HotkeyModifiers=3; Paths=@($imagePath) }
[System.IO.File]::WriteAllText($settingsPath, (ConvertTo-Json -InputObject $settings -Compress))
$settingsHash = (Get-FileHash -LiteralPath $settingsPath).Hash
$imageHash = (Get-FileHash -LiteralPath $imagePath).Hash
$foreignFile = Join-Path $installDir 'user-file-keep.txt'
[System.IO.File]::WriteAllText($foreignFile, 'Keep files not owned by the installer.')
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$startupBefore = (Get-ItemProperty -LiteralPath $runKey -Name Cardline -ErrorAction SilentlyContinue).Cardline
$actualDesktopLink = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'Cardline.lnk'
$actualDesktopBefore = if (Test-Path -LiteralPath $actualDesktopLink) { (Get-FileHash -LiteralPath $actualDesktopLink).Hash } else { '' }
$testAppKey = 'HKCU:\Software\Cardline-InstallerTests\App'
$testRunKey = 'HKCU:\Software\Cardline-InstallerTests\Run'
Check (-not (Test-Path -LiteralPath $testAppKey)) 'Private QA uninstall registration is initially absent'
$productionBytes = [System.IO.File]::ReadAllBytes($ProductionInstaller)
$productionText = [Text.Encoding]::UTF8.GetString($productionBytes)
Check ($productionText -match 'requestedExecutionLevel[^>]+asInvoker') 'Production installer manifest requests current-user execution'
Check (-not $productionText.Contains($Root) -and -not [Text.Encoding]::Unicode.GetString($productionBytes).Contains($Root)) 'Production installer excludes QA directory redirection'

Install
foreach ($file in Get-ChildItem -LiteralPath $Payload -File -Recurse) {
    $relative = $file.FullName.Substring($Payload.TrimEnd('\').Length + 1)
    $installedPath = Join-Path $installDir $relative
    Check ((Get-FileHash -LiteralPath $installedPath).Hash -eq (Get-FileHash -LiteralPath $file.FullName).Hash) ('Installed payload matches verified portable file: ' + $relative)
}
$converterNote = Join-Path $installDir 'Converters\keep-user-note.txt'
Set-Content -LiteralPath $converterNote -Value 'Generated unrelated test note; preserve it.' -Encoding UTF8
Check (Test-Path -LiteralPath (Join-Path $installDir 'INSTALLER.zh-CN.md')) 'Installer usage and attribution guide is included'
VerifyShortcut $desktopLink (Join-Path $installDir 'Cardline.exe')
VerifyShortcut $menuLink (Join-Path $installDir 'Cardline.exe')
Check (Test-Path -LiteralPath (Join-Path $Root 'Start Menu\Cardline\卸载 Cardline.lnk')) 'Start Menu includes an uninstall entry'
$uninstallRegistration = Get-ItemProperty -LiteralPath $testAppKey
Check ($uninstallRegistration.UninstallString -eq ('"' + (Join-Path $installDir 'Uninstall.exe') + '"')) 'Uninstall registration quotes paths containing spaces and Unicode'
Check ($uninstallRegistration.QuietUninstallString -eq ($uninstallRegistration.UninstallString + ' /S')) 'Silent uninstall registration is valid'
Check ($uninstallRegistration.InstallLocation -eq $installDir) 'Uninstall registration points to the installed directory'
Check (-not (Test-Path -LiteralPath $testRunKey)) 'Installation does not enable startup'
New-Item -Path $testRunKey -Force | Out-Null
$startupValue = '"' + (Join-Path $installDir 'Cardline.exe') + '" --data-dir "' + $dataDir + '"'
New-ItemProperty -LiteralPath $testRunKey -Name Cardline -Value $startupValue -PropertyType String -Force | Out-Null
$shortcutArguments = '--data-dir "' + $dataDir + '"'
foreach ($path in @($desktopLink, $menuLink)) { $shortcut = $shell.CreateShortcut($path); $shortcut.Arguments = $shortcutArguments; $shortcut.Save() }
$desktopHash = (Get-FileHash -LiteralPath $desktopLink).Hash
$menuHash = (Get-FileHash -LiteralPath $menuLink).Hash

$previousZip = Join-Path (Split-Path $PSScriptRoot -Parent) 'Cardline-Windows-v1.3.0.zip'
Check ((Get-FileHash -LiteralPath $previousZip -Algorithm SHA256).Hash.ToLowerInvariant() -eq 'b34973a5eeefedb4fe1e4022efe9921f585c9338d1e2d69c5e075bd5ebc14a46') 'Upgrade fixture is the publicly released v1.3.0 portable package'
$previousRoot = Join-Path $Root 'Previous Portable'
Expand-Archive -LiteralPath $previousZip -DestinationPath $previousRoot -Force
$oldExecutable = Join-Path $previousRoot 'Cardline\Cardline.exe'
$oldVersion = [Reflection.AssemblyName]::GetAssemblyName($oldExecutable).Version
$newVersion = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $Payload 'Cardline.exe')).Version
Check ($oldVersion -lt $newVersion) 'Upgrade fixture has an older executable version than the new payload'
Copy-Item -LiteralPath $oldExecutable -Destination (Join-Path $installDir 'Cardline.exe') -Force
$otherDir = Join-Path $Root 'Other Portable'
$secondData = Join-Path $Root 'Second Data'
$otherData = Join-Path $Root 'Other Data'
New-Item -ItemType Directory -Force -Path $otherDir, $secondData, $otherData | Out-Null
Copy-Item -LiteralPath $oldExecutable -Destination (Join-Path $otherDir 'Cardline.exe') -Force
Copy-Item -LiteralPath (Join-Path $Payload 'Cardline.exe.config') -Destination $otherDir -Force
foreach ($directory in @($secondData, $otherData)) { Copy-Item -LiteralPath $settingsPath -Destination (Join-Path $directory 'settings.json') -Force }
$oldProcesses = @()
$otherProcess = $null
try {
    foreach ($directory in @($dataDir, $secondData)) {
        $oldProcesses += Start-Process -FilePath (Join-Path $installDir 'Cardline.exe') -ArgumentList ('--data-dir "' + $directory + '"') -WindowStyle Hidden -PassThru
        $oldProcesses[-1].WaitForInputIdle(5000) | Out-Null
        Check (-not $oldProcesses[-1].HasExited) 'Released old executable starts from the registered installation directory'
    }
    $otherProcess = Start-Process -FilePath (Join-Path $otherDir 'Cardline.exe') -ArgumentList ('--data-dir "' + $otherData + '"') -WindowStyle Hidden -PassThru
    $otherProcess.WaitForInputIdle(5000) | Out-Null
    Check (-not $otherProcess.HasExited) 'A separate portable copy is running during the upgrade'
    Install @() $true
    foreach ($process in $oldProcesses) { Check ($process.WaitForExit(5000) -and $process.ExitCode -eq 0) 'Upgrade gracefully exits a running old instance before replacing its executable' }
    Check (-not $otherProcess.HasExited) 'Upgrade leaves the running portable copy in another directory alone'
    Check ((Get-FileHash -LiteralPath (Join-Path $otherDir 'Cardline.exe')).Hash -eq (Get-FileHash -LiteralPath $oldExecutable).Hash) 'Upgrade does not overwrite another portable copy'
    Check (-not (Test-Path -LiteralPath (Join-Path $Root 'Default Install'))) 'Upgrade automatically reuses the registered custom installation directory'
    Check ((Get-FileHash -LiteralPath (Join-Path $installDir 'Cardline.exe')).Hash -eq (Get-FileHash -LiteralPath (Join-Path $Payload 'Cardline.exe')).Hash) 'Upgrade replaces the old executable with the verified new payload'
    $registration = Get-ItemProperty -LiteralPath $testAppKey
    Check ($registration.InstallLocation -eq $installDir -and $registration.DisplayVersion -eq $newVersion.ToString(3)) 'Upgrade updates one application registration at the original location'
    VerifyShortcut $desktopLink (Join-Path $installDir 'Cardline.exe')
    VerifyShortcut $menuLink (Join-Path $installDir 'Cardline.exe')
    Check ((Get-FileHash -LiteralPath $desktopLink).Hash -eq $desktopHash -and (Get-FileHash -LiteralPath $menuLink).Hash -eq $menuHash) 'In-place upgrade preserves existing shortcut files and their custom data-dir arguments'
    Check (@(Get-ChildItem -LiteralPath (Join-Path $Root 'Desktop') -Filter 'Cardline*.lnk').Count -eq 1) 'Upgrade keeps a single desktop shortcut'
    Check ((Get-ItemProperty -LiteralPath $testRunKey -Name Cardline).Cardline -eq $startupValue) 'Upgrade preserves the enabled startup command and its custom data directory'
    Check ((Get-FileHash -LiteralPath $settingsPath).Hash -eq $settingsHash -and (Get-FileHash -LiteralPath $imagePath).Hash -eq $imageHash) 'Running-instance upgrade preserves screenshots and custom settings byte for byte'
    Check (Test-Path -LiteralPath $foreignFile) 'Upgrade preserves unrelated files in the original installation directory'
} finally {
    foreach ($process in @($oldProcesses) + @($otherProcess)) {
        if ($null -ne $process) { if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit(5000) | Out-Null }; $process.Dispose() }
    }
}
Uninstall
Check (-not (Test-Path -LiteralPath $desktopLink)) 'Uninstall removes the desktop shortcut it created'
Check (-not (Test-Path -LiteralPath $menuLink)) 'Uninstall removes its Start Menu shortcuts'
Check (Test-Path -LiteralPath $foreignFile) 'Uninstall preserves unrelated files inside the installation directory'
Check (Test-Path -LiteralPath $converterNote) 'Uninstall preserves unrelated notes inside the converter directory'
Check ((Get-FileHash -LiteralPath $settingsPath).Hash -eq $settingsHash -and (Get-FileHash -LiteralPath $imagePath).Hash -eq $imageHash) 'Uninstall preserves existing screenshot data and settings'
Check (-not (Test-Path -LiteralPath $testAppKey)) 'Uninstall removes its own application registration'
Check (-not (Get-ItemProperty -LiteralPath $testRunKey -Name Cardline -ErrorAction SilentlyContinue).Cardline) 'Uninstall removes startup pointing to the installed executable'

Install @('/NODESKTOP')
Check (-not (Test-Path -LiteralPath $desktopLink)) 'Opting out does not create a desktop shortcut'
Check (Test-Path -LiteralPath $menuLink) 'Opting out retains the Start Menu entry'
Install
Check (Test-Path -LiteralPath $desktopLink) 'Reinstall can enable the desktop shortcut'
Install @('/NODESKTOP')
Check (-not (Test-Path -LiteralPath $desktopLink)) 'Reinstall can remove a previously created desktop shortcut'
Check ((Get-FileHash -LiteralPath $settingsPath).Hash -eq $settingsHash -and (Get-FileHash -LiteralPath $imagePath).Hash -eq $imageHash) 'Reinstall preserves existing screenshot data and settings'
$otherStartup = '"D:\Other Portable App\Cardline.exe" --data-dir "D:\Other Data"'
New-ItemProperty -LiteralPath $testRunKey -Name Cardline -Value $otherStartup -PropertyType String -Force | Out-Null
Uninstall
Check (Test-Path -LiteralPath $foreignFile) 'Final uninstall preserves unrelated files'
Check ((Get-ItemProperty -LiteralPath $testRunKey -Name Cardline).Cardline -eq $otherStartup) 'Uninstall preserves a startup entry pointing to another portable copy'
Remove-Item -LiteralPath 'HKCU:\Software\Cardline-InstallerTests' -Recurse -Force
$startupAfter = (Get-ItemProperty -LiteralPath $runKey -Name Cardline -ErrorAction SilentlyContinue).Cardline
Check ($startupBefore -eq $startupAfter) 'QA install and uninstall do not change the real startup setting'
$actualDesktopAfter = if (Test-Path -LiteralPath $actualDesktopLink) { (Get-FileHash -LiteralPath $actualDesktopLink).Hash } else { '' }
Check ($actualDesktopBefore -eq $actualDesktopAfter) 'QA does not create or modify the real desktop shortcut'
$report = [ordered]@{
    scope='Actual install, running v1.3.0 upgrade and uninstall with redirected shortcuts and private test registry keys.'
    previousVersion=$oldVersion.ToString(3)
    productionInstaller=[System.IO.Path]::GetFileName($ProductionInstaller)
    productionSHA256=(Get-FileHash -LiteralPath $ProductionInstaller -Algorithm SHA256).Hash.ToLowerInvariant()
    allPassed=$true
    checks=$results.ToArray()
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $Root 'installer-results.json'), (ConvertTo-Json -InputObject $report -Depth 5) + "`n", $utf8)
Write-Output ('PASS ' + $results.Count + ' installer checks')
