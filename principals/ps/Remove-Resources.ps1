param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-Principal {
    param (
        [string]$applicationName
    )
        
    $servicePrincipal = Get-AzureRmADServicePrincipal -SearchString $applicationName  -ErrorAction SilentlyContinue
    if ($servicePrincipal -ne $null) {
        Write-Verbose "Removing Azure AD Service Principal"
        $servicePrincipal = Remove-AzureRmADServicePrincipal -ObjectId $servicePrincipal.Id -Force
        Write-Verbose "Removed Azure AD Service Principal"
    }
    else {
        Write-Verbose "Azure AD Service Principal does not exist"
    }

    $application = Get-AzureRmADApplication -DisplayNameStartWith $applicationName -ErrorAction SilentlyContinue
    if ($application -ne $null) {
        Write-Verbose "Removing Azure AD Application"
        $application = Remove-AzureRmADApplication -ObjectId $application.ObjectId -Force
        Write-Verbose "Removed Azure AD Application"
    }
    else {
        Write-Verbose "Azure AD Application does not exist"
    }
}

function Remove-Principals {
    $principals = $parameters.parameters.resources.value | Where-Object {$_.type -eq "principal"} 
    foreach ($principal in $principals) {
        Remove-Principal -applicationName $principal.application.name
    }
}

$parameterFileName = "principals.parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-RemoveProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Remove-Principals}