[CmdletBinding(DefaultParameterSetName = 'NewVnet')]
param (
    [Parameter(Mandatory)]
    [string]$GitHubOrganization,
    [Parameter(ParameterSetName = 'NewVnet')]
    [string]$Location = 'northeurope',
    [Parameter(ParameterSetName = 'NewVnet')]
    [string]$VnetAddressPrefix = '10.0.0.0/16',

    [Parameter(ParameterSetName = 'NewVnet')]
    [Parameter(ParameterSetName = 'ExistingVnet')]
    [string]$SubnetAddressPrefix = '10.0.1.0/27',

    [Parameter(ParameterSetName = 'NewVnet')]
    [Parameter(ParameterSetName = 'ExistingVnet')]
    [string]$SubnetName = 'github-runner',
    [Parameter(ParameterSetName = 'ExistingVnet', Mandatory)]
    [object]$Vnet,

    [Parameter(ParameterSetName = 'NewVnet')]
    [Parameter(ParameterSetName = 'ExistingVnet')]
    [switch]$DeployNatGateway = $false,

    [Parameter(ParameterSetName = 'NewVnet')]
    [Parameter(ParameterSetName = 'ExistingVnet')]
    [switch]$DefaultOutBoundAccess = $(!$DeployNatGateway) # Default to true if NAT gateway is not deployed
)

$startTime = Get-Date
Import-Module "$PSScriptRoot/pwsh/github.psm1" -Force
$ErrorActionPreference = 'Stop'

# MARK: Validation
# Validate GitHub permissions
$scopes = gh api -i / | Select-String "X-Oauth-Scopes: " -Raw
if (-not $scopes -match "admin:org" -and -not $scopes -match "write:network_configurations") {
    Write-Error "You need to have 'admin:org' scope to run this script"
}

# Validate Azure permissions
$me = Get-AzAdUser -SignedIn
[array]$roleAssignments = Get-AzRoleAssignment -ObjectId $me.Id
[array]$roles = $roleAssignments.RoleDefinitionName
if (-not($roles -contains 'Owner' -or ($roles -contains 'Contributor' -and $roles -contains 'Network Contributor'))) {
    Write-Error "You need to have 'Owner' role to run this script"
}

# Validate subnet addressp prefix and get max runner count
$maxRunnerCount = Convert-SubnetSizeToRunnersCount -SubnetAddressPrefix $SubnetAddressPrefix

# Get GitHub database id
$GitHubDatabaseId = Get-GitHubOrgDatabaseId -Organzation $GitHubOrganization

Write-Host "`n--------------------------------------------------------------------------------"
Write-Host "`n🚀 Deploying GitHub-hosted runners with Azure Private Networking`n"

Write-Host "Using GitHub organization '$GitHubOrganization'"
$Context = Get-AzContext
Write-Host "Using Azure subscription '$($Context.Subscription.Name)'"

if ($PSCmdlet.ParameterSetName -eq 'NewVnet') {
    Write-Host "Running in sandbox mode - will deploy everything into a new resource group"
} else {
    Write-Host "Running in existing vnet mode - will use existing virtual network"
}
if ($DeployNatGateway) {
    Write-Host "Deploying NAT gateway with public IP 💸"
}

Write-Host "`n--------------------------------------------------------------------------------`n"

# MARK: Azure
Write-Host "- Registring GitHub.Network resource provider..."
$provider = Get-AzResourceProvider -ProviderNamespace 'GitHub.Network'
if ($provider.RegistrationState -eq 'Registered') {
    Write-Host "    - Provider already registered"
} else {
    $null = Register-AzResourceProvider -ProviderNamespace GitHub.Network
    Write-Host "    - Provider registered"
}

if ($PSCmdlet.ParameterSetName -eq 'NewVnet') {
    Write-Host "- Configuring resource group and virtual network..."
    $rg = New-AzResourceGroup -Name 'gh-private-runners' -Location $Location -Force
    $Vnet = Get-AzVirtualNetwork -Name 'gh-private-vnet' -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
    if (!$Vnet) {
        $Vnet = New-AzVirtualNetwork -Name 'gh-private-vnet' -ResourceGroupName $rg.ResourceGroupName -Location $Location -AddressPrefix $VnetAddressPrefix -Force
    }
} else {
    Write-Host "- Using existing virtual network: $($Vnet.Name)..."
    $rg = Get-AzResourceGroup -Name $Vnet.ResourceGroupName
    $Location = $Vnet.Location
}

$now = Get-Date -Format 'yyyy-MM-ddTHHmm'

# Deploy template
Write-Host "- Deploying Azure subnet configuration..."
$deploy = New-AzResourceGroupDeployment -Name "gh-private-runners-$now" `
    -ResourceGroupName $rg.ResourceGroupName `
    -TemplateFile "$PSScriptRoot/bicep/main.bicep" `
    -githubDatabaseId $GitHubDatabaseId `
    -location $Location `
    -existingVnetName $vnet.Name `
    -subnetPrefix $SubnetAddressPrefix `
    -subnetName $SubnetName `
    -deployNatGateway $DeployNatGateway.ToBool() `
    -defaultOutBoundAccess $DefaultOutBoundAccess.ToBool()
Write-Host "    - Configured subnet: $($deploy.Outputs.subnetName.value)"

$networkSettingsId = $deploy.Outputs.networkSettingsGitHubId.value
if ([string]::IsNullOrEmpty($networkSettingsId)) {
    Write-Error "Could not determine network settings id!"
}

# MARK: GitHub
# Create hosted compute networking configuration
Write-Host "- Creating GitHub hosted networking configuration..."
$networkConfiguration = New-GitHubOrgHostedComputeNetworkingConfiguration `
    -Organzation $GitHubOrganization `
    -Name $vnet.Name `
    -NetworkSettingsId $networkSettingsId
Write-Host "    - Created networking configuration: $($networkConfiguration.name)"

# Create runner group
Write-Host "- Creating GitHub runner group..."
$runnerGroup = New-GitHubOrgRunnerGroup `
    -Organzation $GitHubOrganization `
    -Name $vnet.Name `
    -NetworkConfigurationId $networkConfiguration.id `
    -Visibility 'private'
Write-Host "    - Created runner group: $($runnerGroup.name)"

# Create runner
Write-Host "- Creating GitHub runner..."
$runnerType = "Ubuntu 24.04"
$runnerTypeSafeName = ($runnerType -replace ' ', '-').ToLower()
$runner = New-GitHubOrgHostedRunner `
    -Organzation $GitHubOrganization `
    -Name "$($vnet.Name)-$($runnerTypeSafeName)" `
    -RunnerGroupId $runnerGroup.id `
    -MaximumRunners $maxRunnerCount `
    -ImageName $runnerType `
    -Size '2-core'
Write-Host "    - Created runner: $($runner.name)"

# MARK: Summary
Write-Host "`n✅ Deployment complete!`n"
$endTime = Get-Date
$duration = $endTime - $startTime
Write-Host "Deployment for Azure and GitHub completed in: $($duration.Minutes)m$($duration.Seconds)s"
Write-Host "`n--------------------------------------------------------------------------------"

Write-Host "`n🔗 Link to Azure resource group:"
Write-Host "https://portal.azure.com/#@$($Context.Tenant.Id)/resource$($rg.ResourceId)"

Write-Host "`n🔗 Link to GitHub hosted compute networking configuration:"
Write-Host "https://github.com/organizations/$GitHubOrganization/settings/network_configurations/$($networkConfiguration.id)"

Write-Host "`n🔗 Link to GitHub runner group with runner:"
Write-Host "https://github.com/organizations/$GitHubOrganization/settings/actions/runner-groups/$($runnerGroup.id)"

$yaml = @"

.github/workflows/az-private-networking-demo.yml:
---

name: az-private-networking-demo
on: [push]
jobs:
  demo:
    runs-on:
      group: $($runnerGroup.name)
    steps:
      - uses: actions/checkout@v4
      - name: Show local IP address
        run: hostname -I


"@

Write-Host "`n💡 Add the following to a GitHub Actions workflow to get started:"
Write-Host $yaml