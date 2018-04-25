param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,

    [Parameter(Mandatory = $True, HelpMessage = 'The user type to runas.')]
    [ValidateSet (  "user-administrator",
                    "subscription-owner", 
                    "keyvault-administrator", 
                    "manager", 
                    "developer",
                    "vsts"
                )]
    [String]$runas
)
function Remove-Resource {
    param (
        [object]$resourceType
    ) 
    Write-Verbose "Removing resource $resourceType"
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

function Remove-AllEnvs {
    $resources = ($parameters.parameters.resources.value | Where-Object {$_.type -eq $runas}).resources
    $index = $resources.Length - 1
    foreach ($r in $resources) {
        $resource = $resources[$index--]
        Write-Verbose "Removing resource $resource"
        Remove-Resource -resource $resource
    }
}

$parameterFileName = "projects.parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-RemoveProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Remove-AllEnvs}