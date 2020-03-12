param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)


function Set-Resource {
    param (
        [object]$resource
    )
    foreach ($member in $resource.members) {
        if ($member.type -eq "principals") {
            foreach ($principalTypeRef in $member.ref) {
                Write-Verbose "Processing principalTypeRef $principalTypeRef"
                $principalObj = Get-ApplicationParameter -type $principalTypeRef
                if ($principalObj -ne $null) {
                    $objectId = $principalObj.servicePrincipal.id
                    if ([string]::IsNullOrEmpty($objectid)) {
                        Write-Verbose "Principal $principalTypeRef not defined in the environment"
                    }
                    else {        
                        $app = Get-AzureRmADServicePrincipal -ObjectId $objectId -ErrorAction SilentlyContinue
                        if ($app -ne $null) {
                            $roleName = $resource.role.name
                            Write-Verbose "AD role name is $roleName"
                            $roleObjectId = $resource.role.id
                            $member = Get-AzureADDirectoryRoleMember -ObjectId $roleObjectId | Where-Object {$_.ObjectId -eq $objectid}
                            if ($member -eq $null) {
                                Add-AzureADDirectoryRoleMember -ObjectId $roleObjectId -RefObjectId $objectid
                                Write-Verbose "Added $objectId to role $roleName"
                            }
                            else {
                                Write-Verbose "$objectId already exists in role $roleName"
                            }
                        }
                        else {
                            Write-Verbose "Service Principal $principalTypeRef with objectId $objectId does not exist in the Azure AD"
                        }
                    }
                }
                else {
                    Write-Verbose "principals.parameters.json does not exist. "
                }
            }        
        }
        elseif ($member.type -eq "users") {
            $objectId = $member.user.id
            $user = Get-AzureRmADUser -ObjectId $objectId -ErrorAction SilentlyContinue
            if ($user -ne $null) {
                $roleName = $resource.role.name
                Write-Verbose "AD role name is $roleName"
                $roleObjectId = $resource.role.id
                $member = Get-AzureADDirectoryRoleMember -ObjectId $roleObjectId | Where-Object {$_.ObjectId -eq $objectid}
                if ($member -eq $null) {
                    Add-AzureADDirectoryRoleMember -ObjectId $roleObjectId -RefObjectId $objectid
                    Write-Verbose "Added $objectId to role $roleName"
                }
                else {
                    Write-Verbose "$objectId already exists in role $roleName"
                }
            }
            else {
                throw "User $($user.DisplayName) does not exist"
            }
        }
        else {
            throw "The type $($member.type) is not supported."
        }
    }
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName


