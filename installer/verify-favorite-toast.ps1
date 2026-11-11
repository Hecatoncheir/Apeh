param([Parameter(Mandatory)][ValidatePattern('^v\d+\.\d+\.\d+$')][string]$Tag)

$ErrorActionPreference = 'Stop'
if (!$env:GITHUB_ACTIONS -or !$env:RUNNER_TEMP) {
    throw 'Этот сценарий использует отдельный профиль Windows в GitHub Actions.'
}
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$accessibility = [Reflection.Assembly]::LoadWithPartialName('Accessibility')
Add-Type -ReferencedAssemblies $accessibility.Location -Path (Resolve-Path ./installer/flutter-accessibility.cs).Path
$toastManager = [Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime]
$appId = 'Apeh.MapRotation'
$inboxProbe = (Resolve-Path ./installer/find-delivered-toast.py).Path

function Wait-For([string]$description, [scriptblock]$check, [int]$seconds) {
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($seconds)
    do {
        $result = & $check
        if ($result) { return $result }
        Start-Sleep -Milliseconds 350
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    throw "Не удалось дождаться: $description."
}

function Find-WindowsToast([string]$text) {
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    $name = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::NameProperty, $text)
    $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $name)
}

function Find-DeliveredToast([string]$id, [string]$text) {
    foreach ($toast in $toastManager::History.GetHistory($appId)) {
        if ($toast.Tag -eq $id -and $toast.Content.GetXml().Contains($text)) {
            return $toast
        }
    }
}

$headers = @{ Accept = 'application/vnd.github+json' }
if ($env:GH_TOKEN) { $headers.Authorization = "Bearer $env:GH_TOKEN" }
$api = "https://api.github.com/repos/Hecatoncheir/Apeh/releases/tags/$Tag"
$release = Invoke-RestMethod $api -Headers $headers -UseBasicParsing
$asset = $release.assets | Where-Object name -eq 'Apeh-Setup-x64.exe'
$setupPath = Join-Path $env:RUNNER_TEMP 'Apeh-toast-setup.exe'
$target = Join-Path $env:RUNNER_TEMP 'ApehToast'
Invoke-WebRequest $asset.browser_download_url -OutFile $setupPath -UseBasicParsing
if ("sha256:$((Get-FileHash -LiteralPath $setupPath).Hash)" -ne $asset.digest) {
    throw 'Контрольная сумма установщика не совпала.'
}
$arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/NOICONS', ('/DIR="{0}"' -f $target))
$setup = Start-Process $setupPath -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
if ($setup.ExitCode -ne 0) { throw "Установщик завершился с кодом $($setup.ExitCode)." }

$exe = Join-Path $target 'apeh.exe'
$info = (Get-Item -LiteralPath $exe).VersionInfo
$installed = [version]::new($info.FileMajorPart, $info.FileMinorPart, $info.FileBuildPart)
if ($installed -ne [version]$Tag.Substring(1)) { throw "Установлена версия $installed." }

# Не даём реальному расписанию заменить тестовую смену. Правило действует
# только для установленного экземпляра Apeh на тестовой машине.
$rule = 'Apeh test ' + [guid]::NewGuid().ToString('N')
New-NetFirewallRule -Name $rule -DisplayName $rule -Program $exe -Direction Outbound -Action Block | Out-Null
$app = $null
try {
    $now = [DateTimeOffset]::UtcNow
    $change = $now.AddSeconds(36).ToUnixTimeSeconds()
    $marker = 'CI-' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    $rotation = @{
        current = @{ map = 'Storm Point'; start = $now.AddMinutes(-5).ToUnixTimeSeconds(); end = $change }
        next = @{ map = 'Olympus'; start = $change; end = $change + 3600; eventName = $marker }
    }
    $snapshot = @{
        updatedAt = $now.UtcDateTime.ToString('o')
        rotation = @{ ranked = $rotation; wildcard = $rotation }
    }
    $settings = @{
        'flutter.appearance.language' = 'english'
        'flutter.window.closeToTray' = $true
        'flutter.rotation.reminders.v1' = '{"minutes":0,"playlists":[],"favorites":[{"map":"Olympus","playlists":["ranked"]}]}'
        'flutter.rotation.snapshot.v1' = $snapshot | ConvertTo-Json -Compress -Depth 7
    }
    $profile = Join-Path $env:APPDATA 'com.example\apeh'
    New-Item -ItemType Directory -Path $profile -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $profile 'shared_preferences.json'),
        ($settings | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
    $expectedId = [string](0x10000000 + (($change -band 0x0fffffff) -shl 2))
    $otherId = [string]([long]$expectedId + 3)
    $message = "The map is changing to Olympus · $marker."

    $app = Start-Process $exe -WorkingDirectory $target -PassThru
    $window = Wait-For 'окна Apeh' {
        $app.Refresh()
        if ($app.HasExited) { throw "Apeh завершился ($($app.ExitCode))." }
        if ($app.MainWindowHandle -ne [IntPtr]::Zero) { $app.MainWindowHandle }
    } 12
    $null = Wait-For 'напоминания Ranked в очереди Windows' {
        $notifier = $toastManager::CreateToastNotifier($appId)
        $scheduled = @($notifier.GetScheduledToastNotifications())
        if ($scheduled.Tag -contains $otherId) { throw 'Запланировано лишнее уведомление Wildcard.' }
        $scheduled | Where-Object { $_.Tag -eq $expectedId -and $_.Content.GetXml().Contains($message) }
    } 14
    Write-Output "$($Tag): Windows запланировала напоминание об Olympus только для Ranked."

    if (![ApehTrayCheck]::Minimize($window)) { throw 'Не удалось свернуть Apeh.' }
    $null = Wait-For 'значка Apeh в трее' {
        ![ApehTrayCheck]::IsWindowVisible($window) -and [ApehTrayCheck]::HasIcon($window)
    } 5
    if ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -ge $change) {
        throw 'Окно свернулось слишком поздно для проверки.'
    }
    Write-Output 'Окно скрыто, значок Apeh зарегистрирован в трее Windows.'

    $beforeDelivery = [DateTimeOffset]::UtcNow
    $remaining = [Math]::Max(0, $change - $beforeDelivery.ToUnixTimeSeconds())
    $delivered = Wait-For 'доставленного Windows уведомления' {
        if ($app.HasExited -or [ApehTrayCheck]::IsWindowVisible($window)) {
            throw 'Apeh перестал работать в трее до доставки.'
        }
        if ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -lt $change) { return }
        if (& python $inboxProbe $expectedId $message) { return 'хранилище доставленных уведомлений Windows' }
        if (Find-DeliveredToast $expectedId $message) { return 'история уведомлений Windows' }
        if (Find-WindowsToast $message) { return 'баннер Windows' }
    } ($remaining + 75)
    Write-Output "Уведомление «$message» доставлено, пока Apeh оставался в трее. Подтверждение: $delivered."
} catch {
    $notifier = $toastManager::CreateToastNotifier($appId)
    Write-Output "Уведомления в очереди после ошибки: $(@($notifier.GetScheduledToastNotifications()).Tag -join ', ')."
    Write-Output "Состояние уведомлений Windows: $($notifier.Setting)."
    Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version | Format-Table | Out-String | Write-Output
    Get-Service 'WpnService','WpnUserService*' | Select-Object Name, Status | Format-Table | Out-String | Write-Output
    Get-WinEvent -ListLog '*PushNotifications*','*TWinUI*' -ErrorAction SilentlyContinue |
        Select-Object LogName, IsEnabled, RecordCount | Format-Table | Out-String | Write-Output
    throw
} finally {
    if ($app -and !$app.HasExited) { Stop-Process -Id $app.Id }
    Remove-NetFirewallRule -Name $rule
}
