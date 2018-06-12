function Get-ValueFromResource {
    param(
        [string]$resourceType,
        [string]$property,
        [string]$typeFilter,
        [string]$subtypeFilter
    )
    
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $itemPath = "$projectFolder\$resourceType.parameters.json"
    $parameters = Get-Content -Path $itemPath -Raw | ConvertFrom-Json
    
    if ([String]::IsNullOrEmpty($subtypeFilter)) {
        $item = $parameters.parameters.resources.value | Where-Object {$_.type -eq $typeFilter}
    }
    else {
        $item = $parameters.parameters.resources.value | `
            Where-Object {$_.type -eq $typeFilter -and $_.subtype -eq $subtypeFilter}
    }
    
    if ($item -eq $null ) {
        throw "1. item cannot be null here for resourceType $resourceType with typeFilter as $typeFilter and subtypeFilter as $subtypeFilter and property as $property"
    }
    $props = $property.Split(".")
    foreach ($prop in $props) {
        $item = $item.$prop
    }
    $val = $item
    if ($item -eq $null ) {
        throw "2. item cannot be null here for resourceType $resourceType with typeFilter as $typeFilter and subtypeFilter as $subtypeFilter and property as $property"
    }
    return $val 
}

function Get-ValueFromResourceRef {
    param (
        [object]$parameters,
        [string]$type
    )
    $parameter = $parameters | Where-Object {$_.type -eq $type}
    $val = Get-ValueFromResource `
        -resourceType $parameter.ref.resourceType `
        -typeFilter $parameter.ref.typeFilter `
        -property $parameter.ref.property `
        -subtypeFilter $parameter.ref.subtypeFilter
    return $val
}

function Get-FormatedText {
    param(
        [string]$strFormat
    )
    $projectParameterFileFullPath = (Get-Item -Path $projectsParameterFile).FullName
    $projectParameters = Get-Content -Path $projectParameterFileFullPath -Raw | ConvertFrom-Json
    function Get-Resource {
        param (
            [string]$type
        )
        $resource = $projectParameters.parameters.resources.value | Where-Object {$_.type -eq $type}
        return $resource.name
    }

    $department = Get-Resource -type "department"
    $projectName = Get-Resource -type "projectName"
    $environment = Get-Resource -type "environment"
    $tenant = Get-Resource -type "tenant"

    $returnValue = $strFormat -f $department, $projectName, $environment, $tenant
    return $returnValue
}

function Get-CurrentIPAddress {
    $url = "https://api.ipify.org?format=json"
    $response = Invoke-RestMethod -UseBasicParsing -Uri $url
    return $response.ip
}

function Get-ResourceParameters {
    param
    (
        [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
        [String]$parameterFileName
    )

    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $projectParameterFullPath = "$projectFolder\$parameterFileName"
    # Write-Verbose "Project Parameter Full Path: $projectParameterFullPath"
    if (-not (Test-Path -Path $projectParameterFullPath)) {
        throw "Project parameter file not found in $projectParameterFullPath"
    }
    $projectParameterFullPath = (Get-Item -Path $projectParameterFullPath).FullName
    # Write-Verbose "Project Parameter Full Path: $projectParameterFullPath"
    $parameters = Get-Content -Path $projectParameterFullPath -Raw | ConvertFrom-JSON
    return $parameters 
}

function Get-TemplateParameters {
    param(
        [Parameter(Mandatory = $True, HelpMessage = 'The name of the parameter file.')]
        [string]$resourceType,

        [Parameter(Mandatory = $True, HelpMessage = 'The name of the parameter file.')]
        [string]$parameterFileName
    )
    $templateParametersFullPath = "$PSScriptRoot\..\..\$resourceType\templates\$parameterFileName"
    $templateParametersFullPath = (Get-Item -Path $templateParametersFullPath).FullName
    # Write-Verbose "Parameters Template Full Path: $templateParametersFullPath"
    $parameters = Get-Content -Path $templateParametersFullPath -Raw | ConvertFrom-JSON
    return $parameters
}

function New-Password {
    param
    ( 
        [int] $numchars = 22,
        [string]$chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#"
    )
    do {
        $bytes = new-object "System.Byte[]" $numchars
        $rnd = new-object System.Security.Cryptography.RNGCryptoServiceProvider
        $rnd.GetBytes($bytes)
        $result = ""
        $repeat = $false
        for ( $i = 0; $i -lt $numchars; $i++ ) {
            $result += $chars[ $bytes[$i] % $chars.Length ]   
        }
        if (-Not $result.Contains("@") -or -Not $result.Contains("#")) {
            $repeat = $true;
        }
        if (-Not ($result -match "[0-9]")) {
            $repeat = $true;
        }
    } while ($repeat)

    $secret = ConvertTo-SecureString -AsPlainText $result -Force
    $props = @{
        securePassword = $secret
        passowrd       = $result
    }

    return $props
}

function Update-ProjectParameters {
    param
    (
        [Parameter(Mandatory = $True, HelpMessage = 'The parameters object.')]
        [object]$parameters,
    
        [Parameter(Mandatory = $True, HelpMessage = 'The name of the parameter file.')]
        [string]$parameterFileName
    )
    # Write-Verbose "Projects Parameter File $projectsParameterFile"
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    # Write-Verbose "Projects Folder $projectFolder"
    $projectParameterFullPath = "$projectFolder\$parameterFileName"
    # Write-Verbose "Project Parameter Full Path: $projectParameterFullPath"
    $parameters | ConvertTo-JSON -Depth 10 | Out-File -filepath $projectParameterFullPath -Force -Encoding utf8
    # Write-Verbose "Project parameter file updated at: $projectParameterFullPath"
}

function Set-Subscription {
    $parameterFileName = "projects.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName

    $subscriptionId = ($parameters.parameters.resources.value | Where-Object {$_.type -eq "subscription"}).id
    $sub = Select-AzureRmSubscription -SubscriptionId $subscriptionId    
}

function Get-KeyVaultName {
    param (
        [string]$keyVaultType
    )
    $parameterFileName = "keyvaults.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    $resource = $parameters.parameters.resources.value | Where-Object {$_.type -eq $keyVaultType}
    $keyVaultName = $resource.name
    return $keyVaultName
}

function Get-ResourceGroupName {
    param(
        [string]$resourceGroupTypeRef
    )
    
    $parameterFileName = "resourcegroups.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    $resourceGroup = $parameters.parameters.resources.value | Where-Object {$_.type -eq $resourceGroupTypeRef}
    Write-Verbose "Returning $($resourceGroup.name) for resourceGroupTypeRef $resourceGroupTypeRef"
    return $resourceGroup.name
}

function Get-ResourcesFromResourceType {
    param (
        [string]$resourceType
    )

    $parameterFileName = "projects.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    
}