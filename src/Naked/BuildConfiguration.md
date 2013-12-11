# NuGetPsake

Intial BuildConfiguration.json for NuGetPsake is:

```json
{
  "MajorAndMinorVersion": "1.0",
  "Framework": "4.0x64",
  "Packages": []
}
```

NuGetPsake's BuildConfiguration.json is plain JSON and must comple to its rules.

To use addtional NuGetPsake packages you should add them by name to Packages config:

```json
{
  "Packages": [
    "NuGetPsake.MsBuild",
    "NuGetPsake.NUnit"
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