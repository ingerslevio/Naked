Framework "4.0x64"

properties {
  #$solutionName = 'naked'
  $majorAndMinorVersion = "1.0"
  $NUnitFiles = 'naked.ExampleProject.Tests'
}

#Load-Package 'naked.MSBuild'
Load-Package 'naked.NUnit'
Load-Package 'naked.Script'