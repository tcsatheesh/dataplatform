param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Set-Resource {
    param (
        [object]$resource
    )
    
    $dataFactoryResourceGroupName = $resource.datafactoryResourceGroup.name
    $dataFactoryName = $resource.datafactory.name

    foreach ($innerResource in $resource.resources) {
        foreach ($service in $innerResource.linkedservices) {
            Write-Verbose "Processing linked service $($service.templateFile)"
            $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
            $configFile = "$projectFolder\dfpipelines\$($service.templateFile)"

            $depl = Set-AzureRmDataFactoryV2LinkedService `
                -ResourceGroupName  $dataFactoryResourceGroupName `
                -DataFactoryName $dataFactoryName `
                -Name $service.name `
                -DefinitionFile $configFile -Force
        }
        foreach ($service in $innerResource.datasets) {
            Write-Verbose "Processing dataset $($service.templateFile)"
            $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
            $configFile = "$projectFolder\dfpipelines\$($service.templateFile)"
            $depl = Set-AzureRmDataFactoryV2Dataset `
                -ResourceGroupName  $dataFactoryResourceGroupName `
                -DataFactoryName $dataFactoryName `
                -Name $service.name `
                -DefinitionFile $configFile -Force   
        }
        foreach ($service in $innerResource.pipelines) {
            Write-Verbose "Processing pipeline $($service.templateFile)"
            $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
            $configFile = "$projectFolder\dfpipelines\$($service.templateFile)"
            $depl = Set-AzureRmDataFactoryV2Pipeline `
                -ResourceGroupName  $dataFactoryResourceGroupName `
                -DataFactoryName $dataFactoryName `
                -Name $service.name `
                -DefinitionFile $configFile -Force
        }
        foreach ($service in $innerResource.triggers) {
            Write-Verbose "Processing trigger $($service.templateFile)"
            $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
            $configFile = "$projectFolder\dfpipelines\$($service.templateFile)"
            $depl = Set-AzureRmDataFactoryV2Trigger `
                -ResourceGroupName  $dataFactoryResourceGroupName `
                -DataFactoryName $dataFactoryName `
                -Name $service.name `
                -DefinitionFile $configFile -Force
        }
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
