param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function New-Resource {
    param (
        [object]$resource
    )
    $resource.application.name = Get-FormatedText -strFormat $resource.application.name
    $resource.application.uri = Get-FormatedText -strFormat $resource.application.uri
    $replyUrls = @()
    foreach ($replyUrl in $resource.application.replyUrls) {
         $replyUrls += Get-FormatedText -strFormat $replyUrl
    }
    if ($null -ne $resource.application.replyUrls) {
        $resource.application.replyUrls = $replyUrls
    }
    if (-not [string]::IsNullOrEmpty($resource.application.homepage)) {
        $resource.application.homepage = Get-FormatedText -strFormat $resource.application.homepage    
    }

    $resource.servicePrincipal.name = Get-FormatedText -strFormat $resource.servicePrincipal.name

    $resource.application.passwordSecretName = "$($resource.application.name)-password"
    $resource.application.certificateSecretName = "$($resource.application.name)-certificate"
    $resource.application.certificatePasswordSecretName = "$($resource.application.name)-certificate-password"
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
