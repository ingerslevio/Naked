# Naked

Intial BuildConfiguration.json for Naked is:

```json
{
  "MajorAndMinorVersion": "1.0",
  "Framework": "4.0x64",
  "Packages": []
}
```

Naked's BuildConfiguration.json is plain JSON and must comple to its rules.

To use addtional Naked packages you should add them by name to Packages config:

```json
{
  "Packages": [
    "Naked.MsBuild",
    "Naked.NUnit"
  ]
}
```

The solution can specify it's ProjectName if its not the same as the branch's parent folder. 
For a solution such as '$/Ennova.ExampleProject/Main' it would default to 'Ennova.ExampleProject'

```json
{
  "ProjectName": "Ennova.AnotherNameForExampleProject"
}
```
## Naked.MsBuild

This package adds several msbuild commands for building the solution. It needs no configuration, but its needed to build visual studio solutions.
## Naked.NUnit

For using Naked.NUnit there must be a setting declaring the dll's containing NUnit tests

```json
{
  "NUnitFiles": [
    "Ennova.ExampleProject.Client.Tests",
    "Ennova.ExampleProject.Server.Tests"
  ]
}
```
