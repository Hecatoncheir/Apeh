param([Parameter(Mandatory)][ValidatePattern('^v\d+\.\d+\.\d+$')][string]$Tag)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$accessibility = [Reflection.Assembly]::LoadWithPartialName('Accessibility')
Add-Type -ReferencedAssemblies $accessibility.Location -Path (Resolve-Path ./installer/flutter-accessibility.cs).Path

function Wait-For([string]$Description, [scriptblock]$Check, [int]$Seconds = 40) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        try {
            $result = & $Check
            if ($result) { return $result }
        } catch [System.Windows.Automation.ElementNotAvailableException] {
            # Окно могло перестроиться после действия.
        }
        Start-Sleep -Milliseconds 500
    } while ([DateTime]::UtcNow -lt $deadline)
    Write-Host "Последние элементы Flutter: $([FlutterAccessibility]::LastNames)"
    throw "Не удалось дождаться: $Description"
}

function Find-Control($Window, [string]$Name) {
    $elements = $Window.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.Condition]::TrueCondition
    )
    foreach ($element in $elements) {
        if ($element.Current.Name -match $Name -and $element.Current.IsEnabled) {
            return $element
        }
    }
}

function Invoke-Control($Control) {
    $pattern = $null
    if (!$Control.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) {
        throw "Элемент $($Control.Current.Name) не поддерживает нажатие через UI Automation."
    }
    $pattern.Invoke()
}

function Find-AppControl($App, [string]$Name) {
    $App.Refresh()
    if ($App.HasExited) { throw "Apeh завершился ($($App.ExitCode))." }
    if ($App.MainWindowHandle -ne [IntPtr]::Zero) {
        [FlutterAccessibility]::Find($App.MainWindowHandle, $Name)
    }
}

function Find-InstallerControl(
    [string]$Name,
    [string]$Title = '(Setup.*Apeh|Установка.*Apeh)'
) {
    $windows = [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
        [System.Windows.Automation.TreeScope]::Children,
        [System.Windows.Automation.Condition]::TrueCondition
    )
    foreach ($window in $windows) {
        if ($window.Current.Name -match $Title) {
            $control = Find-Control $window $Name
            if ($control) { return $control }
        }
    }
}

function Assert-Settings {
    $settings = Get-Content -LiteralPath $preferences -Raw -Encoding UTF8 | ConvertFrom-Json
    $reminders = $settings.'flutter.rotation.reminders.v1' | ConvertFrom-Json
    if ($settings.'flutter.rotation.timeZone' -ne 'UTC' -or
        $reminders.minutes -ne 1440 -or
        ($reminders.playlists -join ',') -ne 'ranked,mixtape') {
        throw 'Настройки расписания или напоминаний изменились.'
    }
}

$version = [version]$Tag.Substring(1)
$api = 'https://api.github.com/repos/Hecatoncheir/Apeh/releases'
$releases = Invoke-RestMethod "${api}?per_page=30" -UseBasicParsing
$previous = $releases |
    Where-Object {
        !$_.draft -and !$_.prerelease -and $_.tag_name -match '^v\d+\.\d+\.\d+$' -and
        [version]$_.tag_name.Substring(1) -lt $version
    } |
    Sort-Object { [version]$_.tag_name.Substring(1) } -Descending |
    Select-Object -First 1
if (!$previous) { Write-Output 'Предыдущий выпуск отсутствует.'; return }

$asset = $previous.assets | Where-Object name -eq 'Apeh-Setup-x64.exe'
$target = Join-Path $env:RUNNER_TEMP 'ApehUpgrade'
$oldInstaller = Join-Path $env:RUNNER_TEMP 'Apeh-previous.exe'
Invoke-WebRequest $asset.browser_download_url -OutFile $oldInstaller -UseBasicParsing
if ("sha256:$((Get-FileHash -LiteralPath $oldInstaller).Hash)" -ne $asset.digest) {
    throw 'Контрольная сумма предыдущего установщика отличается.'
}
$setup = Start-Process $oldInstaller -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOICONS /LANG=english /DIR=`"$target`"" -WindowStyle Hidden -Wait -PassThru
if ($setup.ExitCode -ne 0) { throw "Установщик предыдущей версии завершился с кодом $($setup.ExitCode)." }

$preferences = Join-Path $env:APPDATA 'com.example\apeh\shared_preferences.json'
New-Item -ItemType Directory -Path (Split-Path -Parent $preferences) -Force | Out-Null
$data = @{
    'flutter.rotation.timeZone' = 'UTC'
    'flutter.rotation.reminders.v1' = '{"minutes":1440,"playlists":["ranked","mixtape"]}'
}
[IO.File]::WriteAllText($preferences, ($data | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
Write-Output "Установлен выпуск $($previous.tag_name). Подготовлены настройки."

$exe = Join-Path $target 'apeh.exe'
$old = Start-Process $exe -WorkingDirectory $target -PassThru
try {
    $null = Wait-For 'пояса UTC в предыдущем Apeh' { Find-AppControl $old 'UTC' }
    (Wait-For 'кнопки обновления' { Find-AppControl $old 'Обновления Apeh' }).Invoke()
    $null = Wait-For 'версии предыдущего Apeh в диалоге' {
        Find-AppControl $old "Установленная версия $($previous.tag_name.Substring(1))"
    }
    (Wait-For 'предложения скачать новый выпуск' {
        Find-AppControl $old 'Скачать и установить'
    } 90).Invoke()
    if (!$old.WaitForExit(90000) -or $old.ExitCode -ne 0) {
        throw 'Apeh не завершился после запуска скачанного установщика.'
    }
    Write-Output 'Apeh скачал и запустил установщик из окна обновлений.'

    Invoke-Control (Wait-For 'кнопки установки нового выпуска' {
        $language = Find-InstallerControl '^OK$' '(Select Setup Language|Выбор языка установки)'
        if ($language) { Invoke-Control $language }
        Find-InstallerControl '^&?(Install|Установить)$'
    } 60)
    Invoke-Control (Wait-For 'окончания установки' {
        Find-InstallerControl '^&?(Finish|Завершить|Готово)$'
    } 90)

    $installed = (Get-Item -LiteralPath $exe).VersionInfo
    if ([version]::new($installed.FileMajorPart, $installed.FileMinorPart, $installed.FileBuildPart) -ne $version) {
        throw 'Версия исполняемого файла после обновления отличается.'
    }
    Assert-Settings
    $new = Wait-For 'запуска обновлённого Apeh' {
        Get-Process apeh -ErrorAction SilentlyContinue |
            Where-Object Path -eq $exe |
            Select-Object -First 1
    }
    try {
        $null = Wait-For 'пояса UTC в обновлённом Apeh' { Find-AppControl $new 'UTC' }
        (Wait-For 'окна обновлений новой версии' { Find-AppControl $new 'Обновления Apeh' }).Invoke()
        $null = Wait-For 'номера новой версии в окне обновлений' {
            Find-AppControl $new "Установленная версия $($Tag.Substring(1))"
        }
        Assert-Settings
    } finally {
        if (!$new.HasExited) { Stop-Process -Id $new.Id }
    }
    Write-Output "Переход $($previous.tag_name) → $Tag подтверждён. UTC и настройки напоминаний сохранились."
} finally {
    if (!$old.HasExited) { Stop-Process -Id $old.Id }
}
