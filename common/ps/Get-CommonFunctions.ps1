function Get-ValueFromResource {
    param(
        [string]$resourceType,
        [string]$property,
        [string]$typeFilter,
        [string]$subtypeFilter
    )
    
    $parameters = Get-ResourceParameters -parameterFileName "$resourceType.parameters.json"
    
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

function Get-SubnetID {
    param (
        [object]$subnetRef
    )
    $VNetName = Get-ValueFromResource -resourceType $subnetRef.resourceType `
        -property $subnetRef.property -typeFilter $subnetRef.typeFilter
    
    $vnet = Get-AzureRmVirtualNetwork | Where-Object {$_.Name -eq $VnetName}
    $subnet = $vnet.Subnets | Where-Object {$_.Name -eq $subnetRef.subnetName}
    return $subnet.Id
}

function Get-ParentProjectParameterFilePath {
    param
    (
        [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
        [String]$projectsParameterFullFilePath,
        [Parameter(Mandatory = $True, HelpMessage = 'The .parameters.json file.')]
        [String]$parameterFileName
    )
    $projectParameters = Get-Content -Path $projectsParameterFullFilePath -Raw | ConvertFrom-JSON
    $envType = $projectParameters.parameters.resources.value | Where-Object {$_.type -eq "envType"}
    Write-Verbose "Env type is $envType"
    $currentType = $projectParameters.parameters.resources.value | Where-Object {$_.type -eq $envType.value}
    Write-Verbose "Current type is $currentType"
    if ($currentType.parent -ne $null) {
        Write-Verbose "This is a child project. Parent is $($currentType.parent)"
        $projectFolder = (Get-Item -Path $projectsParameterFile).FullName
        Write-Verbose "1. Project Folder is $projectFolder"
        $projectFolder = (Get-Item -Path $projectFolder).DirectoryName
        Write-Verbose "2. Project Folder is $projectFolder"                
        $parentProjectFolder = "$projectFolder\..\$($currentType.parent)"
        Write-Verbose "1. Project Parent Folder is $parentProjectFolder"
        $parentProjectFolder = (Get-Item -Path $parentProjectFolder).FullName
        Write-Verbose "2. Project Parent Folder is $parentProjectFolder"
        $parameterFullPath = "$parentProjectFolder\$parameterFileName"
        Write-Verbose "3. Project Parent filepath is $parameterFullPath"
        if (-not (Test-Path -Path $parameterFullPath)) {
            Write-Verbose "Parameter file $parameterFileName not found. Check if this is a child project"
            $lclProjectsParameterFullFilePath = "$parentProjectFolder\projects.parameters.json"
            $parameterFullPath = Get-ParentProjectParameterFilePath -projectsParameterFullFilePath $lclProjectsParameterFullFilePath -parameterFileName $parameterFileName
            if ($parameterFullPath -eq $null) {
                throw "Project parameter file not found in $parameterFullPath"
            }
        }    
        return $parameterFullPath
    }
    else {
        return $null
    }
}

function Get-ResourceParameters {
    param
    (
        [Parameter(Mandatory = $True, HelpMessage = 'The .parameters.json file.')]
        [String]$parameterFileName
    )

    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $projectsParameterFullFilePath = "$projectFolder\projects.parameters.json"
    $parameterFullPath = "$projectFolder\$parameterFileName"
    if (-not (Test-Path -Path $parameterFullPath)) {
        Write-Verbose "Parameter file $parameterFileName not found. Check if this is a child project"
        $parameterFullPath = Get-ParentProjectParameterFilePath -projectsParameterFullFilePath $projectsParameterFullFilePath -parameterFileName $parameterFileName
        if ($parameterFullPath -eq $null) {
            throw "Project parameter file not found in $parameterFullPath"
        }
    }
    $parameterFullPath = (Get-Item -Path $parameterFullPath).FullName    
    $parameters = Get-Content -Path $parameterFullPath -Raw | ConvertFrom-JSON
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
function Get-ApplicationParameter {
    param (
        [string]$type
    )
    $applicationsParameterFileName = "principals.parameters.json"
    $applicationsParameters = Get-ResourceParameters -parameterFileName $applicationsParameterFileName -ErrorAction SilentlyContinue
    if ($applicationsParameters -ne $null) {
        $principal = $applicationsParameters.parameters.resources.value | Where-Object {$_.type -eq $type}
        return $principal
    }
}

function Get-ADGroupFromType {
    param (
        [string]$type
    )
    $adgroupsParameterFileName = "adgroups.parameters.json"
    $adgroupsParameters = Get-ResourceParameters -parameterFileName $adgroupsParameterFileName -ErrorAction SilentlyContinue
    if ($adgroupsParameters -ne $null) {
        $adgroup = $adgroupsParameters.parameters.resources.value | Where-Object { $_.type -eq $type } 
        return $adgroup
    }
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

function Get-ProjectParameter {
    param (
        [string]$type
    )
    $parameters = Get-Content -Path (Get-Item -Path $projectsParameterFile).FullName -Raw | ConvertFrom-Json
    $parameter = $parameters.parameters.resources.value | Where-Object {$_.type -eq $type}
    if ($parameter -eq $null) {
        throw "You are missing the vsts account information in the projects.parameter.json"
    }
    return $parameter
}

function Update-ProjectParameters {
    param
    (
        [Parameter(Mandatory = $True, HelpMessage = 'The parameters object.')]
        [object]$parameters,
    
        [Parameter(Mandatory = $True, HelpMessage = 'The name of the parameter file.')]
        [string]$parameterFileName
    )
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $projectParameterFullPath = "$projectFolder\$parameterFileName"
    $parameters | ConvertTo-JSON -Depth 10 | Out-File -filepath $projectParameterFullPath -Force -Encoding utf8
}

function Get-SubscriptionId {    
    $parameterFileName = "projects.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName

    $subscriptionId = ($parameters.parameters.resources.value | Where-Object {$_.type -eq "subscription"}).id
    return $subscriptionId
}

function Set-Subscription {
    $subscriptionId = Get-SubscriptionId
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

function Copy-TemplateFile {
    param(
        [string]$resourceType,
        [string]$templateFileName
    )
    $sourcePath = (Get-Item -Path "$PSScriptRoot\..\..\$resourceType\templates\$templateFileName").FullName
    Write-Verbose "Source Path is $sourcePath"
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $destinationPath = "$projectFolder\$resourceType"
    $destinationPath = New-Item -Path $destinationPath -ItemType Directory -Force
    $destinationPath = "$destinationPath\$templateFileName"
    Write-Verbose "Destination Path is $destinationPath"
    Copy-Item -Path $sourcePath -Destination $destinationPath -Force
}

function Set-ParametersToFile { 
    param (
        [string]$resourceType,
        [object]$parameters,
        [string]$parameterFileName
    )
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $destinationPath = "$projectFolder\$resourceType"
    $destinationPath = New-Item -Path $destinationPath -ItemType Directory -Force
    $destinationPath = "$destinationPath\$parameterFileName"
    Write-Verbose "Destination Path is $destinationPath"
    $parameters | ConvertTo-JSON -Depth 10 | Out-File -filepath $destinationPath -Force -Encoding utf8
    Write-Verbose "Project parameter file created at: $destinationPath"
}

function Get-ProjectTemplateFilePath {
    param(
        [string]$resourceType,
        [string]$fileName
    )
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    return (Get-Item -Path "$projectFolder\$resourceType\$fileName").FullName
}

function Get-CreateADGroupsStatus {
    $createADGroups = "createADGroups"
    $parameterFileName = "projects.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    $resource = $parameters.parameters.resources.value | Where-Object {$_.type -eq $createADGroups}
    $createNew = $resource.status
    Write-Verbose "Create status for AD Groups $createNew"
    return $createNew
}