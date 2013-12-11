task 'Test:NUnit' {

  if(-not $buildConfiguration.NUnitFiles) {
    throw "Could not find list of nunit files in property \$NUnitFiles"
  }

  foreach($nunitFile in $naked.buildConfiguration.NUnitFiles) {
    $testFile = $nunitFile
    $nunit = (Get-ChildItem (join-path $naked.properties.packagesPath NUnit.Runners*\tools\nunit-console-x86.exe) | Sort LastWriteTime -Descending | Select-Object -First 1).FullName

    $fullTestFileName = $testFile
    if(-not $fullTestFileName.endswith('.dll') -and -not $fullTestFileName.endswith('.exe')){
      $fullTestFileName = $testFile + '.dll'
    }
    $testFilePath = join-path $naked.properties.solutionDir (Get-ChildItem $naked.properties.solutionDir -Name $fullTestFileName -Recurse)[0]

    if($naked.properties.isRunningOnBuildServer){
      & $naked.properties.teamcity['teamcity.dotnet.nunitlauncher'] v4.0 x86 NUnit-2.6.2 $testFilePath
    } else {
      & $nunit $testFilePath /framework=v4.0 
    }
    $naked.properties.hasFailedTests = $lastexitcode -ne 0

  }
}

Add-Dependency 'Test' 'Test:NUnit'