properties {
  $test = "not set"
}

task LogBuild {
  Write-Output "Log this Build! (test=$test)"
}

Add-Dependency 'Build' 'LogBuild'