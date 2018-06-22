param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function New-Resource {
    param(
        [object]$resource
    )
    $resourceType = (Get-Item -Path $PSScriptRoot).Parent.Name
    $resourceParameterFileName = $resource.path
    $resourceParameters = Get-TemplateParameters -resourceType $resourceType -parameterFileName $resourceParameterFileName
    $resource.name = Get-FormatedText -strFormat $resource.name
    $resourceParameters.Name = $resource.name
    $name = $resourceParameters.Name
    $rdef = Get-AzureRmRoleDefinition -Name $name -ErrorAction SilentlyContinue
    if ($rdef -ne $null -and $resource.update) {
        Write-Verbose "Updating role defintion for $name"
        $resourceParameters | Add-Member -Name 'Id' -MemberType Noteproperty -Value $rdef.Id
        $rdef.AssignableScopes | ForEach-Object {
            $resourceParameters.AssignableScopes += $_
        }
    }
    elseif ($rdef -eq $null) {
        Write-Verbose "Creating role definition $name"
        $subscriptionId = Get-SubscriptionId
        $subcriptionToAdd = "/subscriptions/{0}" -f $subscriptionId
        $resourceParameters.AssignableScopes += $subcriptionToAdd
    }
    else {
        Write-Verbose "Role definition $name exists and not updated"
        return
    }
    
    Set-ParametersToFile -resourceType $resourceType `
        -parameters $resourceParameters `
        -parameterFileName $resourceParameterFileName
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
