param(
    [Parameter(Position=0,Mandatory=0)]
    [string]$task = 'Help',

    [Parameter(Position=1,Mandatory=0)]
    [string] $psakeTask = '',

    [Parameter(Position=2,Mandatory=0)]
    [System.Collections.Hashtable] $properties = @{}
)

$majorAndMinorVersion = '0.1.0'

$nugetPackageDir = (join-path (split-path $script:MyInvocation.MyCommand.Path) 'NugetPackages')

Import-Module .\src\NuGetPsake\teamcity.psm1 -DisableNameChecking

function Update-Version {
  # versioning.ps1 directly included - start
  if($env:TEAMCITY_VERSION) {
    Write-Output "Build Script is running on build server"
    $script:isRunningOnBuildServer = $true
    $vcsNumber = $env:BUILD_VCS_NUMBER
    $buildTag = $env:BUILD_TAG
    
    # calculate build number unless its already been calculated by another build script run.
    if(-not ($env:BUILD_NUMBER -like '*.*.*.*')) {
      #$script:version = "$($majorAndMinorVersion).$($vcsNumber).$($env:BUILD_NUMBER)"
      $script:version = "$($majorAndMinorVersion).$($env:BUILD_NUMBER)"
      if($buildTag)
      {
        $script:version += '-' + $buildTag
      }
    }
    else {
      $script:version = $env:BUILD_NUMBER
    }
    
    Teamcity-SetBuildNumber $script:version

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
    Write-Output "Build Script is NOT running on build server"
    $script:isRunningOnBuildServer = $false
    $tempVersion = [System.DateTime]::Now.ToString("yyyyMMdd.HHmmss")
    $script:version = "$($majorAndMinorVersion).$tempVersion-local"
  }
  # versioning.ps1 directly included - end
}

$descriptions = @{}

$nugetDependencies = 'NUnit.Runners'
$nugetPackageNames = 'NugetPsake', 'NugetPsake.NUnit','NugetPsake.MsBuild','NugetPsake.Script','NugetPsake.Octopus'

$descriptions['Build'] = "Builds the nuget packages"
function Build {
  Update-Version
  if(-not (Test-Path $nugetPackageDir)) {
    [void] (New-Item -ItemType directory -Path $nugetPackageDir)
  }
  Remove-Item (join-path $nugetPackageDir *.nupkg)
  foreach($nugetPackageName in $nugetPackageNames) {
    .\.nuget\NuGet.exe pack .\src\$nugetPackageName.nuspec -version $version -NoPackageAnalysis -OutputDirectory $nugetPackageDir
    $nugetPackageFileName = (Get-ChildItem $nugetPackageDir | Where-Object {$_.Name -match "$nugetPackageName[\d\.\-a-zA-Z]+\.nupkg"}).FullName
    if($isRunningOnBuildServer) {
      TeamCity-PublishArtifact $nugetPackageFileName
    }
  }
}

$descriptions['Install'] = "Installs the nuget packages in Examples"
function Install {

  KillOldOnes

  Build
  foreach($nugetDependency in $nugetDependencies) {
    .\Example\.nuget\NuGet.exe install $nugetDependency -OutputDirectory .\Example\packages
  }
  remove-item .\Example\packages\NugetPsake* -recurse  
  foreach($nugetPackageName in $nugetPackageNames) {
    .\Example\.nuget\NuGet.exe install $nugetPackageName -source $nugetPackageDir -Prerelease -OutputDirectory .\Example\packages
  }
}

$descriptions['TestVsInit'] = "Installs the nuget packages in Examples and runs a init.ps1 test"
function TestVsInit {
  Install

  function script:Register-TabExpansion($taskName, $script) {
    write-host "!Register-TabExpansion for $taskName" -fore Yellow
  }

  $initScript = (Get-ChildItem .\Example\packages\NugetPsake* -recurse -filter "init.ps1")
  $toolsPath = $initScript.Directory.FullName
  $installPath = $initScript.Directory.Parent.FullName

  . $initScript `
      -installPath $installPath `
      -toolsPath $toolsPath
}

$descriptions['Run'] = "Build NuGetPsake and install and run it in Examples. Supply task for running specific psake task."
function Run {
  Install
  .\Example\build.ps1 $psakeTask -properties $properties
}

$descriptions['BuildServerRun'] = "The full run to run on the buildserver."
function BuildServerRun {
  $psakeTask = 'BuildServerRun'
  Run
}

$descriptions['Help'] = "Shows help"
function Help { 
    $descriptions.Keys | Sort | ForEach-Object { 
      New-Object PSObject -Property @{ 
          Task = $_
          Description = $descriptions[$_]
      }
    } | Format-Table -autosize
}

function KillOldOnes {
  try {
    $global:NuGetPsake_Script_ServerProcess.Kill()
  } catch {
  }
}

Invoke-Expression $task