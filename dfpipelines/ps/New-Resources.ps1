param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Write-OutputFile {
    param (
        [object]$resource,
        [object]$outputObj,
        [string]$filePath
    )
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $destinationPath = "$projectFolder\dfpipelines"
    $path = New-Item -Path $destinationPath -ItemType Directory -Force
    $destinationFile = "$destinationPath\$filePath"
    $path = New-Item -Path $destinationFile -ItemType File -Force
    $outputObj | ConvertTo-JSON -Depth 10| Out-File -filepath $destinationFile -Force
    Write-Verbose "Created linked service configuration $destinationFile"
}

function Get-SalesforceInputDataSet {
    param (
        [object]$service,
        [object]$inputdataset
    )
    $inputdataset.name = $service.name

    $referenceName = $service.parameters | Where-Object {$_.type -eq "referenceName"}
    $inputdataset.properties.linkedServiceName.referenceName = $referenceName.value

    return $inputdataset
}
function Get-SalesforceOutputDataSet {
    param (
        [object]$service,
        [object]$outputdataset
    )
    $outputdataset.name = $service.name

    $referenceName = Get-ValueFromResourceRef -parameters $service.parameters -type "referenceName"
    $outputdataset.properties.linkedServiceName.referenceName = $referenceName

    return $outputdataset
}

function Get-SalesforcePipeline {
    param (
        [object]$service,
        [object]$pipeline
    )
    $pipeline.name = $service.name
    
    $inputdataset = $service.parameters | Where-Object {$_.type -eq "inputdataset"}
    $pipeline.properties.activities.inputs[0].referenceName = $inputdataset.value

    $outputdataset = $service.parameters | Where-Object {$_.type -eq "outputdataset"}
    $pipeline.properties.activities.outputs[0].referenceName = $outputdataset.value

    return $pipeline
}

function Get-SalesforceLinkedService {
    param (
        [object]$service,
        [object]$linkedService
    )

    $linkedService.name = $service.name

    $keyVaultName = Get-ValueFromResourceRef -parameters $service.parameters -type "keyvault"
    $usernameSecretName = Get-ValueFromResourceRef -parameters $service.parameters -type "usernameSecretName"
    $passwordSecretName = Get-ValueFromResourceRef -parameters $service.parameters -type "passwordSecretName"
    $securityTokenSecretName = Get-ValueFromResourceRef -parameters $service.parameters -type "securityTokenSecretName"

    $linkedService.properties.typeProperties.username.secretName = $usernameSecretName     
    $linkedService.properties.typeProperties.username.store.referenceName = $keyVaultName
    $linkedService.properties.typeProperties.password.store.referenceName = $keyVaultName
    $linkedService.properties.typeProperties.password.secretName = $passwordSecretName
    $linkedService.properties.typeProperties.securityToken.store.referenceName = $keyVaultName
    $linkedService.properties.typeProperties.securityToken.secretName = $securityTokenSecretName
    
    return $linkedService
}

function Get-SalesForceTumbleTrigger {
    param (
        [object]$service,
        [object]$trigger
    )

    $trigger.name = $service.name

    $startTime = $service.parameters | Where-Object {$_.type -eq "startTime"}
    $trigger.properties.typeProperties.startTime = $startTime.value

    $pipelineName = $service.parameters | Where-Object {$_.type -eq "pipelineName"}
    $trigger.properties.pipeline.pipelineReference.referenceName = $pipelineName.value

    $outputFolderPath = $service.parameters | Where-Object {$_.type -eq "outputFolderPath"}
    $trigger.properties.pipeline.parameters.outputFolderPath = $outputFolderPath.value

    $outputFilePath = $service.parameters | Where-Object {$_.type -eq "outputFilePath"}
    $trigger.properties.pipeline.parameters.outputFilePath = $outputFilePath.value

    $query = $service.parameters | Where-Object {$_.type -eq "query"}
    $trigger.properties.pipeline.parameters.query = $query.value

    return $trigger
}

function Get-ForEachInputDataSet {
    param (
        [object]$service,
        [object]$inputdataset
    )
    $inputdataset.name = $service.name

    $referenceName = Get-ValueFromResourceRef -parameters $service.parameters -type "referenceName"
    $inputdataset.properties.linkedServiceName.referenceName = $referenceName

    return $inputdataset
}

function Get-ForEachPipeline {
    param (
        [object]$service,
        [object]$pipeline
    )
    $pipeline.name = $service.name

    $referenceName = $service.parameters | Where-Object {$_.type -eq "referenceName"}
    $pipeline.properties.activities[0].typeProperties.dataset.referenceName = $referenceName.value
    
    return $pipeline
}

function Get-ForEachTumbleTrigger {
    param (
        [object]$service,
        [object]$trigger
    )

    $trigger.name = $service.name

    $startTime = $service.parameters | Where-Object {$_.type -eq "startTime"}
    $trigger.properties.typeProperties.startTime = $startTime.value

    $interval = $service.parameters | Where-Object {$_.type -eq "interval"}
    $trigger.properties.typeProperties.interval = $interval.value

    $pipelineName = $service.parameters | Where-Object {$_.type -eq "pipelineName"}
    $trigger.properties.pipeline.pipelineReference.referenceName = $pipelineName.value

    $outputFolderPath = $service.parameters | Where-Object {$_.type -eq "outputFolderPath"}
    $trigger.properties.pipeline.parameters.outputFolderPath = $outputFolderPath.value

    $inputFolderPath = $service.parameters | Where-Object {$_.type -eq "inputFolderPath"}
    $trigger.properties.pipeline.parameters.inputFolderPath = $inputFolderPath.value

    $inputFileName = $service.parameters | Where-Object {$_.type -eq "inputFileName"}
    $trigger.properties.pipeline.parameters.inputFileName = $inputFileName.value


    return $trigger
}

function New-Resource {
    param (
        [object]$resource
    )
    
    $dataFactoryResoureGroupName = Get-ValueFromResource -resourceType $resource.datafactoryResourceGroup.ref.resourceType `
        -typeFilter $resource.datafactoryResourceGroup.ref.type `
        -property $resource.datafactoryResourceGroup.ref.property
    $dataFactoryName = Get-ValueFromResource -resourceType $resource.dataFactory.ref.resourceType `
        -typeFilter $resource.dataFactory.ref.type `
        -property $resource.dataFactory.ref.property
    $resource.datafactoryResourceGroup.name = $dataFactoryResoureGroupName
    $resource.datafactory.name = $dataFactoryName

    foreach ($innerResource in $resource.resources) {
        foreach ($service in $innerResource.linkedservices) {
            Write-Verbose "Processing linked service $($service.templateFile)"
            $sourcePath = "$PSScriptRoot\..\templates\$($service.templateFile)"
            Write-Verbose "Getting linked service configuration template from $sourcePath"
            $linkedService = Get-Content -Path $sourcePath -Raw | ConvertFrom-JSON
            if ($service.type -eq "salesforce") {
                $linkedService = Get-SalesforceLinkedService -service $service -linkedService $linkedService
            }
            else {
                throw "the type $($service.type) of linked service is not supported yet"
            }
            Write-OutputFile -resource $resource -outputObj $linkedService -filePath $service.templateFile
        }
        foreach ($service in $innerResource.inputdatasets) {
            Write-Verbose "Processing input dataset $($service.templateFile)"
            $sourcePath = "$PSScriptRoot\..\templates\$($service.templateFile)"
            Write-Verbose "Getting input dataset configuration template from $sourcePath"
            $inputdataset = Get-Content -Path $sourcePath -Raw | ConvertFrom-JSON
            if ($service.type -eq "salesforce") {
                $inputdataset = Get-SalesforceInputDataSet -service $service -inputdataset $inputdataset
            }
            elseif ($service.type -eq "foreach") {
                $inputdataset = Get-ForEachInputDataSet -service $service -inputdataset $inputdataset
            }            
            else {
                throw "the type $($service.type) of input dataset is not supported yet"
            }
            Write-OutputFile -resource $resource -outputObj $inputdataset -filePath $service.templateFile
        }
        foreach ($service in $innerResource.outputdatasets) {
            Write-Verbose "Processing output dataset $($service.templateFile)"
            $sourcePath = "$PSScriptRoot\..\templates\$($service.templateFile)"
            Write-Verbose "Getting output dataset configuration template from $sourcePath"
            $outputdataset = Get-Content -Path $sourcePath -Raw | ConvertFrom-JSON
            if ($service.type -eq "salesforce") {
                $outputdataset = Get-SalesforceOutputDataSet -service $service -outputdataset $outputdataset
            }
            else {
                throw "the type $($service.type) of output dataset is not supported yet"
            }
            Write-OutputFile -resource $resource -outputObj $outputdataset -filePath $service.templateFile
        }
        foreach ($service in $innerResource.pipelines) {
            Write-Verbose "Processing pipeline $($service.templateFile)"
            $sourcePath = "$PSScriptRoot\..\templates\$($service.templateFile)"
            Write-Verbose "Getting pipeline configuration template from $sourcePath"
            $pipeline = Get-Content -Path $sourcePath -Raw | ConvertFrom-JSON
            if ($service.type -eq "salesforce") {
                $pipeline = Get-SalesforcePipeline -service $service -pipeline $pipeline
            }
            elseif ($service.type -eq "foreach") {
                $pipeline = Get-ForEachPipeline -service $service -pipeline $pipeline
            }
            else {
                throw "the type $($service.type) of pipeline is not supported yet"
            }
            Write-OutputFile -resource $resource -outputObj $pipeline -filePath $service.templateFile

        }
        foreach ($service in $innerResource.triggers) {
            Write-Verbose "Processing trigger $($service.templateFile)"
            $sourcePath = "$PSScriptRoot\..\templates\$($service.templateFile)"
            Write-Verbose "Getting linked service configuration template from $sourcePath"
            $trigger = Get-Content -Path $sourcePath -Raw | ConvertFrom-JSON
            if ($service.type -eq "salesforce") {
                $trigger = Get-SalesForceTumbleTrigger -service $service -trigger $trigger
            }
            elseif ($service.type -eq "foreach") {
                $trigger = Get-ForEachTumbleTrigger -service $service -trigger $trigger
            }
            else {
                throw "the type $($service.type) of tigger is not supported yet"
            }
            Write-OutputFile -resource $resource -outputObj $trigger -filePath $service.templateFile
        }
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
