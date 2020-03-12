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
    [Switch]$get,

    [Parameter(Mandatory = $False, HelpMessage = "Delete the trigger")]
    [Switch]$delete
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


function Delete-Trigger {
    param(
        [string]$triggerName
    )
    $tstate = Get-TriggerState -triggerName $triggerName
    if (-not [string]::IsNullOrEmpty($tstate)) {
        $null = Remove-AzureRmDataFactoryV2Trigger -ResourceGroupName $dataFactoryResourceGroupName `
            -DataFactoryName $dataFactoryName -Name $triggerName -Force
    }
}

function Set-Resource {
    param (
        [object]$resource
    )
    $dataFactoryResourceGroupName = Get-ResourceGroupName -resourceGroupTypeRef $resource.resourceGroupTypeRef
    $dataFactoryName = $resource.name
    Write-Verbose "Processing datafactory $dataFactoryName in resource group $dataFactoryResourceGroupName"
    $trigger = Get-AzureRmDataFactoryV2Trigger -ResourceGroupName $dataFactoryResourceGroupName -DataFactoryName $dataFactoryName -Name $nameofTrigger -ErrorAction SilentlyContinue
    if ($null -ne $trigger) {
        Write-Verbose "Processing trigger $nameofTrigger in datafactory $dataFactoryName in resource group $dataFactoryResourceGroupName"
        if ($stop) {
            Stop-Trigger -triggerName $nameofTrigger
        }
        elseif ($start) {
            Start-Trigger -triggerName $nameofTrigger
        }
        elseif ($delete) {
            Stop-Trigger -triggerName $nameofTrigger
            Delete-Trigger -triggerName $nameofTrigger
        }
        else {
            Get-TriggerState -triggerName $nameofTrigger
        }
    }
    else {
        Write-Verbose "Trigger $triggerName not found."
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
