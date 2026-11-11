[Setup]
AppId={{02F6FD8C-9D44-4EBD-A42B-0B310D906B25}
AppName=Apeh
AppVersion={#AppVersion}
AppPublisher=Hecatoncheir
AppPublisherURL=https://github.com/Hecatoncheir/Apeh
DefaultDirName={localappdata}\Programs\Apeh
DefaultGroupName=Apeh
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
CloseApplications=yes
RestartApplications=no
UninstallDisplayIcon={app}\apeh.exe
SetupIconFile=..\windows\runner\resources\app_icon.ico
OutputBaseFilename=Apeh-Setup-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#RuntimeDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Apeh"; Filename: "{app}\apeh.exe"

[Run]
Filename: "{app}\apeh.exe"; Description: "{cm:LaunchProgram,Apeh}"; Flags: nowait postinstall skipifsilent
