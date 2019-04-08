param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Get-Values($value) {
    $tenantId = (Get-ProjectParameter -type "tenant").id
    $analysisServicesName = Get-FormatedText -strFormat "{0}{1}{2}as01"
    
    $outputValues = @()
    foreach ($val in $value) {
        Write-Verbose "Incoming value is $val"
        if ($val.Contains("<tenantId>")){
            $newVal = $val.Replace("<tenantId>", $tenantId)
        }
        elseif ($val.Contains("<analysisServicesName>")) {
            $newVal = $val.Replace("<analysisServicesName>", $analysisServicesName)
        }
        else {
            $newVal = $val
        }
        Write-Verbose "Outgoing value is $newVal"
        $outputValues += $newVal
    }
    return $outputValues
}

function Set-ResourceSpecificParameters {
    param (
        [object]$resource,
        [object]$resourceparam
    )
    $val = Get-Values($resourceparam.value)    
    return $val
}


$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\New-Resources.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name