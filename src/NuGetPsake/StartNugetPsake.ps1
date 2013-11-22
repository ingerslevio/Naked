# Helper script for those who want to run psake without importing the module.
# Example:
# .\psake.ps1 "default.ps1" "BuildHelloWord" "4.0" 

# Must match parameter definitions for psake.psm1/invoke-psake 
# otherwise named parameter binding fails
param(
    [Parameter(Position=0,Mandatory=0)]
    [string[]]$taskList = @(),
    [Parameter(Position=1,Mandatory=0)]
    [string]$framework,
    [Parameter(Position=2,Mandatory=0)]
    [switch]$docs = $false,
    [Parameter(Position=3,Mandatory=0)]
    [System.Collections.Hashtable]$parameters = @{},
    [Parameter(Position=4, Mandatory=0)]
    [System.Collections.Hashtable]$properties = @{},
    [Parameter(Position=5, Mandatory=0)]
    [alias("init")]
    [scriptblock]$initialization = {},
    [Parameter(Position=6, Mandatory=0)]
    [switch]$nologo = $false,
    [Parameter(Position=7, Mandatory=0)]
    [switch]$help = $false
)

$packagePath = split-path ((Get-Variable MyInvocation -scope 0).Value.MyCommand.Path)
$rootDirectory = split-path ((Get-Variable MyInvocation -scope 1).Value.MyCommand.Path)

$global:nugetPsake = @{
    "properties" = @{
        "packagePath" = $packagePath
        "rootDirectory" = $rootDirectory
    } 
}

# '[p]sake' is the same as 'psake' but $Error is not polluted
remove-module [p]sake
import-module (join-path $packagePath psake.psm1) -DisableNameChecking
if ($help) {
  Get-Help Invoke-psake -full
  return
}

$buildScript = join-path $packagePath 'Bootstrapper.ps1'

invoke-psake $buildScript $taskList $framework $docs $parameters $properties $initialization $nologo

exit 0