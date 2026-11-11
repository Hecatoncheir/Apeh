param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')]
    [string]$Version,

    [Parameter(Mandatory)]
    [string]$Compiler
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$bundle = (Resolve-Path -LiteralPath "$root/build/windows/x64/runner/Release").Path
$output = New-Item -ItemType Directory -Path "$root/build/dist" -Force
$vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
$visualStudio = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if ($LASTEXITCODE -ne 0 -or !$visualStudio) {
    throw 'Не найдена установка Visual Studio с инструментами C++.'
}
$runtime = Get-ChildItem -Directory "$visualStudio/VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT" |
    Sort-Object { [version]$_.Parent.Parent.Name } -Descending |
    Select-Object -First 1
if (!$runtime -or !(Test-Path -LiteralPath "$($runtime.FullName)/vcruntime140.dll")) {
    throw 'Не найдены распространяемые библиотеки Visual C++ x64.'
}
if (!(Test-Path -LiteralPath "$bundle/data/app.so")) {
    throw 'Сначала соберите Apeh в режиме release.'
}

& $Compiler "/DAppVersion=$Version" "/DBundleDir=$bundle" "/DRuntimeDir=$($runtime.FullName)" "/O$($output.FullName)" "$PSScriptRoot/apeh.iss"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
