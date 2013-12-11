if(-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw "node.js must be installed on PATH to use NuGetPsake.Script"
}

if(-not $global:NuGetPsake_Script_WatchedDirectories) {
  $global:NuGetPsake_Script_WatchedDirectories = New-Object System.Collections.ArrayList
}

$global:NuGetPsake_Script_Paths = @{}

function script:Watch([string] $path, [string] $destination) {

  $filter = '*.*'

  $fsw = New-Object IO.FileSystemWatcher $path, $filter -Property @{IncludeSubdirectories = $true;NotifyFilter = [IO.NotifyFilters]'FileName, LastWrite'} 

  $messageData = @{
    Source = $path
    Destination = $destination
    ToolsPath = $packages.Script.ToolsPath
  }

  [void] $global:NuGetPsake_Script_WatchedDirectories.Add($path)
  foreach($type in @('Created', 'Deleted', 'Changed', 'Error', 'Renamed')) {
    $eventName = "$($path)$($type)"
    [void] (Register-ObjectEvent $fsw $type -SourceIdentifier $eventName -MessageData $messageData -Debug -Action { 
      try {
        $name = $Event.SourceEventArgs.FullPath
        $changeType = $Event.SourceEventArgs.ChangeType 
        $timeStamp = $Event.TimeGenerated 

        # Throttle events, because of FileSystemWatcher sometimes publishes multiple events from one change
        if( ($global:NuGetPsake_Script_Paths[$name]) -and (($timeStamp.Subtract($global:NuGetPsake_Script_Paths[$name])).Seconds -eq 0) ) {
          return
        }
        $global:NuGetPsake_Script_Paths[$name] = $timeStamp

        Write-Host "`r`nThe file '$name' was $changeType at $timeStamp" -fore Green
        # "The file '$name' was $changeType at $timeStamp" >> "c:\workspace\test.txt"
        CallNode -source $Event.MessageData.Source `
                 -destination $Event.MessageData.Destination `
                 -files $name `
                 -toolsPath $Event.MessageData.ToolsPath

        TriggerReload $name

      } catch {
        Write-Host "An error occured while handling event. Error:`r`n $Error" -fore Red
      }
    }) 
  }
}

function script:UnwatchAll {
  foreach($directory in $global:NuGetPsake_Script_WatchedDirectories.clone()) {
    Unwatch $directory
  }
}

function script:Unwatch([string] $path) {
  foreach($type in @('Created', 'Deleted', 'Changed', 'Error', 'Renamed')) {
    $event = "$($path)$($type)"
    try {
      Unregister-Event $event
      [void] $global:NuGetPsake_Script_WatchedDirectories.Remove($path)
    } catch {
    }
  }
}

function global:CallNode($source, $destination, $files, $clear = $false, $toolsPath = $packages.Script.ToolsPath) {

  if(-not $files) {
    $filesParam = ''
  }
  else {
    $filesParam = [string]::join(';',$files)
  }

  Write-Host "node -e ""require('coffee-script'); require('./build')"" ""Source=$source"" ""Destination=$destination"" ""Files=$filesParam"" ""Clear=$clear"""
  Run-AtPath $toolsPath {
    node -e "require('coffee-script'); require('./build')" "Source=$source" "Destination=$destination" "Files=$filesParam" "Clear=$clear"
  }
  
  if($lastexitcode -gt 0) {
    Write-LineByLine "node build script failed"
    return $false
  }
  Write-LineByLine "node build script successfully run" 
  return $true
}

function script:Write-LineByLine($out, $color = $null)
{
  foreach($line in $out) {
    if($color) {
      Write-Host $line -fore $color
    } else {
      Write-Host $line
    }
  }
}

function script:StartServer() {

  try {
    $global:NuGetPsake_Script_ServerProcess.Kill()
  } catch {
  }

  $global:NuGetPsake_Script_ServerProcess = New-Object System.Diagnostics.Process
  $setup = $global:NuGetPsake_Script_ServerProcess.StartInfo
  $setup = New-Object "System.Diagnostics.ProcessStartInfo" 
  $setup.FileName = "node"
  $setup.Arguments = "-e ""require('coffee-script'); require('./server')"""
  $setup.WorkingDirectory = $packages.Script.ToolsPath
  $setup.UseShellExecute = $false
  $setup.RedirectStandardError = $true
  $setup.RedirectStandardOutput = $true
  $setup.RedirectStandardInput = $false
  # Hook into the standard output and error stream events
  $errEvent = Register-ObjectEvent -InputObj $global:NuGetPsake_Script_ServerProcess -Event "ErrorDataReceived" `
    -Action {
        param
        (
            [System.Object] $sender,
            [System.Diagnostics.DataReceivedEventArgs] $e
        )
        Write-Host -foreground "DarkRed" $e.Data
    }
  $outEvent = Register-ObjectEvent -InputObj $global:NuGetPsake_Script_ServerProcess -Event "OutputDataReceived" `
    -Action {
        param
        (
            [System.Object] $sender,
            [System.Diagnostics.DataReceivedEventArgs] $e
        )
        Write-Host $e.Data
    }
  $global:NuGetPsake_Script_ServerProcess.StartInfo = $setup
  [Void] $global:NuGetPsake_Script_ServerProcess.Start()

  $global:NuGetPsake_Script_ServerProcess.BeginOutputReadLine()
  $global:NuGetPsake_Script_ServerProcess.BeginErrorReadLine()


}

function global:TriggerReload($file) {
  $url = "http://localhost:8181/trigger/" + ([System.Web.HttpUtility]::UrlEncode($file.replace('\',';')))
  write-host $url -fore Blue
  $web.DownloadString($url)
  $request = [System.Net.HttpWebRequest]::Create($url)
  $request.cachepolicy = new-object System.Net.Cache.HttpRequestCachePolicy([System.Net.Cache.HttpRequestCacheLevel]::NoCacheNoStore)
  $request.getResponse()
}

function script:InstallNodeDependencies()
{
  copy-item (join-path $packages.Script.ToolsPath package.json) $solutionDir
  copy-item (join-path $packages.Script.ToolsPath README.md) $solutionDir
  echo "Installing node depedencies at $solutionDir"
  Run-AtPath $solutionDir {
    npm install
  }
}

function script:Run-AtPath($path, $script) {
  $currentLocation = (get-location).path
  Set-Location $path
  . $script
  Set-Location $currentLocation
}

task BuildScripts {
  
  InstallNodeDependencies
  
  foreach($scriptDirectory in $buildConfiguration.scriptDirectories) {
    $source = join-path $solutionDir $scriptDirectory.Source
    $output = join-path $solutionDir $scriptDirectory.Output

    if(-not (Test-Path $source)) {
      throw "Could not watch source path '$source'. It does not exist!"
    }

    $files = Get-ChildItem $source -Recurse | where { -not $_.PSIsContainer } | foreach-object { $_.FullName }
    
    CallNode -source $source `
             -destination $output `
             -files $files `
             -clear $true

    echo "Successfully builded $($source) and outputting to $($output)"
  }
}

Add-Dependency 'Build' 'BuildScripts'

task WatchScripts -depends BuildScripts {
   
  UnwatchAll
  
  foreach($scriptDirectory in $buildConfiguration.scriptDirectories) {
    $source = join-path $solutionDir $scriptDirectory.Source
    $output = join-path $solutionDir $scriptDirectory.Output

    if(-not (Test-Path $source)) {
      throw "Could not watch source path '$source'. It does not exist!"
    }

    Watch $source $output
    echo "Successfully started watching $($source) and outputting to $($output)"
  }

  StartServer
}

Add-Dependency 'Watch' 'WatchScripts'
Add-Dependency 'VisualStudio-Init' 'WatchScripts'