if(-not $buildConfiguration.Octopus) {
  $octopus = @{}
} else {
  $octopus = $buildConfiguration.Octopus    
}

$settingNames = `
  'Server', `
  'ApiKey'

foreach($name in $settingNames) {
  if(-not $octopus[$name]) { 
    $octopus[$name] = [environment]::GetEnvironmentVariable($name) 
  }
}

$script:octo = join-path $packages.Script.ToolsPath octo.exe

task DeployWithOctopus {
  
  foreach($deploy in $octopus.deploys) {
    exec { &$octo create-release --server=$($octopus.Server) --project=NordeaEm --deployto= --apiKey=$($octopus.ApiKey) }
  }
}

#Add-Dependency 'Deploy', 'DeployWithOctopus'