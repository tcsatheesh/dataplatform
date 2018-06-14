param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,

    [Parameter(Mandatory = $True, HelpMessage = 'The user type to runas.')]
    [String]$runas
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
    $resources = ($parameters.parameters.resources.value | Where-Object {$_.type -eq $runas}).resources
    $index = $resources.Length - 1
    foreach ($r in $resources) {
        $resource = $resources[$index--]        
        Remove-Resource2 -resourceType $resource.resourceType
    }
}

$parameters = Get-Content -Path (Get-Item -Path $projectsParameterFile).FullName -Raw | ConvertFrom-JSON

Remove-Resources2 -parameters $parameters