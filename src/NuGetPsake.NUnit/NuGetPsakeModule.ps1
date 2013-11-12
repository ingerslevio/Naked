function global:Test-NUnit([string] $testFile)
{
  $nunit = (Get-ChildItem (join-path $packagesPath NUnit.Runners*\tools\nunit-console-x86.exe)).FullName
  $fullTestFileName = $testFile
  if(-not $fullTestFileName.endswith('.dll') -and -not $fullTestFileName.endswith('.exe')){
    $fullTestFileName = $testFile + '.dll'
  }
  $testFilePath = join-path $solutionDir (Get-ChildItem $solutionDir -Name $fullTestFileName -Recurse)[0]

  if($isRunningOnBuildServer){
    & $teamcity['teamcity.dotnet.nunitlauncher'] v4.0 x86 NUnit-2.6.2 $testFilePath
  } else {
    & $nunit $testFilePath /framework=v4.0 
  }
  $script:hasFailedTests = $lastexitcode -ne 0
}

task TestNUnit {
  if(-not $buildConfiguration.NUnitFiles) {
    throw "Could not find list of nunit files in property \$NUnitFiles"
  }

  foreach($nunitFile in $buildConfiguration.NUnitFiles) {
    Test-NUnit $nunitFile
  }
}

Add-Dependency 'Test' 'TestNUnit'