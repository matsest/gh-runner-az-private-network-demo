[CmdletBinding(DefaultParameterSetName = 'NewVnet')]
param (
    [Parameter(Mandatory)]
    [string]$GitHubOrganizationUserName,
    [Parameter(ParameterSetName = 'NewVnet')]
    [string]$Location = 'northeurope',
    [Parameter(ParameterSetName = 'NewVnet')]
    [string]$VnetAddressPrefix = '10.0.0.0/16',

    [Parameter(ParameterSetName = 'NewVnet')]
    [Parameter(ParameterSetName = 'ExistingVnet')]
    [string]$SubnetAddressPrefix = '10.0.1.0/24',

    [Parameter(ParameterSetName = 'NewVnet')]
    [Parameter(ParameterSetName = 'ExistingVnet')]
    [string]$SubnetName = 'github-runner',
    [Parameter(ParameterSetName = 'ExistingVnet', Mandatory)]
    [Microsoft.Azure.Commands.Network.Models.PSVirtualNetwork]$Vnet
)

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/../pwsh/github.psm1" -Force

Write-Host "`n Deploying GitHub-hosted runners with Azure Private Networking for organization '$GitHubOrganizationUserName'...`n"
$GitHubDatabaseId = Get-GitHubOrganizationDatabaseId -OrganizationUsername $GitHubOrganizationUserName

$Context = Get-AzContext
Write-Host "Using Azure subscription: $($Context.Subscription.Name) in location: $Location"

# MARK: Azure
Write-Host "- Registring GitHub.Network resource provider..."
$provider = Get-AzResourceProvider -ProviderNamespace 'GitHub.Network'
if ($provider.RegistrationState -eq 'Registered') {
    Write-Host "    - Provider already registered!"
} else {
    $null = Register-AzResourceProvider -ProviderNamespace GitHub.Network
}

if ($PSCmdlet.ParameterSetName -eq 'NewVnet') {
    Write-Host "- Configuring resource group and virtual network..."
    $rg = New-AzResourceGroup -Name 'gh-private-runners' -Location $Location -Force
    $Vnet = New-AzVirtualNetwork -Name 'gh-private-vnet' -ResourceGroupName $rg.ResourceGroupName -Location $Location -AddressPrefix $VnetAddressPrefix
} else {
    Write-Host "- Using existing virtual network: $($Vnet.Name)..."
    $rg = Get-AzResourceGroup -Name $Vnet.ResourceGroupName
    $Location = $Vnet.Location
}

$now = Get-Date -Format 'yyyy-MM-ddTHHmm'

# Deploy template
Write-Host "- Deploying Azure subnet configuration..."
$deploy = New-AzResourceGroupDeployment -Name "gh-private-runners-$now" `
    -ResourceGroupName $rg.ResourceGroupName -TemplateFile "$PSScriptRoot/../bicep/main.bicep" `
    -githubDatabaseId $GitHubDatabaseId `
    -location $Location `
    -existingVnetName $vnet.Name `
    -subnetPrefix $SubnetAddressPrefix `
    -subnetName $SubnetName
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
    -Name $vnet.Name `
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
Write-Host "https://github.com/organizations/$GitHubOrganizationUserName/settings/actions/hosted-compute/networking-configurations/$($networkConfiguration.id)"

Write-Host "👉 Url to runner group with runner:"
Write-Host "https://github.com/organizations/$GitHubOrganizationUserName/settings/actions/runner-groups/$($runnerGroup.id)"

$yaml = @"

jobs:
  example-job:
    runs-on:
      group: $($runnerGroup.name)

"@

Write-Host "🚀 Add the following to a GitHub Actions workflow to get started:"
Write-Host $yaml