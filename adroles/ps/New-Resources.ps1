param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function New-Resource {
    param (
        [object]$resource
    )
    $roleName = $resource.role.name
    Write-Verbose "Processing role $roleName"
    $roleId = $resource.role.id    
    if ([string]::IsNullOrEmpty($roleId)) {
        $roleObjectId = (Get-AzureADDirectoryRole | Where-Object {$_.DisplayName -eq $roleName}).ObjectId
        if ( [string]::IsNullOrEmpty($roleObjectId)) {
            throw "AD role $roleName not found in Azure Active Directory."
        }else {
            $resource.role.id = $roleObjectId
        }                    
    }
    foreach ($member in $resource.members) {
        if ($member.type -eq "users") {
            $user = Get-AzureRmADUser -UserPrincipalName $member.user.upn
            $member.user.id = $user.Id
        }
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"


