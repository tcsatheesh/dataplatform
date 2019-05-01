param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Set-ResourceSpecificParameters {
    param (
        [object]$resource,
        [object]$resourceparam
    )
    if ($resourceparam.name -eq "body") {
        $val = Get-Body -value $resourceparam.value
    }
    elseif ($resourceparam.name -eq "url") {
        $atmnaccname = Get-FormatedText -strFormat $resourceparam.value
        $val = Get-WebhookUri -resourcename $atmnaccname
    }
    elseif ($resourceparam.name -eq "authUrl") {
        $val = Get-AuthUrl -resourceparam $resourceparam
    }
    elseif ($resourceparam.name -eq "analysisServicesResourceUrl") {
        $val = Get-AnalysisServicesResourceUrl -resourceparam $resourceparam
    }
    elseif ($resourceparam.name -eq "webhookName") {
        $val = $resourceparam.value -f (Get-Date -Format yyyyMMddHHmmss)        
    }
    else {
        throw "resource param $($resourceparam.name) not supported"
    } 
    return $val
}


$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\New-Resources.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name