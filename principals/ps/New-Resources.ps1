param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function New-PrincipalParameters {
    param(
        [object]$parameters
    )
    $principals = $parameters.parameters.resources.value | Where-Object {$_.type -eq "principal"}
    foreach ($principal in $principals) {
        Write-Verbose "Processing principal $($principal.application.name)"
        $principal.application.name = Get-FormatedText -strFormat $principal.application.name
        $principal.application.uri = Get-FormatedText -strFormat $principal.application.uri
        if ($principal.application.clientCertificateName -ne $null) {
            $principal.application.clientCertificateName = Get-FormatedText -strFormat $principal.application.clientCertificateName
        }
        $principal.servicePrincipal.name = Get-FormatedText -strFormat $principal.servicePrincipal.name

        $principal.application.passwordSecretName = "$($principal.application.name)-password"
        $principal.application.certificateSecretName = "$($principal.application.name)-certificate"
        $principal.application.certificatePasswordSecretName = "$($principal.application.name)-certificate-password"
    }
}

function New-ApplicationParameters {
    New-PrincipalParameters -parameters $parameters
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$parameterFileName = "principals.parameters.json"

& "$commonPSFolder\Invoke-NewProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType "principals" `
    -parameterFileName $parameterFileName `
    -procToRun {New-ApplicationParameters}
