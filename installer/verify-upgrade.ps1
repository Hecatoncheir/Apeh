param([Parameter(Mandatory)][ValidatePattern('^v\d+\.\d+\.\d+$')][string]$Tag)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Security
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

function Find-AppControl($App, [string]$Name, [switch]$MatchSuffix) {
    $App.Refresh()
    if ($App.HasExited) { throw "Apeh завершился ($($App.ExitCode))." }
    if ($App.MainWindowHandle -ne [IntPtr]::Zero) {
        [FlutterAccessibility]::Find($App.MainWindowHandle, $Name, $MatchSuffix.IsPresent)
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

function Assert-ApiKey {
    $plaintext = [Security.Cryptography.ProtectedData]::Unprotect(
        [IO.File]::ReadAllBytes($secureStorage), $null, $dpapiScope
    )
    $values = [Text.Encoding]::UTF8.GetString($plaintext) | ConvertFrom-Json
    if ($values.'rotation.alsKey' -cne $testKey) {
        throw 'Тестовый API-ключ не сохранился в защищённом хранилище.'
    }
}

function Assert-AppReadsApiKey($App) {
    Assert-ApiKey
    # Синтетический ключ не авторизует запрос. Это сообщение появляется
    # после попытки использовать ключ, прочитанный при запуске.
    $null = Wait-For 'попытки запроса со сохранённым ключом' {
        Find-AppControl $App 'Используется публичное расписание.' -MatchSuffix
    }
}

function Assert-AppReadsReminders($App) {
    (Wait-For 'кнопки напоминаний' {
        Find-AppControl $App 'Напоминания о смене карт'
    }).Invoke()
    $null = Wait-For 'интервала напоминаний в диалоге' {
        [FlutterAccessibility]::FindValue($App.MainWindowHandle, '1440')
    }
    $expected = @{ Ranked = $true; 'Обычный BR' = $false; Mixtape = $true; Wildcard = $false }
    foreach ($mode in $expected.Keys) {
        $checkbox = Wait-For "флажка режима $mode" {
            # ROLE_SYSTEM_CHECKBUTTON
            [FlutterAccessibility]::Find($App.MainWindowHandle, $mode, $false, 0x2c)
        }
        if ($checkbox.IsChecked -ne $expected[$mode]) {
            throw "Состояние напоминаний для режима $mode отличается от сохранённого."
        }
    }
    (Wait-For 'закрытия настроек напоминаний' { Find-AppControl $App 'Отмена' }).Invoke()
}

$version = [version]$Tag.Substring(1)
$api = 'https://api.github.com/repos/Hecatoncheir/Apeh/releases'
$headers = @{ Accept = 'application/vnd.github+json' }
if ($env:GH_TOKEN) { $headers.Authorization = "Bearer $env:GH_TOKEN" }
$releases = Invoke-RestMethod "${api}?per_page=30" -UseBasicParsing -Headers $headers
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
$secureStorage = Join-Path (Split-Path -Parent $preferences) 'flutter_secure_storage.dat'
$testKey = 'apeh-ci-' + [Guid]::NewGuid().ToString('N')
$dpapiScope = [Security.Cryptography.DataProtectionScope]::CurrentUser
$keyJson = @{ 'rotation.alsKey' = $testKey } | ConvertTo-Json -Compress
$encrypted = [Security.Cryptography.ProtectedData]::Protect(
    [Text.Encoding]::UTF8.GetBytes($keyJson), $null, $dpapiScope
)
[IO.File]::WriteAllBytes($secureStorage, $encrypted)
Write-Output "Установлен выпуск $($previous.tag_name). Подготовлены настройки."

$exe = Join-Path $target 'apeh.exe'
$old = Start-Process $exe -WorkingDirectory $target -PassThru
try {
    $null = Wait-For 'пояса UTC в предыдущем Apeh' { Find-AppControl $old 'UTC' }
    Assert-AppReadsApiKey $old
    Assert-AppReadsReminders $old
    Write-Output 'Предыдущая версия прочитала тестовый API-ключ, UTC и настройки напоминаний.'
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
    Assert-ApiKey
    $new = Wait-For 'запуска обновлённого Apeh' {
        Get-Process apeh -ErrorAction SilentlyContinue |
            Where-Object Path -eq $exe |
            Select-Object -First 1
    }
    try {
        $null = Wait-For 'пояса UTC в обновлённом Apeh' { Find-AppControl $new 'UTC' }
        Assert-AppReadsApiKey $new
        Assert-AppReadsReminders $new
        (Wait-For 'окна обновлений новой версии' { Find-AppControl $new 'Обновления Apeh' }).Invoke()
        $null = Wait-For 'номера новой версии в окне обновлений' {
            Find-AppControl $new "Установленная версия $($Tag.Substring(1))"
        }
        Assert-Settings
        Write-Output 'Новая версия прочитала тот же API-ключ без повторного ввода.'
    } finally {
        if (!$new.HasExited) { Stop-Process -Id $new.Id }
    }
    Write-Output "Переход $($previous.tag_name) → $Tag подтверждён. UTC, настройки напоминаний и API-ключ сохранились."
} finally {
    if (!$old.HasExited) { Stop-Process -Id $old.Id }
}
