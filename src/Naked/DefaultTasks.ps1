properties {
  $buildConfiguration = $naked.buildConfiguration
  foreach ($key in $naked.properties.keys) {
    set-item -path "variable:$key" -value $naked.properties.$key | out-null
  }
  $buildScript = join-path $solutionDir nakedModule.ps1
  $hasBuildScript = Test-Path $buildScript
  $nuget = join-path $solutionDir '.nuget/NuGet.exe'
  $nugetPackageDir = join-path $solutionDir 'nugetpackages'
  $hasFailedTests = $false
}

task Init {
}

task default -depends Build

[void] (Add-NakedProcedure -Procedure GenerateVersionNumber -Name Test -ScriptBlock {
  $version = $buildConfiguration.version
  if(-not $version) {
    throw '$version not set. Insert "version": "1.0.0" in BuildConfiguration.json'
  }

  if($isRunningOnBuildServer) {
    $vcsNumber = $env:BUILD_VCS_NUMBER
    $script:buildTag = $env:BUILD_TAG
    
    # calculate build number unless its already been calculated by another build script run.
    if(-not ($env:BUILD_NUMBER -like '*.*.*.*')) {
      $script:cleanVersion = "$($version).$($env:BUILD_NUMBER)"
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
    $script:cleanVersion = "$($version).0"
    $script:version = "$($script:cleanVersion)-$($script:buildTag)"
  }
  echo "Building version $version"
})

task GenerateVersionNumber {
  [void] (Invoke-NakedProcedure GenerateVersionNumber)
}

task PatchAssemblyInfos -depends GenerateVersionNumber {
  Get-ChildItem "$solutionDir\**\Properties\AssemblyInfo.cs" | Foreach-Object {
    try {
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
    catch
    {
      Write-Host "Got error trying to patch $($_.FullName). Error: $($error[0])" -fore Red
      throw "Got error trying to patch $($_.FullName). Error: $($error[0])"
    }
  }

}

task Build -depends Init,GenerateVersionNumber,PatchAssemblyInfos

task BuildNuGetPackages -depends CleanNugetPackages,GenerateVersionNumber {
  $nuspecFiles = Get-ChildItem $solutionDir -Name *.nuspec -Recurse
  if($nuspecFiles) {
    foreach($nuspecFile in $nuspecFiles) {
      if(-not (join-path $solutionDir $nuspecFile).startsWith($packagesPath)) {
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
    }
  } else {
    write-output "No .nuspec's found in solution: '$solutionDir'"
  }
}

task CleanNuGetPackages -depends Init {
  if (Test-Path $nugetPackageDir) {
    Get-ChildItem $nugetPackageDir |% {remove-item $_.fullname}
  }
}


task Test -depends Init {
  if($script:hasFailedTests) {
    throw "There was errors running the tests"
  }
}


task ? -Description "Display help" -depends Init {
  $global:psakeTasks = Write-Documentation
  $global:psakeTasks
}

task GetTasks -Description "Returns a list of tasks" -depends Init {
  $currentContext = $psake.context.Peek()
  $global:psakeTasks = $currentContext.tasks.Keys | Foreach-Object { $currentContext.tasks[$_].Name } | sort
  $global:psakeTasks
}

task BuildServerRun -depends Init,Build,Test,BuildNuGetPackages

task Watch -Description "Watch using plugins." -depends Init

task Deploy -Description "Deploy applications" -depends Init

task VisualStudio-Init -Description "Init call for running from Visual Studio" -depends Init