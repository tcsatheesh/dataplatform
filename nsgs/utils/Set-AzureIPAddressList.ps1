param(
    [string]$resourceGroupName,
    [string]$nsgName,
    [string]$nsgRuleName = "allow_north_europe_range",
    [string]$regionofInterest = "europenorth",
    [string]$protocol = "tcp",
    [string]$access = "Allow",
    [string]$direction = "Outbound",
    [string]$sourcePortRange = "*",
    [string]$sourceAddressPrefix = "*",
    [string]$destinationPortRange = "443,1433",
    [string]$priority = 100
)

$outputFilePath = New-TemporaryFile # "$PSScriptRoot\\azurepublicipaddressrange.xml"
Write-Verbose "XML File Path is $outputFilePath"
Write-Verbose "File not downloaded. Downloading..."
$url = 'https://www.microsoft.com/en-gb/download/confirmation.aspx?id=41653' 
$response = (Invoke-WebRequest -UseBasicParsing -Uri $url )
$xmlurl = (($response.Links | Where-Object { $_.href -like "*PublicIP*xml" }).href)[0]
Write-Verbose "Azure IP Address XML file URL is $xmlurl"
Invoke-WebRequest -UseBasicParsing -Uri $xmlurl -OutFile $outputFilePath
Write-Verbose "File downloaded."

$dpr = New-Object "System.Collections.Generic.List[string]"
foreach ($pr in $destinationPortRange.Split(",")) {
    $dpr.Add($pr)
    Write-Verbose "Added $pr"
}

$iprange = [xml] (Get-Content $outputFilePath)

$selectedIPRange = $iprange.AzurePublicIpAddresses.Region | Where-Object { $_.Name -eq $regionofInterest }

$addressRange = $selectedIPRange.IpRange.Subnet
#Write-Verbose "Address Range $addressRange"

$nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $nsgName
if ($null -eq $nsg) {
    Write-Error "NSG Rule $nsgRuleName not found in resource group $resourceGroupName"
}
else {
    $ruleConfig = Get-AzureRmNetworkSecurityRuleConfig -Name $nsgRuleName -NetworkSecurityGroup $nsg -ErrorAction SilentlyContinue
    if ($null -eq $ruleConfig) {
        Write-Verbose "Rule $nsgRuleName does not exist. Creating..."
        $null = Add-AzureRmNetworkSecurityRuleConfig -Name $nsgRuleName -NetworkSecurityGroup $nsg -DestinationAddressPrefix $addressRange `
            -Protocol $protocol -Access $access -Direction $direction `
            -SourcePortRange $sourcePortRange -SourceAddressPrefix $sourceAddressPrefix `
            -DestinationPortRange $destinationPortRange -Priority $priority
    }
    else {
        Write-Verbose "Rule $nsgRuleName already exists. Updating..."
        $null = Set-AzureRmNetworkSecurityRuleConfig -Name $nsgRuleName -NetworkSecurityGroup $nsg -DestinationAddressPrefix $addressRange `
        -Protocol $protocol -Access $access -Direction $direction `
        -SourcePortRange $sourcePortRange -SourceAddressPrefix $sourceAddressPrefix `
        -DestinationPortRange $dpr -Priority $priority
    }        
    Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nsg
}
