if($env:TEAMCITY_VERSION) {
  Write-Output "Build Script is running on build server"
  $isRunningOnBuildServer = $true

  # load properties from teamcity properties file
  $teamcityConfigFileContent = [IO.File]::ReadAllText($env:TEAMCITY_BUILD_PROPERTIES_FILE)
  $teamcity = @{}
  foreach($line in $teamcityConfigFileContent.split("`n")) {
    if(-not ($line -like '#*')) {
      $value = $line.split('=')[1]
      if($value) {
        $value = $value.replace("\\","\").replace("\:",":").replace("`r","")
      }
      $teamcity.Add($line.split('=')[0],$value)
    } 
  }

} else {
  #Write-Output "Build Script is NOT running on build server"
  $isRunningOnBuildServer = $false
}

$nugetPsake.properties.nugetPsakePath = (split-path $script:MyInvocation.MyCommand.Path)
$nugetPsake.properties.packagesPath = resolve-path (join-path $nugetPsake.properties.nugetPsakePath ..\..\)
$nugetPsake.properties.solutionFile = (Get-ChildItem $nugetPsake.properties.rootDirectory -Filter '*.sln' -Recurse | Select-Object -First 1).FullName
$nugetPsake.properties.solutionDir = split-path $nugetPsake.properties.solutionFile
$nugetPsake.properties.buildConfigurationPath = join-path $nugetPsake.properties.solutionDir buildConfiguration.json

Import-Module (join-path $nugetPsake.properties.nugetPsakePath 'teamcity.psm1') -DisableNameChecking



function ConvertTo-HashTable($psobject) {
  $hashtable = @{}
  foreach($property in $psobject.psobject.properties) {
    if($property.Value -and ($property.Value.GetType().Name -eq 'PSCustomObject')) {
      $hashtable[$property.Name] = ConvertTo-HashTable $property.Value
    } else {
      $hashtable[$property.Name] = $property.Value
    }
  }
  return $hashtable
}

function Get-Task([string] $taskName) {
    return $psake.context.Peek().tasks[$taskName]
}

function Add-Dependency([string] $taskName, [string[]] $dependencies) {
    if(-not (Get-Task $taskName)) {
      throw "Could not add dependency to task. Unknown taskName: '$taskName'"
    }
    foreach($dependency in $dependencies) {
      if(-not (Get-Task $dependency)) {
        throw "Could not add dependency to task: '$taskName'. Unknown dependency: '$dependency'"
      }
      (Get-Task $taskName).dependson += $dependency
    }
}

$nugetPsake.procedures = @{}

function Add-NuGetPsakeProcedure($procedure, $name, $scriptBlock) {
  if(-not $nugetPsake.procedures.$procedure) {
    $nugetPsake.procedures.$procedure = @()
  }
  $nugetPsake.procedures.$procedure + @{
    ScriptBlock = $scriptBlock
    Name = $name
  }  
}

function Invoke-NuGetPsakeProcedure($procedure) {
  $possibleProcedures = $nugetPsake.procedures.$procedure
  foreach($possibleProcedure in $possibleProcedures) {
    try {
      $result = . $possibleProcedure.ScriptBlock)
    } catch {
      $result = @{
        Success = $false
        Error = $Error[0]
      }
    }
    $result.Name = $possibleProcedure.Name
    if($success) {
      return $true
    }
  }
}




if(-not (Get-Command "ConvertFrom-Json" -ErrorAction SilentlyContinue)) {
  throw "Powershell 3.0+ is required. Please install Windows Management Framework 3.0 (http://www.microsoft.com/en-us/download/details.aspx?id=34595)"
} else {
  $nugetPsake.buildConfiguration = ConvertTo-HashTable (ConvertFrom-Json (Get-Content $nugetPsake.properties.buildConfigurationPath | Out-String))
}

## Parent Level Shared BuildConfiguration.json
$solutionDirItem = (Get-ChildItem $buildConfigurationPath).Directory
$currentDirectory = $solutionDirItem.parent
while($currentDirectory.parent -and (-not $sharedBuildConfigurationPath)) { 
  if(Test-Path (join-path $currentDirectory.FullName "BuildConfiguration.json")) {
    $sharedBuildConfigurationPath = join-path $currentDirectory.FullName "BuildConfiguration.json"
  }
  $currentDirectory = $currentDirectory.parent
}

if($buildConfiguration.framework) {
  Framework $buildConfiguration.framework
} else {
  Framework "4.0x64"
}

$nugetPsake.packages = @{}

Include "$($nugetPsake.properties.nugetPsakePath)\DefaultTasks.ps1"
foreach($packageName in $nugetPsake.buildConfiguration.packages) {
  $packageSearchPath = join-path $nugetPsake.properties.packagesPath "$packageName*\tools\NuGetPsakeModule.ps1"
  $nuGetPsakeModuleItem = (Get-ChildItem $packageSearchPath | Sort LastWriteTime -Descending | Select-Object -First 1)
  if(-not $nuGetPsakeModuleItem) {
    $nuGetPsakeModuleItem = Get-Item (join-path $nugetPsake.properties.solutionDir "$packageName\NuGetPsakeModule.ps1")
  }
  if(-not $nuGetPsakeModuleItem) {
    throw "Could not load package '$packageName'. It does not seem to exist."
  }

  $nugetPsake.packages[$packageName -replace "nugetpsake\.", ""] = @{
    Name = $packageName
    ToolsPath = $nuGetPsakeModuleItem.Directory.FullName
  }

  Write-Host "Loading Package $($packageName)" -fore green
  Include $nuGetPsakeModuleItem.FullName
 
  if(-not $nuGetPsakeModuleItem)  # I think this should be removed since its not used.
  {
    $cmdName = "Init-$packageName"
    if (Get-Command $cmdName -errorAction SilentlyContinue)
    {
        "$cmdName exists"
    }
  }
}