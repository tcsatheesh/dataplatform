param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-RoleAssignment3 {
    param
    (
        [string]$objectId,
        [string]$roleName
    )
    Write-Verbose "Removing role assignment for role $roleName with id $objectId for subscription"
    $res1 = $null
    if (-not [string]::IsNullOrEmpty($objectId)) {
        $res1 = Get-AzureRmRoleAssignment -ObjectId $objectId -RoleDefinitionName $roleName -ErrorAction SilentlyContinue
    }
    if ($res1 -eq $null -and (-not [string]::IsNullOrEmpty($objectId))) {
        $res1 = Remove-AzureRmRoleAssignment -ObjectId $objectId -RoleDefinitionName $roleName
        Write-Verbose "Role $roleName removed for objectid $objectId in subscription"
    }
    else {
        Write-Verbose "Role $roleName does not exist for objectid $objectId exists in subscription"
    }
}
function Remove-RoleAssignment2 {
    param
    (
        [string]$resourceGroupName,
        [string]$objectId,
        [string]$roleName
    )
    Write-Verbose "Removing role assignment for role $roleName with id $objectId for resource group $resourceGroupName"
    $res1 = $null
    if (-not [string]::IsNullOrEmpty($objectId)) {
        $res1 = Get-AzureRmRoleAssignment -ObjectId $objectId -ResourceGroupName $resourceGroupName -RoleDefinitionName $roleName -ErrorAction SilentlyContinue
    }
    if ($res1 -ne $null -and (-not [string]::IsNullOrEmpty($objectId))) {
        $res1 = Remove-AzureRmRoleAssignment -ObjectId $objectId -ResourceGroupName $resourceGroupName -RoleDefinitionName $roleName
        Write-Verbose "Role $roleName removed for objectid $objectId in resource group $resourceGroupName"
    }
    else {
        Write-Verbose "Role $roleName does not exist for objectid $objectId in resource group $resourceGroupName"
    }
}

function Remove-RoleAssignment {
    param
    (
        [string]$resourceGroupName,
        [string]$resourceName,
        [string]$resourceType,
        [string]$objectId,
        [string]$roleName
    )
    Write-Verbose "Removing role assignment for role $roleName with id $objectId for resource $resourceName in resource group $resourceGroupName"
    $res1 = $null
    if (-not [string]::IsNullOrEmpty($objectId)) {
        $res1 = Get-AzureRmRoleAssignment -ObjectId $objectId -ResourceGroupName $resourceGroupName -resourceName $resourceName -ResourceType $resourceType -RoleDefinitionName $roleName -ErrorAction SilentlyContinue
    }
    if ($res1 -ne $null -and (-not [string]::IsNullOrEmpty($objectId))) {
        $res1 = Remove-AzureRmRoleAssignment -ObjectId $objectId -ResourceGroupName $resourceGroupName -resourceName $resourceName -ResourceType $resourceType -RoleDefinitionName $roleName
        Write-Verbose "Role $roleName removed for objectid $objectId for resource $resourceName in resource group $resourceGroupName"
    }
    else {
        Write-Verbose "Role $roleName does not exist for objectid $objectId for resource $resourceName in resource group $resourceGroupName"
    }
}
function Remove-ResourceAcls {
    param(
        [object]$resource
    )
    foreach ($acl in $resource.accesspolicies ) {        
        $roleName = $acl.type
        foreach ($policy in $acl.policies) {
            if ($policy.type -eq "principals") {
                foreach ($principalTypeRef in $policy.ref) {
                    Write-Verbose "Processing principalTypeRef $principalTypeRef"
                    $principalObj = Get-ApplicationParameter -type $principalTypeRef -godeep
                    if ($null -ne $principalObj) {
                        $objectId = $principalObj.servicePrincipal.id
                        if ([string]::IsNullOrEmpty($objectid)) {
                            Write-Verbose "Principal $principalTypeRef not defined in the environment"
                        }
                        else {        
                            $app = Get-AzureRmADServicePrincipal -ObjectId $objectId -ErrorAction SilentlyContinue
                            if ($null -ne $app) {
                                if ([string]::IsNullOrEmpty($resource.resourcename) -and [string]::IsNullOrEmpty($resource.resourceGroupName)) {
                                    Remove-RoleAssignment3 -objectId $objectId -roleName $roleName
                                }elseif ([string]::IsNullOrEmpty($resource.resourcename)) {
                                    Remove-RoleAssignment2 -resourceGroupName $resource.resourceGroupName -objectId $objectId -roleName $roleName
                                }else {
                                    Remove-RoleAssignment -resourceGroupName $resource.resourceGroupName -resourceName $resource.resourceName -resourceType $resource.azureResourceType -objectId $objectId -roleName $roleName
                                }
                            }
                            else {
                                Write-Verbose "Service Principal $principalTypeRef with objectId $objectId does not exist in the Azure AD"
                            }
                        }
                    }
                    else {
                        Write-Verbose "Principal $principalTypeRef does not exist in principals.parameters.json."
                    }
                }        
            }
            elseif ($policy.type -eq "adgroups") {
                foreach ($adgroupTypeRef in $policy.ref) {
                    Write-Verbose "Processing ad group $adgroupTypeRef"
                    $selectedADGroup = Get-ADGroupFromType -type $adgroupTypeRef
                    if ($selectedADGroup -ne $null) {
                        $objectId = $selectedADGroup.id
                        if ([string]::IsNullOrEmpty($objectid)) {
                            Write-Verbose "AD Group $adgroupTypeRef not defined in the environment"
                        }
                        else {
                            $group = Get-AzureRmADGroup -ObjectId $objectId -ErrorAction SilentlyContinue
                            if ($group -ne $null) {
                                if ([string]::IsNullOrEmpty($resource.resourcename)) {
                                    Remove-RoleAssignment2 -resourceGroupName $resource.resourceGroupName -objectId $objectId -roleName $roleName
                                }else {
                                    Remove-RoleAssignment -resourceGroupName $resource.resourceGroupName -resourceName $resource.resourceName -resourceType $resource.azureResourceType -objectId $objectId -roleName $roleName
                                }
                            }
                            else {
                                Write-Verbose "AD Group $adgroupTypeRef with objectId $objectId does not exist in the Azure AD"
                            }
                        }
                    }
                    else {
                        Write-Verbose "ADGroup $adgroupTypeRef does not exist in adgroups.parameters.json."
                    }
                }        
            }
            else {
                throw "this type: $($policy.type) of acl policy is not supported. Supported types are adgroups and principals"
            }
        }
    }    
}


function Remove-Resource {
    param (
        [object]$resource
    )
    Remove-ResourceAcls $resource
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-RemoveProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName