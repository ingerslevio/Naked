param($installPath, $toolsPath, $package)

if (Get-Module NuGetPsake) {
 Remove-Module NuGetPsake
}

Import-Module (Join-Path $toolsPath NuGetPsake.psm1) -DisableNameChecking
Set-Settings $installPath $toolsPath $package
Copy-BuildDefinition

Run-Task VisualStudio-Init