[CmdletBinding()]
param (
    [Parameter()]
    [string]$Location = 'northeurope',
    [Parameter()]
    [string]$VnetAddressPrefix = '10.0.0.0/16',
    [Parameter()]
    [string]$SubnetAddressPrefix = '10.0.1.0/24',
    [Parameter(Mandatory)]
    [string]$GitHubOrganizationUserName
)

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/github.psm1" -Force

Write-Host "`n Deploying GitHub-hosted runners with Azure Private Networking for organization '$GitHubOrganizationUserName'...`n"

$Context = Get-AzContext
Write-Host "Using Azure subscription: $($Context.Subscription.Name) in location: $Location"

# MARK: Azure
Write-Host "- Registring GitHub.Network resource provider..."
$null = Register-AzResourceProvider -ProviderNamespace GitHub.Network

# TODO: Add support for inputing a pre-existing vnet and resource group
# Pre-reqs
Write-Host "- Configuring resource group and virtual network..."
$rg = New-AzResourceGroup -Name 'gh-private-runners' -Location $Location -Force
$vnet = Get-AzVirtualNetwork -Name 'gh-private-vnet' -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
if (!$vnet) {
    $vnet = New-AzVirtualNetwork -Name 'gh-private-vnet' -ResourceGroupName $rg.ResourceGroupName -Location $Location -AddressPrefix $VnetAddressPrefix
}

$GitHubDatabaseId = Get-GitHubOrganizationDatabaseId -OrganizationUsername $GitHubOrganizationUserName
$now = Get-Date -Format 'yyyy-MM-ddTHHmm'

# Deploy template
Write-Host "- Deploying Azure subnet configuration..."
$deploy = New-AzResourceGroupDeployment -Name "gh-private-runners-$now" `
    -ResourceGroupName $rg.ResourceGroupName -TemplateFile "$PSScriptRoot/../bicep/main.bicep" `
    -githubDatabaseId $GitHubDatabaseId `
    -location $Location `
    -existingVnetName $vnet.Name `
    -subnetPrefix $SubnetAddressPrefix
Write-Host "    - Configured subnet: $($deploy.Outputs.subnetName.value)!"

$networkSettings = Get-AzResource -ResourceId $deploy.Outputs.networkSettingsId.value
$networkSettingsId = $networkSettings.Tags['GitHubId']
if ([string]::IsNullOrEmpty($networkSettingsId)) {
    Write-Error "Could not determine network settings id!"
}

# MARK: GitHub
# Create hosted compute networking configuration
Write-Host "- Creating GitHub hosted networking configuration..."
$networkConfiguration = New-GitHubHostedComputeNetworkingConfiguration `
    -OrganizationUsername $GitHubOrganizationUserName `
    -NetworkConfigurationName  $vnet.Name `
    -NetworkSettingsId $networkSettingsId
Write-Host "    - Created networking configuration: $($networkConfiguration.name)!"

# Create runner group
Write-Host "- Creating GitHub runner group..."
$runnerGroup = New-GitHubRunnerGroup `
    -OrganizationUsername $GitHubOrganizationUserName `
    -Name $vnet.Name `
    -NetworkConfigurationId $networkConfiguration.id `
    -Visibility 'all'
Write-Host "    - Created runner group: $($runnerGroup.name)!"

# Create runner
Write-Host "- Creating GitHub runner..."
$runnerType = "ubuntu-24.04"
$runner = New-GitHubHostedRunner `
    -OrganizationUsername $GitHubOrganizationUserName `
    -Name "$($vnet.Name)-$runnerType" `
    -RunnerGroupId $runnerGroup.id `
    -MaximumRunners 10 `
    -ImageName $runnerType `
    -Size '2-core'
Write-Host "    - Created runner: $($runner.name)!"

# MARK: Summary
Write-Host "`n ✅ Deployment complete!`n"

Write-Host "👉 Url to hosted compute networking configuration:"
Write-Host "https://github.com/organizations/$GitHubOrganizationUserName/settings/actions/hosted-compute/networking-configurations/$($networkConfiguration.id)"0

Write-Host "👉 Url to runner group with runner:"
Write-Host "https://github.com/organizations/$GitHubOrganizationUserName/settings/actions/runner-groups/$($runnerGroup.id)"

$yaml = @"

jobs:
  example-job:
    runs-on:
      group: $($runnerGroup.name)

"@

Write-Host "🚀 Add the following to a GitHub Actions workfflow to get started:"
Write-Host $yaml