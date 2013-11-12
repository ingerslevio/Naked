properties {
  $transformProject = join-path $packagePath "Transform.proj"
  $verbosity = 'quiet'
}

function global:Transform([string] $source, [string] $transformation, [string] $destination)
{
  exec { msbuild $transformProject /t:Transform /property:"Source=$($source);Transformation=$($transformation);Destination=$($destination)" }
}

function global:Run-MsBuild([string] $msbuildFile, [string] $msbuildTask, [string] $verbosity) {  
  if($msbuildTask) {
    exec { msbuild $msbuildFile /t:$msbuildTask /verbosity:$verbosity }
  } else {
    exec { msbuild $msbuildFile /verbosity:$verbosity }
  }
}

task BuildSolution -depends CleanSolution -Description "Build Solution with MsBuild. Verbosity can be set with 'verbosity' property eq. -properties @{verbosity='diagnostic'} Possible values: q[uiet], m[inimal], n[ormal], d[etailed], diag[nostic]." {
  Run-MsBuild $solutionFile 'rebuild' $verbosity
}

task CleanSolution {
  Run-MsBuild $solutionFile 'clean' $verbosity
}

Add-Dependency 'Build' 'BuildSolution'