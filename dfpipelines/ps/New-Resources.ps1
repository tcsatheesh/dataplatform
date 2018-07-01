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

function Set-DataFactoryServiceFile {
    param (
        [object]$resource,
        [object]$service,
        [string]$filePath
    )
    $sourcePath = "$PSScriptRoot\..\templates\$filePath"
    Write-Verbose "Getting linked service configuration template from $sourcePath"
    $outputObj = Get-Content -Path $sourcePath -Raw | ConvertFrom-JSON
    foreach ($parameter in $service.parameters) {
        if ($parameter.type -eq "referenceName") {
            $value = Get-ValueFromResource -resourceType $parameter.ref.resourceType `
                    -typeFilter $parameter.ref.type `
                    -property $parameter.ref.property
            $outputObj.properties.linkedServiceName.referenceName = $value
        }
        else {
            throw "this parameter type $type is not supported currently"
        }
    }
    Write-OutputFile -resource $resource -outputObj $outputObj -filePath $filePath
}

function Get-SalesforceLinkedService {
    param (
        [object]$resource,
        [object]$linkedService
    )

    $keyVaultName = Get-ValueFromResourceRef -parameters $resource.parameters -type "keyvault"
    $usernameSecretName = Get-ValueFromResourceRef -parameters $resource.parameters -type "usernameSecretName"
    $passwordSecretName = Get-ValueFromResourceRef -parameters $resource.parameters -type "passwordSecretName"
    $securityTokenSecretName = Get-ValueFromResourceRef -parameters $resource.parameters -type "securityTokenSecretName"

    $linkedService.properties.typeProperties.username.secretName = $usernameSecretName     
    $linkedService.properties.typeProperties.username.store.referenceName = $keyVaultName
    $linkedService.properties.typeProperties.password.store.referenceName = $keyVaultName
    $linkedService.properties.typeProperties.password.secretName = $passwordSecretName
    $linkedService.properties.typeProperties.securityToken.store.referenceName = $keyVaultName
    $linkedService.properties.typeProperties.securityToken.secretName = $securityTokenSecretName
    
    return $linkedService
}

function Get-TumbleTrigger {
    param (
        [object]$resource,
        [object]$trigger
    )
    $startTime = $resource.parameters | Where-Object {$_.type -eq "startTime"}
    $trigger.properties.typeProperties.startTime = $startTime.value

    $pipelineName = $resource.parameters | Where-Object {$_.type -eq "pipelineName"}
    $trigger.properties.pipeline.pipelineReference.referenceName = $pipelineName.value

    $inputFilePath = $resource.parameters | Where-Object {$_.type -eq "inputFilePath"}
    $trigger.properties.pipeline.parameters.inputFilePath = $inputFilePath.value

    $outputFilePath = $resource.parameters | Where-Object {$_.type -eq "outputFilePath"}
    $trigger.properties.pipeline.parameters.outputFilePath = $outputFilePath.value

    $query = $resource.parameters | Where-Object {$_.type -eq "query"}
    $trigger.properties.pipeline.parameters.query = $query.value

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
                $linkedService = Get-SalesforceLinkedService -resource $service -linkedService $linkedService
            }
            else {
                throw "the type $type of linked service is not supported yet"
            }
            Write-OutputFile -resource $resource -outputObj $linkedService -filePath $service.templateFile
        }
        foreach ($service in $innerResource.datasets) {
            Write-Verbose "Processing dataset $($service.templateFile)"
            Set-DataFactoryServiceFile -resource $resource -service $service -filePath $service.templateFile
        }
        foreach ($service in $innerResource.pipelines) {
            Write-Verbose "Processing pipeline $($service.templateFile)"
            Set-DataFactoryServiceFile -resource $resource -service $service -filePath $service.templateFile
        }
        foreach ($service in $innerResource.triggers) {
            Write-Verbose "Processing trigger $($service.templateFile)"
            $sourcePath = "$PSScriptRoot\..\templates\$($service.templateFile)"
            Write-Verbose "Getting linked service configuration template from $sourcePath"
            $trigger = Get-Content -Path $sourcePath -Raw | ConvertFrom-JSON
            if ($trigger.properties.type -eq "TumblingWindowTrigger") {
                $trigger = Get-TumbleTrigger -resource $service -trigger $trigger
            }
            else {
                throw "only tumble window is supported for now"
            }
            Write-OutputFile -resource $resource -outputObj $trigger -filePath $service.templateFile
        }
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
