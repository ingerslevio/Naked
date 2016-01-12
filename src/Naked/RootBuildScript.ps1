$naked.properties.nakedPath = (split-path $script:MyInvocation.MyCommand.Path)
$naked.properties.packagesPath = resolve-path (join-path $naked.properties.nakedPath ..\..\)
$naked.properties.solutionFile = (Get-ChildItem $naked.properties.rootDirectory -Filter '*.sln' -Recurse | Select-Object -First 1).FullName
$naked.properties.solutionDir = split-path $naked.properties.solutionFile
$naked.properties.buildConfigurationPath = join-path $naked.properties.solutionDir buildConfiguration.json

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

$naked.procedures = @{}

function Add-nakedProcedure($procedure, $name, $scriptBlock) {
  if(-not $naked.procedures.$procedure) {
    $naked.procedures.$procedure = @()
  }
  $naked.procedures.$procedure += @{
    ScriptBlock = $scriptBlock
    Name = $name
  }  
}

function Invoke-nakedProcedure($procedure) {
  $possibleProcedures = $naked.procedures.$procedure
  write-output $procedure $possibleProcedures

  foreach($possibleProcedure in $possibleProcedures) {
    try {
      $result = [PSCustomObject] (. $possibleProcedure.ScriptBlock)
    } catch {
      $result = [PSCustomObject] @{
        Success = $false
        Error = $Error[0]
      }
    }
    if(-not (Get-Member -InputObject $result -Name 'Success')) { 
        [void] (Add-Member -InputObject $result -MemberType NoteProperty -Name 'Success' -Value $true)
    }
    if($result.success -eq $true) {
        return $result
    }
  }
  return [PSCustomObject] @{
    Success = $false
    Error = "No procedures succeded"
  }
}

if(-not (Get-Command "ConvertFrom-Json" -ErrorAction SilentlyContinue)) {
  throw "Powershell 3.0+ is required. Please install Windows Management Framework 3.0 (http://www.microsoft.com/en-us/download/details.aspx?id=34595)"
} else {
  $naked.buildConfiguration = ConvertTo-HashTable (ConvertFrom-Json (Get-Content $naked.properties.buildConfigurationPath | Out-String))
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

$naked.packages = @{}

Include "$($naked.properties.nakedPath)\DefaultTasks.ps1"
foreach($packageName in $naked.buildConfiguration.packages) {
  $packageSearchPath = join-path $naked.properties.packagesPath "$packageName*\tools\NakedModule.ps1"
  $nakedModuleItem = (Get-ChildItem $packageSearchPath | Sort LastWriteTime -Descending | Select-Object -First 1)
  if(-not $nakedModuleItem) {
    $nakedModuleItem = Get-Item (join-path $naked.properties.solutionDir "$packageName\NakedModule.ps1")
  }
  if(-not $nakedModuleItem) {
    throw "Could not load package '$packageName'. It does not seem to exist."
  }

  $naked.packages[$packageName -replace "Naked\.", ""] = @{
    Name = $packageName
    ToolsPath = $nakedModuleItem.Directory.FullName
  }

  Write-Host "Loading Package $($packageName)" -fore green
  Include $nakedModuleItem.FullName
 
  if(-not $nakedModuleItem)  # I think this should be removed since its not used.
  {
    $cmdName = "Init-$packageName"
    if (Get-Command $cmdName -errorAction SilentlyContinue)
    {
        "$cmdName exists"
    }
  }
}

Add-nakedProcedure -Procedure "DetectBuildServer" -Name "TeamCity" -ScriptBlock {
    if($env:TEAMCITY_VERSION) {
      Import-Module (join-path $naked.properties.nakedPath 'teamcity.psm1') -DisableNameChecking
      
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
      $naked.properties.teamcity = $teamcity
      return @{ Success = $true }
    } else {
      return @{ Success = $false }
    }
}

$result = Invoke-nakedProcedure "DetectBuildServer"

$naked.properties.isRunningOnBuildServer = $result.Success
if($naked.properties.isRunningOnBuildServer) {
    Write-Output "Build Script is running on build server"    
} else {
    Write-Output "Build Script is NOT running on build server"
}