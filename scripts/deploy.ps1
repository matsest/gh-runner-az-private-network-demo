[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $Location = 'northeurope',
    [Parameter()]
    [string]
    $VnetAddressPrefix = '10.0.0.0/16',
    [Parameter()]
    [string]
    $SubnetAddressPrefix = '10.0.1.0/24',
    [Parameter(Mandatory)]
    [string]
    $GitHubDatabaseId
)

$ErrorActionPreference = 'Stop'

Write-Host "Registring GitHub.Network resource provider..."
$null = Register-AzResourceProvider -ProviderNamespace GitHub.Network

# Pre-reqs
Write-Host "Configuring resource group and virtual network..."
$rg = New-AzResourceGroup -Name 'gh-private-runners' -Location $Location -Force
$vnet = Get-AzVirtualNetwork -Name 'gh-private-vnet' -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
if (!$vnet) {
    $vnet = New-AzVirtualNetwork -Name 'gh-private-vnet' -ResourceGroupName $rg.ResourceGroupName -Location $Location -AddressPrefix $VnetAddressPrefix
}

$now = Get-Date -Format 'yyyy-MM-ddTHHmm'

# Deploy template
Write-Host "Deploying template..."
$deploy = New-AzResourceGroupDeployment -Name "gh-private-runners-$now" `
    -ResourceGroupName $rg.ResourceGroupName -TemplateFile "$PSScriptRoot/../bicep/main.bicep" `
    -githubDatabaseId $GitHubDatabaseId `
    -location $Location `
    -existingVnetName $vnet.Name `
    -subnetPrefix $SubnetAddressPrefix

Write-Host "✅ Deployment complete!"

$networkSettings = Get-AzResource -ResourceId $deploy.Outputs.networkSettingsId.value
$networkSettingsId = $networkSettings.Tags['GitHubId']

Write-Host "Network Settings Resource Id:"
Write-Host $networkSettingsId