param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Get-Principal {
    param (
        [string]$type
    )
    $parameterFileName = "principals.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    $resource = $parameters.parameters.resources.value | Where-Object {$_.type -eq $type}
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

function New-Resource {    
    param(
        [object]$resource
    )
    $resource.adlStoreName = Get-FormatedText $resource.adlStoreName

    foreach ($folder in $resource.folders) {
        $folderName = $folder.folderName
        Write-Verbose "Processing $folderName"
        foreach ($permission in $folder.permissions) {
            $aadName = $permission.AADName
            $aadType = $permission.AADType
            Write-Verbose "Permission in $folderName for $aadName"
            if ($aadType -eq "SPN") {
                $principal = Get-Principal -type $aadName
                $aadName = $principal.name
                $objectid = $principal.id
            } 
            else {
                $group = Get-ADGroup -type $aadName
                $aadName = $group.name
                $objectid = $group.id
            }
            Write-Verbose "Processing folder $folderName for aad user $aadName"
            $permission.AADName = $aadName
            $permission.Id = $objectid        
        }
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
