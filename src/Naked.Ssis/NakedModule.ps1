function Apply-SSIS-Configuration([string] $Configuration)
{
  $source = join-path $ssisProject "Project.default.params"
  $transformation = join-path $ssisProject "Project.$($Configuration).params"
  $destination = join-path $ssisProject "Project.params"
  Transform $source $transformation $destination
}

function Build-SSIS-Deploy-Script([string] $Configuration)
{
  Apply-SSIS-Configuration($Configuration)
  exec { msbuild $ssisBuildProject /t:SSISBuild /property:"Configuration=$Configuration;SSISProjectPath=$($ssisProjectFile);Platform=x86" }
}


task SSISConfiguration { 
  $environments = "Debug", "UnitTest", "Development", "QualityAssurance", "Production"
  $configuration = Read-Host "Choose environment in list: $([string]::join(', ', $environments)) (only first letters required)"
  Foreach ($environment in $environments)
  {
    if($environment.StartsWith($configuration,"CurrentCultureIgnoreCase"))
    {
      $configuration = $environment
      break
    }

  }
  Apply-SSIS-Configuration($configuration) 
}