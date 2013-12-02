task TestNUnit {

  if(-not $buildConfiguration.NUnitFiles) {
    throw "Could not find list of nunit files in property \$NUnitFiles"
  }

  foreach($nunitFile in $buildConfiguration.NUnitFiles) {
    $testFile = $nunitFile
    $nunit = (Get-ChildItem (join-path $packagesPath NUnit.Runners*\tools\nunit-console-x86.exe) | Sort LastWriteTime -Descending | Select-Object -First 1).FullName

    $fullTestFileName = $testFile
    if(-not $fullTestFileName.endswith('.dll') -and -not $fullTestFileName.endswith('.exe')){
      $fullTestFileName = $testFile + '.dll'
    }
    
    # if the testFile name contains \ assume it is a full relative path from the solutionDir
    if($fullTestFileName.Contains("\")) {
      $testFilePath = join-path $solutionDir $fullTestFileName
    } else {
      $testFilePath = join-path $solutionDir (Get-ChildItem $solutionDir -Name $fullTestFileName -Recurse)[0]
    }

    if($isRunningOnBuildServer){
      & $teamcity['teamcity.dotnet.nunitlauncher'] v4.0 x86 NUnit-2.6.2 $testFilePath
    } else {
      & $nunit $testFilePath /framework=v4.0 
    }
    $script:hasFailedTests = $lastexitcode -ne 0

  }
}

Add-Dependency 'Test' 'TestNUnit'
