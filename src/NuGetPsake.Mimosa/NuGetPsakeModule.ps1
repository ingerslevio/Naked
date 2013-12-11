function global:Run-Mimosa {
    param(
        [Parameter(Position=0,Mandatory=1)] $mimosaConfig,
        [Parameter(Position=2,Mandatory=1)] $Arguments,
        [Parameter(Position=3,Mandatory=0)] [switch]$SpawnWindow = $false
    )
    $currentDirectory = Get-Location

    try {
        $argumentsString = [string]::join(',', ($arguments | foreach-object { "'$($_)'" }))
    
        $initialScript = "`$arguments = @('-e',""""""require('mimosa')"""""",'mimosa', $argumentsString); " +
                         "Set-Location $($mimosaConfig.Directory.FullName); "
        $processScript = "Write-Host 'Starting: $($mimosaConfig.Directory.FullName)\Mimosa $([string]::join(' ', $arguments))'; " +
                         "Start-Process node -NoNewWindow -Wait -ArgumentList `$arguments; "

        if($SpawnWindow) {
            $script = $initialScript +
                      "while(`$true) { " +
                           $processScript +
                           "Write-Host 'Mimosa stopped. Press a key to retry.'; " +
                           "Read-Host;" +
                      "} "
            
            Write-Host "Opening window for $($mimosaConfig.Directory.FullName)"
            Start-process PowerShell -ArgumentList $script
        } else {
            $script = $initialScript + $processScript

            Start-Process PowerShell -NoNewWindow -Wait -ArgumentList $script
        }
    }
    finally
    {
        Set-Location $currentDirectory
    }
}

properties {
    $mimosaConfigs = Get-ChildItem $solutionDir -filter mimosa-config.coffee -recurse -ErrorAction SilentlyContinue | where { -not ($_.FullName -like '*\node_modules\*') }
}

task InitMimosa {
    if(-not (Get-Command npm -ErrorAction SilentlyContinue)) { 
        throw host "npm can't be found on PATH. It seems that you have not installed nodejs. Ensure it is installed and try again." 
    }

    $currentDirectory = Get-Location
    foreach($mimosaConfig in $mimosaConfigs) {
        try {
            Write-Host "Ensure local Mimosa is installed in $($mimosaConfig.Directory.FullName)"
            Set-Location $mimosaConfig.Directory.FullName
            $mimosa = (npm list mimosa --json | out-string | ConvertFrom-Json).dependencies.mimosa
            if(-not $mimosa) {
                npm install mimosa
                $mimosa = (npm list mimosa --json | out-string | ConvertFrom-Json).dependencies.mimosa
            }
            Write-Host "Mimosa version $($mimosa.version) is installed in $($mimosaConfig.Directory.FullName)"
        }
        finally
        {
            Set-Location $currentDirectory
        }
    }
}

task WatchMimosa -depends InitMimosa {
    foreach($mimosaConfig in $mimosaConfigs) {
        Run-Mimosa $mimosaConfig clean
        Run-Mimosa $mimosaConfig watch,"--server" -SpawnWindow
    }
}

task BuildMimosa -depends InitMimosa {
    foreach($mimosaConfig in $mimosaConfigs) {
        Run-Mimosa $mimosaConfig build
    }
}

Add-Dependency 'Build' 'BuildMimosa'
Add-Dependency 'Watch' 'WatchMimosa'