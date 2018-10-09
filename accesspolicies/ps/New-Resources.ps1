param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function New-Resource {
    param (
        [object]$resource
    )
    $resourceparameters = Get-ResourceParameters -parameterFileName "$($resource.resourceType).parameters.json"
    $selectedResource = $resourceparameters.parameters.resources.value | Where-Object {$_.type -eq $resource.type}
    $selectedResourceName = $selectedResource.name
    if ($resource.resourceType -ne "subscription") {
        
    }elseif ($resource.resourceType -ne "resourcegroups") {
        $selectedResourceResourceGroupName = Get-ResourceGroupName -resourceGroupTypeRef $selectedResource.resourceGroupTypeRef
        $selectedResourceType = (Get-AzureRmResource -ResourceGroupName $selectedResourceResourceGroupName -ResourceName $selectedResourceName).ResourceType    
        $resource | Add-Member -Name 'resourceName' -MemberType Noteproperty -Value $selectedResourceName
        $resource | Add-Member -Name 'resourceGroupName' -MemberType Noteproperty -Value $selectedResourceResourceGroupName
        $resource | Add-Member -Name 'azureResourceType' -MemberType Noteproperty -Value $selectedResourceType    
    }else {
        $selectedResourceResourceGroupName = Get-ResourceGroupName -resourceGroupTypeRef $selectedResource.type
        $resource | Add-Member -Name 'resourceGroupName' -MemberType Noteproperty -Value $selectedResourceResourceGroupName
    }
    foreach ($policy in $resource.accesspolicies) {
        Write-Verbose "Policy type is $($policy.type)"
        if ($policy.type -eq "Custom") {
            $val = Get-ValueFromResource -resourceType $policy.ref.resourceType `
                                        -typeFilter $policy.ref.typeFilter `
                                        -property $policy.ref.property
            $policy.type = $val
        }
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
