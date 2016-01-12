# Naked

Intial BuildConfiguration.json for Naked is:

```json
{
  "Version": "1.0.0",
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