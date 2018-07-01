param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,

    [Parameter(Mandatory = $False, HelpMessage = "Set to name of the trigger")]
    [string]$nameofTrigger,

    [Parameter(Mandatory = $False, HelpMessage = "Set to start the trigger")]
    [Switch]$start,

    [Parameter(Mandatory = $False, HelpMessage = "Set to stop the trigger")]
    [Switch]$stop,

    [Parameter(Mandatory = $False, HelpMessage = "Set to get the trigger status")]
    [Switch]$get
)

function Get-TriggerState {
    param(
        [string]$triggerName
    )
    $ret = Get-AzureRmDataFactoryV2Trigger -ResourceGroupName $dataFactoryResourceGroupName `
        -DataFactoryName $dataFactoryName -Name $triggerName -ErrorAction SilentlyContinue
    return $ret    
}
function Start-Trigger {
    param(
        [string]$triggerName
    )
    $tstate = Get-TriggerState -triggerName $triggerName
    if (-not [string]::IsNullOrEmpty($tstate)) {
        $null = Start-AzureRmDataFactoryV2Trigger -ResourceGroupName $dataFactoryResourceGroupName `
            -DataFactoryName $dataFactoryName -Name $triggerName -Force
    }
    return Get-TriggerState -triggerName $triggerName
}

function Stop-Trigger {
    param(
        [string]$triggerName
    )
    $tstate = Get-TriggerState -triggerName $triggerName
    if (-not [string]::IsNullOrEmpty($tstate)) {
        $null = Stop-AzureRmDataFactoryV2Trigger -ResourceGroupName $dataFactoryResourceGroupName `
            -DataFactoryName $dataFactoryName -Name $triggerName -Force
    }
    return Get-TriggerState -triggerName $triggerName
}

function Set-Resource {
    param (
        [object]$resource
    )
    $dataFactoryResourceGroupName = $resource.datafactoryResourceGroup.name
    $dataFactoryName = $resource.datafactory.name
    $triggerName = $resource.resources.triggers[0].name
    if ([string]::IsNullOrEmpty($nameofTrigger) -or ($triggerName -eq $nameofTrigger)) {
        Write-Verbose "Processing trigger $triggerName in datafactory $dataFactoryName in resource group $dataFactoryResourceGroupName"
        if ($stop) {
            Stop-Trigger -triggerName $triggerName
        }
        elseif ($start) {
            Start-Trigger -triggerName $triggerName
        }
        else {
            Get-TriggerState -triggerName $triggerName
        }
    }else {
        Write-Verbose "Skipping trigger execution for $triggerName"
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
