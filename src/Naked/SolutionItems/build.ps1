# Updated by naked. Do not change.
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
$rootDirectory = (split-path $script:MyInvocation.MyCommand.Path)
& "$rootDirectory\.nuget\NuGet.exe" install "$rootDirectory\.nuget\packages.config" -OutputDirectory .\packages
$startPath = (Get-ChildItem (join-path $rootDirectory packages\naked*\tools\StartNaked.ps1) | Sort LastWriteTime -Descending | Select-Object -First 1).FullName
& $startPath @psBoundParameters