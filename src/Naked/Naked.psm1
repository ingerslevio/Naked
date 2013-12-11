$path = (split-path $script:MyInvocation.MyCommand.Path)

function Run-Task($task) {
    . $path\Startnaked.ps1 $Task
}

function GetAvailableTasks($context) {
    [void] (Run-Task 'GetTasks')
    return $psakeTasks | sort
}

function Copy-BuildDefinition {
    $solutionItemsPath = join-path $script:toolsPath 'SolutionItems'

    WriteIfChanged -from (join-path $solutionItemsPath build.ps1) -to (join-path $solutionPath build.ps1)

    $packagesPath = split-path $installPath
    $documentation = [string]::join([Environment]::NewLine, (Get-ChildItem $packagesPath -filter "BuildConfiguration.md" -recurse | foreach-object { Get-Content $_.FullName }))
    EnsureWriteAccess (join-path $solutionPath BuildConfiguration.md)
    WriteIfChanged -fromContent $documentation -to (join-path $solutionPath BuildConfiguration.md)

    try {
      [string] $documentationHtml = (Invoke-RestMethod -uri "https://api.github.com/markdown/raw" -Body $documentation -method post -ContentType "text/plain")
      $documentationHtml = "<!DOCTYPE html><html><head><title>BuildConfiguration documentation</title><style>" + (Get-Content (join-path $script:toolsPath 'markdown.css')) + "</style></head><body>" + $documentationHtml + "</body></html>"
      EnsureWriteAccess (join-path $solutionPath BuildConfiguration.html)

      WriteIfChanged -fromContent $documentationHtml -to (join-path $solutionPath BuildConfiguration.html)
    }
    catch {
      Write-Host "Could not create html documentation" -fore Yellow
    }

    if(-not (Test-Path (join-path $solutionPath BuildConfiguration.json))) {
      Copy-Item (join-path $solutionPath BuildConfiguration.template.json) (join-path $solutionPath BuildConfiguration.json)
    }
}

function EnsureWriteAccess($file) {
  if(-not (Test-Path $file)) {
    return
  }

  if((Get-ChildItem $file).IsReadOnly) {
    try {
      $visualStudioVersion = (Get-ChildItem "C:\Program Files (x86)\Microsoft Visual Studio*" | foreach-object { [void] ($_.name -match "[a-z ]+([0-9]+)\.[0-9]+"); [int] $matches[1] } | sort -Descending)[0]
      $tfPath = (Get-ChildItem "C:\Program Files (x86)\Microsoft Visual Studio $($visualStudioVersion).*\Common7\IDE\TF.exe")[0].FullName
      . $tfPath checkout $to
    } catch {
      write-host "Could not make file $($file) writeable, because it was not possible to check it out with TF. Error: {$error[0]}" -fore Yellow
      Remove-Item $file -Force
    }
  }
}

function WriteIfChanged() {
    param($from, $fromContent, $to)
    if(-not $fromContent) {
      $fromContent = Get-Content $from
    }
    write-output Test-Path $to
    if((-not (Test-Path $to)) -or (Compare-Object $fromContent $(Get-Content $to))) {
        EnsureWriteAccess $to

        if(-not (Test-Path $to)) {
          write-host "Creating $to" -fore yellow
          [void] (New-Item $to -type file -value "")  
        }
        write-host "Writing new content to $to" -fore yellow
        [void] (Set-Content $to -Force -Value $fromContent)
    } else {
        write-host "No changes to $to" -fore yellow
    }
}

function Set-Settings($installPath, $toolsPath) {
    $script:installPath = $installPath
    $script:toolsPath = $toolsPath
    $script:package = $package

    if($dte) {
      $script:solution = Get-Interface $dte.Solution ([EnvDTE80.Solution2])
      $script:solutionPath = split-path $solution.FullName
    } else {
      $script:solutionPath = split-path (split-path $installPath)
    }
}

Register-TabExpansion 'Run-Task' @{
    'task' = {
        param($context)
        GetAvailableTasks($context)
    }
}

Export-ModuleMember Run-Task,Set-Settings,Copy-BuildDefinition