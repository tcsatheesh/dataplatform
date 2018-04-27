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
        [string]$replyUrl,
        [string]$homepage
    ) 

    $application = Get-AzureRmADApplication -DisplayNameStartWith $applicationName -ErrorAction SilentlyContinue
    if ($application -eq $null) {        
        if ([string]::IsNullOrEmpty($replyUrl) ) {
            Write-Verbose "Creating new Azure AD Application $applicationName"
            $application = New-AzureRmADApplication -DisplayName $applicationName -IdentifierUris $applicationUri
        }
        else {
            Write-Verbose "Creating new Azure AD Application $applicationName with replyurl $replyUrl and homepage $homepage"            
            $application = New-AzureRmADApplication -DisplayName $applicationName -IdentifierUris $applicationUri `
                -ReplyUrls $replyUrl -HomePage $homepage
        }
        Write-Verbose "Created new Azure AD Application"
    }
    else {
        Write-Verbose "Azure AD Application $applicationName exists"
    }
    $applicationId = $application.ApplicationId
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

function Set-Principal {
    param (
        [object]$principal
    )

    $principalIds = Set-Application -applicationName $principal.application.name `
        -applicationUri $principal.application.uri `
        -replyUrl $principal.application.replyUrl `
        -homepage $principal.application.homepage

    $principal.application.clientId = $principalIds.applicationId
    $principal.servicePrincipal.name = $principal.application.name
    $principal.servicePrincipal.id = $principalIds.servicePrincipalId
}

function Set-Principals {
    $principals = $parameters.parameters.resources.value | Where-Object {$_.type -eq "principal"} 
    foreach ($principal in $principals) {
        Set-Principal -principal $principal
    }    
}

$parameterFileName = "principals.parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-SetProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Set-Principals}