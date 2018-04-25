$pip = Get-AzureRmPublicIpAddress `
-ResourceGroupName it-iac-d-vms-rg -Name itiacdpip01
$nic = Get-AzureRmNetworkInterface `
-ResourceGroupName it-iac-d-vms-rg -Name itiacdvm01-nic

$nic.IpConfigurations[0].PublicIpAddress = $pip

Set-AzureRmNetworkInterface -NetworkInterface $nic -Verbose

Get-AzureRmPublicIpAddress -ResourceGroupName it-iac-d-vms-rg -Name itiacdpip01

