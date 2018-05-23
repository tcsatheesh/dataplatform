param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Get-Principal {
    param (
        [string]$subtype
    )
    $parameterFileName = "principals.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    $resource = $parameters.parameters.resources.value | Where-Object {$_.subtype -eq $subtype}
    return $resource.servicePrincipal
}
function Get-ADGroup {
    param (
        [string]$type
    )
    $parameterFileName = "adgroups.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    $resource = $parameters.parameters.resources.value | Where-Object {$_.type -eq $type}  
    return $resource 
}

function New-Resources {
    $folderParameters = $parameters.parameters.resources.value

    $folderParameters.adlStoreName = Get-FormatedText $folderParameters.adlStoreName

    foreach ($folder in $folderParameters.folders) {
        $folderName = $folder.folderName
        Write-Verbose "Processing $folderName"
        foreach ($permission in $folder.permissions) {
            $aadName = $permission.AADName
            $aadType = $permission.AADType
            Write-Verbose "Permission in $folderName for $aadName"
            if ($aadType -eq "SPN") {
                $resource = Get-Principal -subtype $aadName
                $aadName = $resource.name
                $objectid = $resource.id
            } 
            else {
                $resource = Get-ADGroup -type $aadName
                $aadName = $resource.name
                $objectid = $resource.id
            }
            Write-Verbose "Processing folder $folderName for aad user $aadName"
            $permission.AADName = $aadName
            $permission.Id = $objectid        
        }
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName

& "$commonPSFolder\Invoke-NewProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name `
    -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json" `
    -procToRun {New-Resources}