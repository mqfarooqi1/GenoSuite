; Inno Setup script for GenoSuite — builds a self-contained Windows installer.
; Compile from the packaging/ directory:  ISCC.exe GenoSuite.iss

#define MyAppName "GenoSuite"
#define MyAppVersion "0.1.1"
#define MyAppPublisher "Muhammad Farooqi"
#define MyAppURL "https://mqfarooqi1.github.io/GenoSuite/"
#define DistDir "..\dist\GenoSuite"

[Setup]
AppId={{8E6C3F2A-1B7D-4E9C-9A21-7F3D0C2B5A10}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={localappdata}\Programs\GenoSuite
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=GenoSuite-Setup
SetupIconFile={#DistDir}\GenoSuite.ico
UninstallDisplayIcon={app}\GenoSuite.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
LicenseFile=..\LICENSE
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "{#DistDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\GenoSuite"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\GenoSuite.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\GenoSuite.ico"
Name: "{group}\Uninstall GenoSuite"; Filename: "{uninstallexe}"
Name: "{autodesktop}\GenoSuite"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\GenoSuite.vbs"""; WorkingDir: "{app}"; IconFilename: "{app}\GenoSuite.ico"; Tasks: desktopicon

[Run]
Filename: "{sys}\wscript.exe"; Parameters: """{app}\GenoSuite.vbs"""; Description: "Launch GenoSuite now"; Flags: nowait postinstall skipifsilent
