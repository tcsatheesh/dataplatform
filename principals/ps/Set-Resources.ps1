param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Set-Application {
    param
    (
        [string]$applicationName,
        [string]$applicationUri,
        [object]$replyUrls,
        [string]$homepage,
        [boolean]$isNative
    ) 

    $application = Get-AzureADApplication -SearchString $applicationName -ErrorAction SilentlyContinue
    if ($application -eq $null) {        
        if ([string]::IsNullOrEmpty($replyUrls) ) {
            Write-Verbose "Creating new Azure AD Application $applicationName"
            if ($isNative) {
                $application = New-AzureADApplication -DisplayName $applicationName -PublicClient $true
            }else {
                $application = New-AzureADApplication -DisplayName $applicationName -IdentifierUris $applicationUri                 
            }
        }
        else {
            Write-Verbose "Creating new Azure AD Application $applicationName with replyurls $replyUrls"
            if ($isNative) {
                $application = New-AzureADApplication -DisplayName $applicationName -ReplyUrls $replyUrls -PublicClient $true
            }else {
                $application = New-AzureADApplication -DisplayName $applicationName -IdentifierUris $applicationUri `
                -ReplyUrls $replyUrls -HomePage $homepage
            }
        }
        Write-Verbose "Created new Azure AD Application"
    }
    else {
        Write-Verbose "Azure AD Application $applicationName exists"
    }
    $applicationId = $application.AppId
    $servicePrincipal = Get-AzureRmADServicePrincipal -SearchString $applicationName  -ErrorAction SilentlyContinue
    if ($servicePrincipal -eq $null) {
        Write-Verbose "Creating new Azure AD Service Principal"
        $servicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $applicationId
        Write-Verbose "Created new Azure AD Service Principal $applicationName"
    }
    else {
        Write-Verbose "Azure AD Service Principal $applicationName exists"
    }
    $servicePrincipalId = $servicePrincipal.Id

    $users = Get-AzureRmADServicePrincipal -SearchString $applicationName
    if ($users.Count -lt 1) {
        throw "$objType $searchString not found in the Azure Active Directory. Check the name."
    }
    if ($users.Count -gt 1) {
        throw "Found too many ${objType}s with name $searchString in the Azure Active Directory. Provide the full name to narrow the search."
    }

    Write-Verbose "Application $applicationName Id:  $applicationId"
    Write-Verbose "ServicePrincipal $applicationName Id: $servicePrincipalId"
    $props = @{ 
        applicationId      = $applicationId
        servicePrincipalId = $servicePrincipalId
    }
    return $props
}

function Set-Resource {
    param (
        [object]$resource
    )

    $isNative = $false
    if ($null -ne $resource.isNativeType) {
        $isNative = $resource.isNativeType
    }
    Write-Verbose "$($resource.application.name) is a native application: $isNative"

    $resourceIds = Set-Application -applicationName $resource.application.name `
        -applicationUri $resource.application.uri `
        -replyUrl $resource.application.replyUrls `
        -homepage $resource.application.homepage `
        -isNative $isNative

    $resource.application.clientId = $resourceIds.applicationId
    $resource.servicePrincipal.name = $resource.application.name
    $resource.servicePrincipal.id = $resourceIds.servicePrincipalId
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName