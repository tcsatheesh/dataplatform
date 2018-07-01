param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,

    [Parameter(Mandatory = $False, HelpMessage = 'Set to remove the corresponding project folder.')]
    [Switch]$removeProjectFolder
)
function Remove-Resource2 {
    param (
        [object]$resourceType
    ) 
    Write-Verbose "**************** Removing resource $resourceType ****************"
    $psFolder = (Get-Item -Path "$PSScriptRoot\..\..\$resourceType\ps").FullName
    try{
        $removeScript = ( Get-Item -Path "$psFolder\Remove-Resources.ps1").FullName
        Write-Verbose "Remove script is $removeScript"
        & $removeScript -projectsParameterFile $projectsParameterFile    
    }catch {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
        Write-Verbose "Error Message is $ErrorMessage"
        Write-Verbose "Failed Item is $FailedItem"                
    }
}

function Remove-Resources2 {
    $deployedEnvironment = $parameters.parameters.resources.value | Where-Object {$_.type -eq "envtype"}
    $resources = ($parameters.parameters.resources.value | Where-Object {$_.type -eq $deployedEnvironment.value}).resources
    $index = $resources.Length - 1
    foreach ($r in $resources) {
        $resource = $resources[$index--]        
        Remove-Resource2 -resourceType $resource.resourceType
    }
}

$parameters = Get-Content -Path (Get-Item -Path $projectsParameterFile).FullName -Raw | ConvertFrom-JSON

Remove-Resources2 -parameters $parameters

if ($removeProjectFolder) {
    $projectFolder = (Get-Item -Path $projectsParameterFile).Directory
    Write-Verbose "Removing the project folder $projectFolder"
    Remove-Item -Path $projectFolder -Recurse
}