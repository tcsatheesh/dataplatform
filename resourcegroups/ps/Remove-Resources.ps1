param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-ResourceGroup {
    param (
        [string]$resourceGroupName
    )
    Write-Verbose "Removing resource group $resourceGroupName"
    $null = Remove-AzureRmResourceGroup -Name $resourceGroupName -Force -ErrorAction SilentlyContinue
}

function Remove-Resource {
    param (
        [object]$resource
    )
    Remove-ResourceGroup -resourceGroupName $resource.name
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-RemoveProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName