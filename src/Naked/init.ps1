param($installPath, $toolsPath, $package)

if (Get-Module Naked) {
 Remove-Module Naked
}

Import-Module (Join-Path $toolsPath Naked.psm1) -DisableNameChecking
Set-Settings $installPath $toolsPath $package
Copy-BuildDefinition

Run-Task VisualStudio-Init