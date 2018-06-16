param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function New-ResourceGroup {
    param (
        [string]$Name,
        [string]$Location
    )
    $rg1 = New-AzureRmResourceGroup -Name $Name -Location $Location -Force
}

function Set-RoleAssignment2 {
    param
    (
        [string]$resourceGroupName,
        [string]$objectId,
        [string]$roleName
    )
    Write-Verbose "Role assignment for role $roleName with id $objectId for resource group $resourceGroupName"
    $res1 = $null
    if (-not [string]::IsNullOrEmpty($objectId)) {
        $res1 = Get-AzureRmRoleAssignment -ObjectId $objectId -ResourceGroupName $resourceGroupName -RoleDefinitionName $roleName -ErrorAction SilentlyContinue
    }
    if ($res1 -eq $null -and (-not [string]::IsNullOrEmpty($objectId))) {
        $res1 = New-AzureRmRoleAssignment -ObjectId $objectId -ResourceGroupName $resourceGroupName -RoleDefinitionName $roleName
        Write-Verbose "Role $roleName assigned to objectid $objectId in resource group $resourceGroupName"
    }
    else {
        Write-Verbose "Role $roleName assignment for to objectid $objectId exists in resource group $resourceGroupName"
    }
}

function Set-RoleAssignment {
    param
    (
        [string]$resourceGroupName,
        [string]$resourceName,
        [string]$resourceType,
        [string]$objectId,
        [string]$roleName
    )
    Write-Verbose "Role assignment for role $roleName with id $objectId for resource $resourceName in resource group $resourceGroupName"
    $res1 = $null
    if (-not [string]::IsNullOrEmpty($objectId)) {
        $res1 = Get-AzureRmRoleAssignment -ObjectId $objectId -ResourceGroupName $resourceGroupName -resourceName $resourceName -ResourceType $resourceType -RoleDefinitionName $roleName -ErrorAction SilentlyContinue
    }
    if ($res1 -eq $null -and (-not [string]::IsNullOrEmpty($objectId))) {
        $res1 = New-AzureRmRoleAssignment -ObjectId $objectId -ResourceGroupName $resourceGroupName -resourceName $resourceName -ResourceType $resourceType -RoleDefinitionName $roleName
        Write-Verbose "Role $roleName assigned to objectid $objectId for resource $resourceName in resource group $resourceGroupName"
    }
    else {
        Write-Verbose "Role $roleName assignment for to objectid $objectId exists for resource $resourceName in resource group $resourceGroupName"
    }
}


function Set-ResourceAcls {
    param(
        [object]$resource
    )
    foreach ($acl in $resource.accesspolicies ) {        
        $roleName = $acl.type
        foreach ($policy in $acl.policies) {
            if ($policy.type -eq "principals") {
                foreach ($principalTypeRef in $policy.ref) {
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
                                if ([string]::IsNullOrEmpty($resource.resourcename)) {
                                    Set-RoleAssignment2 -resourceGroupName $resource.resourceGroupName -objectId $objectId -roleName $roleName
                                }else {
                                    Set-RoleAssignment -resourceGroupName $resource.resourceGroupName -resourceName $resource.resourceName -resourceType $resource.azureResourceType -objectId $objectId -roleName $roleName
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
                                    Set-RoleAssignment2 -resourceGroupName $resource.resourceGroupName -objectId $objectId -roleName $roleName
                                }else {
                                    Set-RoleAssignment -resourceGroupName $resource.resourceGroupName -resourceName $resource.resourceName -resourceType $resource.azureResourceType -objectId $objectId -roleName $roleName
                                }
                            }
                            else {
                                Write-Verbose "AD Group $adgroupTypeRef with objectId $objectId does not exist in the Azure AD"
                            }
                        }
                    }
                    else {
                        Write-Verbose "adgroups.parameters.json does not exist"
                    }
                }        
            }
            else {
                throw "this type: $($policy.type) of acl policy is not supported. Supported types are adgroups and principals"
            }
        }
    }    
}

function Set-Resource {
    param (
        [object]$resource
    )    
    Set-ResourceAcls -resource $resource
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName 
