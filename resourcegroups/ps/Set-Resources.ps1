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

function Set-Resource {
    param (
        [object]$resource
    )
    $resourceGroupName = $resource.name
    New-ResourceGroup -Name $resourceGroupName -Location $resource.location
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName 
