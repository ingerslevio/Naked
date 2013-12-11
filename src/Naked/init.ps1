param($installPath, $toolsPath, $package)

if (Get-Module naked) {
 Remove-Module naked
}

Import-Module (Join-Path $toolsPath naked.psm1) -DisableNameChecking
Set-Settings $installPath $toolsPath $package
Copy-BuildDefinition

Run-Task VisualStudio-Init