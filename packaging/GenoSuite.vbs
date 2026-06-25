' GenoSuite launcher
' Starts the bundled R + Shiny app with no console window and opens the
' default web browser. Double-clicked via the Start-menu / desktop shortcut.
Dim fso, shell, appDir, rscript, launcher, cmd
Set fso = CreateObject("Scripting.FileSystemObject")
appDir = fso.GetParentFolderName(WScript.ScriptFullName)
rscript = appDir & "\R\bin\Rscript.exe"
launcher = appDir & "\launcher.R"
Set shell = CreateObject("WScript.Shell")
shell.CurrentDirectory = appDir
cmd = """" & rscript & """ """ & launcher & """ """ & appDir & """"
shell.Run cmd, 0, False
