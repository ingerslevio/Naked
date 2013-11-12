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

$nugetPsakePath = (split-path $script:MyInvocation.MyCommand.Path)

function Find-FileMovingUp($fileName) {
  $folderItem = Get-Item $nugetPsakePath
  while(-not ($folderItem.GetFiles() | where {$_.Name -like $fileName})) {
    if(-not $folderItem.Parent) {
        throw "Could not find '$fileName' directory by moving upwards from '$nugetPsakePath'"
    }
    $folderItem = $folderItem.Parent
  }
  return ($folderItem.GetFiles() | where {$_.Name -like $fileName}).FullName
}

Import-Module (join-path $nugetPsakePath 'teamcity.psm1') -DisableNameChecking

$solutionFile = Find-FileMovingUp '*.sln'
$solutionDir = split-path $solutionFile
$buildScript = join-path $solutionDir NuGetPsakeModule.ps1
$hasBuildScript = Test-Path $buildScript

$packagesPath = resolve-path (join-path $nugetPsakePath ..\..\)

$nuget = join-path $solutionDir '.nuget/NuGet.exe'
$nugetPackageDir = join-path $solutionDir 'nugetpackages'

$hasFailedTests = $false

$packages = @{}

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

$buildConfigurationPath = join-path $solutionDir buildConfiguration.json

if(-not (Get-Command "ConvertFrom-Json" -ErrorAction SilentlyContinue)) {
  throw "Powershell 3.0+ is required. Please install Windows Management Framework 3.0 (http://www.microsoft.com/en-us/download/details.aspx?id=34595)"
} else {
  $global:buildConfiguration = ConvertTo-HashTable (ConvertFrom-Json (Get-Content $buildConfigurationPath | Out-String))
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

function Load-Package([string] $packageName) {
    $nuGetPsakeModuleItem = (Get-ChildItem (join-path $packagesPath \$($packageName)*\tools\NuGetPsakeModule.ps1) | Sort LastWriteTime -Descending | Select-Object -First 1)
    if(-not $nuGetPsakeModuleItem) {
      $nuGetPsakeModuleItem = Get-Item (join-path $solutionDir \$($packageName)\NuGetPsakeModule.ps1)
    }
    if(-not $nuGetPsakeModuleItem) {
      throw "Could not load package '$packageName'. It does not seem to exist."
    }

    $packages[$packageName -replace "nugetpsake\.", ""] = @{
      Name = $packageName
      ToolsPath = $nuGetPsakeModuleItem.Directory.FullName
    }

    Write-Host "Loading Package $($packageName)" -fore green
    [void] (. $nuGetPsakeModuleItem.FullName)


    # I think this should be removed since its not used.
    $cmdName = "Init-$packageName"
    if (Get-Command $cmdName -errorAction SilentlyContinue)
    {
        "$cmdName exists"
    }
}

function Get-Task([string] $taskName) {
    return $psake.context.Peek().tasks[$taskName]
}

# function Remove-Task([string] taskName) {
#   Remove-ItemProperty $psake.context.Peek().tasks 
# }

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

function Create-NuGetPackage([string] $nuspecFile)
{
  $nuspecFilePath = join-path $solutionDir $nuspecFile
  $basePath = Split-Path $nuspecFilePath
  if (!(Test-Path $nugetPackageDir )) {
    mkdir $nugetPackageDir
  }
  
  exec { &$nuget pack $nuspecFilePath -BasePath $basePath -OutputDirectory $nugetPackageDir -Version $version -NoPackageAnalysis }
  
  $baseFileName = (Get-ChildItem $nuspecFilePath).BaseName
  $nugetPackageFileName = (Get-ChildItem $nugetPackageDir | Where-Object {$_.Name -match "$baseFileName[\d\.\-a-zA-Z]+\.nupkg"}).BaseName
  $nugetPackageFile = "$nugetPackageDir\$nugetPackageFileName.nupkg"  
  TeamCity-PublishArtifact $nugetPackageFile
}

function Generate-VersionNumber {
  $majorAndMinorVersion = $buildConfiguration.majorAndMinorVersion
  if(-not $majorAndMinorVersion) {
    throw '$majorAndMinorVersion not set. Insert "majorAndMinorVersion": "1.0" in BuildConfiguration.json'
  }

  if($isRunningOnBuildServer) {
    $vcsNumber = $env:BUILD_VCS_NUMBER
    $script:buildTag = $env:BUILD_TAG
    
    # calculate build number unless its already been calculated by another build script run.
    if(-not ($env:BUILD_NUMBER -like '*.*.*.*')) {
      $script:cleanVersion = "$($majorAndMinorVersion).$($vcsNumber).$($env:BUILD_NUMBER)"
      $script:version = $script:cleanVersion
      if($script:buildTag)
      {
        $script:version += '-' + $script:buildTag
      }
    }
    else {
      $script:version = $env:BUILD_NUMBER
    }
    Teamcity-SetBuildNumber $script:version
  } else {
    $script:buildTag = "local"
    $script:cleanVersion = "$($majorAndMinorVersion).0.0"
    $script:version = "$($script:cleanVersion)-$($script:buildTag)"
  }
  echo "Building version $version"
}


task default -depends Build

task GenerateVersionNumber {
  Generate-VersionNumber
}

task PatchAssemblyInfos -depends GenerateVersionNumber {
  Get-ChildItem "$solutionDir\**\Properties\AssemblyInfo.cs" | Foreach-Object {
    $propertyInfoPath = $_.FullName
    $content = Get-Content $propertyInfoPath

    $title = $content | select-string -Pattern  "\[assembly: AssemblyTitle\(""(?<title>[^(]+).*""\)\]" | select -expand Matches | foreach {$_.groups["title"].value}
    $title = $title.Trim()

    $attributes = @{
      AssemblyTitle = "$title ($($script:buildTag))"
      AssemblyProduct = "$title ($($script:buildTag))"
      AssemblyVersion = $script:cleanVersion
      AssemblyFileVersion = $script:cleanVersion
      AssemblyConfiguration = "$title-$($script:version)"
    }

    Write-Host "Pacthing $($propertyInfoPath)"
    $attributes.GetEnumerator() | foreach-object {
      Write-Host "Applying $($_.Name)=$($_.Value)"
      $content = $content -replace "\[assembly: $($_.Name)\("".*""\)\]", "[assembly: $($_.Name)(""$($_.Value)"")]" 
    }
    Set-Content -Path $propertyInfoPath -Value $content -Force
    Write-Host "Pacthed $($propertyInfoPath)"
  }

}

task Build -depends GenerateVersionNumber,PatchAssemblyInfos

task BuildNuGetPackages -depends CleanNugetPackages,GenerateVersionNumber {
  $nuspecs = Get-ChildItem $solutionDir -Name *.nuspec -Recurse
  if($nuspecs) {
    foreach($nuspec in $nuspecs) {
      if(-not (join-path $solutionDir $nuspec).startsWith($packagesPath)) {
        Create-NuGetPackage $nuspec
      }
    }
  } else {
    write-output "No .nuspec's found in solution: '$solutionDir'"
  }
}

task CleanNuGetPackages {
  if (Test-Path $nugetPackageDir) {
    Get-ChildItem $nugetPackageDir |% {remove-item $_.fullname}
  }
}


task Test {
  if($script:hasFailedTests) {
    throw "There was errors running the tests"
  }
}


task ? -Description "Display help" {
  $global:psakeTasks = Write-Documentation
  $global:psakeTasks
}

task GetTasks -Description "Returns a list of tasks" {
  $currentContext = $psake.context.Peek()
  $global:psakeTasks = $currentContext.tasks.Keys | Foreach-Object { $currentContext.tasks[$_].Name } | sort
  $global:psakeTasks
}

task BuildServerRun -depends Build,Test,BuildNuGetPackages

task Watch -Description "Watch using plugins."

task Deploy -Description "Deploy applications"

task VisualStudio-Init -Description "Init call for running from Visual Studio"

foreach($packageName in $buildConfiguration.packages) {
  Load-Package $packageName
}