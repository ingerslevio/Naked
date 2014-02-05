param(
    [Parameter(Position=0,Mandatory=0)]
    [string]$task = 'Help',

    [Parameter(Position=1,Mandatory=0)]
    [string] $psakeTask = '',

    [Parameter(Position=2,Mandatory=0)]
    [System.Collections.Hashtable] $properties = @{},

    [Parameter(Position=3,Mandatory=0)]
    [string] $example = 'Example'
)

$majorAndMinorVersion = '0.1.0'

$nugetPackageDir = (join-path (split-path $script:MyInvocation.MyCommand.Path) 'NugetPackages')

Import-Module .\src\naked\teamcity.psm1 -DisableNameChecking

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
    $tempVersion = [System.DateTime]::Now.ToString("ddHHmmss")
    $script:version = "$($majorAndMinorVersion).$tempVersion-local"
  }
  # versioning.ps1 directly included - end
}

$descriptions = @{}

$nugetPackageNames = 'Naked', 'Naked.NUnit','Naked.MsBuild','Naked.Script','Naked.Octopus','Naked.Mimosa'

$descriptions['Build'] = "Builds the nuget packages"
function Build {
  Update-Version
  if(-not (Test-Path $nugetPackageDir)) {
    [void] (New-Item -ItemType directory -Path $nugetPackageDir)
  }
  Remove-Item (join-path $nugetPackageDir *.nupkg)
  foreach($nugetPackageName in (get-childitem ./src/*.nuspec | foreach-object { $_.basename })) {
    .\.nuget\NuGet.exe pack .\src\$nugetPackageName.nuspec -version $version -NoPackageAnalysis -OutputDirectory $nugetPackageDir
    $nugetPackageFileName = (Get-ChildItem $nugetPackageDir | Where-Object {$_.Name -match "$nugetPackageName[\d\.\-a-zA-Z]+\.nupkg"}).FullName
    if($isRunningOnBuildServer) {
      TeamCity-PublishArtifact $nugetPackageFileName
    }
  }
}

$descriptions['Install'] = "Installs the nuget packages in Examples"
function Install {
  Build

  [xml] $packagesConfig = Get-Content ".\$example\.nuget\packages.config"
  $packages = $packagesConfig.packages.package

  foreach($nugetDependency in ($packages | where { -not $_.version.endsWith("-local") })) {
    & ".\$example\.nuget\NuGet.exe" install $nugetDependency.id -OutputDirectory .\$example\packages -version $nugetDependency.version
  }
  remove-item .\$example\packages\naked* -recurse  
  foreach($nugetPackage in ($packages | where { $_.version.endsWith("-local") })) {
    & ".\$example\.nuget\NuGet.exe" install $nugetPackage.id -source $nugetPackageDir -Prerelease -OutputDirectory .\$example\packages
  }
}

$descriptions['TestVsInit'] = "Installs the nuget packages in Examples and runs a init.ps1 test"
function TestVsInit {
  Install

  function script:Register-TabExpansion($taskName, $script) {
    write-host "!Register-TabExpansion for $taskName" -fore Yellow
  }

  $initScript = (Get-ChildItem .\$example\packages\naked* -recurse -filter "init.ps1")
  $toolsPath = $initScript.Directory.FullName
  $installPath = $initScript.Directory.Parent.FullName

  . $initScript `
      -installPath $installPath `
      -toolsPath $toolsPath
}

$descriptions['Run'] = "Build naked and install and run it in Examples. Supply task for running specific psake task."
function Run {
  Install
  & ".\$example\build.ps1" $psakeTask -properties $properties
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

Invoke-Expression $task