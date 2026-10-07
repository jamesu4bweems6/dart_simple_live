#ifndef AppVersion
  #error AppVersion must be supplied with /DAppVersion
#endif
#ifndef SourceDir
  #error SourceDir must be supplied with /DSourceDir
#endif
#ifndef OutputDir
  #error OutputDir must be supplied with /DOutputDir
#endif

[Setup]
AppId={{45F6FA98-DA23-4795-8685-60F607317A1F}
AppName=Slive
AppVersion={#AppVersion}
AppPublisher=SlotSun
DefaultDirName={autopf}\Slive
DefaultGroupName=Slive
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=Slive-{#AppVersion}-Windows-x64-setup
SetupIconFile=..\..\..\assets\icons\app_icon.ico
UninstallDisplayIcon={app}\slive.exe
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "zh"; MessagesFile: "ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Slive"; Filename: "{app}\slive.exe"
Name: "{autodesktop}\Slive"; Filename: "{app}\slive.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\slive.exe"; Description: "{cm:LaunchProgram,Slive}"; Flags: nowait postinstall skipifsilent
