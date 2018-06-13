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

function Set-RoleAssignment {
    param
    (
        [string]$resourceGroupName,
        [string]$objectId,
        [string]$roleName
    )
    Write-Verbose "Role assignment for role $roleName with id $objectId for resource group $resourceGroupName"
    $res1 = $null
    if ($objectId -ne $null) {
        $res1 = Get-AzureRmRoleAssignment -ObjectId $objectId -ResourceGroupName $resourceGroupName -RoleDefinitionName $roleName -ErrorAction SilentlyContinue
    }
    if ($res1 -eq $null) {        
        $res1 = New-AzureRmRoleAssignment -ObjectId $objectId -ResourceGroupName $resourceGroupName -RoleDefinitionName $roleName
        Write-Verbose "Role assigned to $resourceGroupName"
    }
    else {
        Write-Verbose "Role assignment exists for $resourceGroupName"
    }
}

function Set-ResourceGroupAcls {
    param(
        [string]$resourceGroupName,
        [object]$acls,
        [string]$roleName
    )

    foreach ($principalTypeRef in $acls.principalsTypeRef) {
        Write-Verbose "Processing principalTypeRef $principalTypeRef"
        $principalObj = Get-ApplicationParameter -type $principalTypeRef
        Set-RoleAssignment -resourceGroupName $resourceGroupName -objectId $principalObj.servicePrincipal.id -roleName $roleName
    }
    
    foreach ($adgroupTypeRef in $acls.adgroupsTypeRef) {
        Write-Verbose "Processing ad group $adgroupTypeRef"
        $selectedADGroup = Get-ADGroupParameter -type $adgroupTypeRef
        Set-RoleAssignment -resourceGroupName $resourceGroupName -objectId $selectedADGroup.id -roleName $roleName
    }
}

function Set-Resource {
    param (
        [object]$resource
    )
    $resourceGroupName = $resource.name
    New-ResourceGroup -Name $resourceGroupName -Location $resource.location
    
    $acls = $resource.contributors
    Set-ResourceGroupAcls -resourceGroupName $resourceGroupName -acls $acls -roleName "Contributor"
    $acls = $resource.readers
    Set-ResourceGroupAcls -resourceGroupName $resourceGroupName -acls $acls -roleName "Reader"
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName 
