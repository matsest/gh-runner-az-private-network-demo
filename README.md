# Azure Private Networking for GitHub-hosted Runners Demo

Learning to set up Azure Private Networking for GitHub-hosted runners. Based on [this guide](https://docs.github.com/en/organizations/managing-organization-settings/configuring-private-networking-for-github-hosted-runners-in-your-organization) a full end-to-end automated deployement using PowerShell, Bicep and GitHub CLI.

Why? You can use GitHub-hosted runners in an Azure VNET to connect privately to other resources. This enables you to use GitHub-managed infrastructure for CI/CD while providing you with full control over the networking policies of your runners. See more details in [the documentation](#official-documentation).

> [!TIP]
> I am currently re-working this demo with support for [new GitHub API's allowing for full end-to-end automated deployment](https://github.blog/changelog/2025-01-29-actions-github-hosted-larger-runner-network-configuration-rest-apis-ga/). You can check out the previous (still functional but not end-to-end automated!) version see [v1 here](https://github.com/matsest/gh-runner-az-private-network-demo/tree/v1). (Run `git checkout v1` after cloning.)

## Pre-requisites

- An Azure subscription with **Contributor** and **Network Contributor** permissions (least privilege) or **Owner** permissions
- An **Enterprise Cloud GitHub organization** with **organization Owner role** (required to run operations via GH CLI with Oauth scopes)
  - TODO: Identify if lesser-privileged approach is supported on required APIs using GitHub Apps or fine-grained token (awaiting [discussion](https://github.com/orgs/community/discussions/149651#discussioncomment-12373322))
- [GitHub CLI](https://cli.github.com/) (tested with 2.67)
- PowerShell 7.x with [Azure PowerShell modules](https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell) (tested with Az.Resources 7.8.1)
- [Azure Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) (tested with 0.33.93)

Note that there is limited support for Azure regions with Azure Private Networking. See supported Azure regions [here](https://docs.github.com/en/organizations/managing-organization-settings/about-azure-private-networking-for-github-hosted-runners-in-your-organization#about-supported-regions).

## Usage

1. [Authenticate with GitHub CLI](https://cli.github.com/manual/gh_auth_login) by running:

``` powershell
gh auth login -s admin:org
```

2. [Authenticate with Azure PowerShell](https://learn.microsoft.com/en-us/powershell/azure/authenticate-azureps) by running:

```powershell
Connect-AzAccount # Login
Set-AzContext -Subscription <subscription name or id>
```

3. Deploy

> [!WARNING]
> Currently outdated - will be updated for the v2 version


**Option 1: Sandbox deployment**: Run the following deployment script to create a new resource group, a new virtual network and configure a new subnet to be set up for private networking:

```powershell
./scripts/deploy.ps1 -GitHubDatabaseId <databaseId>

# Output
Registring GitHub.Network resource provider...
Configuring resource group and virtual network...
Deploying template...
✅ Deployment complete!
Network Settings Resource Id:
<network settings resource id>
```

:point_right: Copy the `Network Settings Resource Id` value for the next step.

**Option 2: Deploy to existing vnet**: If you want to set up a new subnet in an existing virtual network you can deploy the [`main.bicep`](./bicep/main.bicep) and provide the necessary parameters by editing the [`main.bicepparam`](./bicep/main.bicepparam) file, and then running the following command:

```powershell
$resourceGroupName = "<existing resource group name>"

$deploy = New-AzResourceGroupDeployment -Name "gh-private-runners-$now" `
    -ResourceGroupName $resourceGroupName -TemplateFile './bicep/main.bicep' `
    -TemplateParameterFile "./bicep/main.bicepparam"

$networkSettings = Get-AzResource -ResourceId $deploy.Outputs.networkSettingsId.value

Write-Host "Network Settings Resource Id:"
Write-Host $networkSettings.Tags['GitHubId']

```

:warning: Note that if you are deploying into an existing vnet with a default route to a firewall that filters traffic (e.g. Azure Firewall) you will need to whitelist [these URL's](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#communication-between-self-hosted-runners-and-github) to allow traffic from the runner to GitHub. In that case you kan simplify the outbound NSG-rules to allow traffic to 'Internet' and handle the granular filtering in firewall rules.

:point_right: Copy the `Network Settings Resource Id` value for the next step.

4. Use the new privately networked GitHub-hosted runner!

Learn more about managing access to runners [here](https://docs.github.com/en/enterprise-cloud@latest/actions/using-github-hosted-runners/using-larger-runners/controlling-access-to-larger-runners).

## Clean-up

### GitHub

Done via GitHub.com:

1. [Remove the runner](https://docs.github.com/en/enterprise-cloud@latest/actions/hosting-your-own-runners/managing-self-hosted-runners/removing-self-hosted-runners)
1. [Delete the runner group](https://docs.github.com/en/enterprise-cloud@latest/actions/hosting-your-own-runners/managing-self-hosted-runners/managing-access-to-self-hosted-runners-using-groups#removing-a-self-hosted-runner-group)
2. [Delete the hosted networking configuration](https://docs.github.com/en/organizations/managing-organization-settings/configuring-private-networking-for-github-hosted-runners-in-your-organization#deleting-a-subnet)

### Azure

<details>

#### Full deploy option

```powershell
# Remove the resource group with all resources
Remove-AzResourceGroup -Name $ResourceGroupName
```

#### Existing vnet deploy option:

```powershell
$resourceGroupName = <name>
$vnetName = <name>
$subnetName = <name>
$nsgName = <name>
$networkSettingsName = <name>

# Delete subnet
$vnet = Get-AzVirtualNetwork $vnetName -ResourceGroupName $resourceGroupName
Remove-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet | Set-AzVirtualNetwork

# Delete NSG
Remove-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName

# Delete network settings
Remove-AzResource -Name $networkSettingsName `
  -ResourceType 'GitHub.Network/networkSettings' `
  -ResourceGroupName $resourceGroupName
  -ApiVersion '2024-04-02'
```

</details>

## Learn more

### Cost

There will be a minimal Azure-related cost for network traffic depending on your setup, but the main cost of these runners will be the billing for the runners which is listed [here](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions#per-minute-rates-for-x64-powered-larger-runners). Billing is only counted when workflows are running - no idle cost for this solution.

Note that included GitHub Actions minutes for GitHub Enterprise Cloud does **not** apply to larger runners, so all usage will be billed per-minute according to the rates linked above.

Examples:
- One 2-core Linux runner running a 3 minute job 10 times a day: $0.008/min * 3 min * 10 = $0.24 per day
- One 4-core Linux runner running a 5 minute job 10 times a day: $0.016/min * 5 min * 10 = $0.80 per day
- Total of 50,000 minutes on 2-core Linux runners per month: $0.008/min * 50,000 = $400 per month ($12.9 per day)

### Subnet size and runner concurrency

Based on [GitHub documentation](https://docs.github.com/en/enterprise-cloud@latest/admin/configuring-settings/configuring-private-networking-for-hosted-compute-products/configuring-private-networking-for-github-hosted-runners-in-your-enterprise#prerequisites) it's recommended to add a 30% buffer to the maximum job concurrency you anticipate. This needs to be taken into account when choosing the subnet size (Azure) and the maximum count of runners (GitHub) in the setup. Note that Azure reserves [five of the IP addresses](https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/private-ip-addresses#allocation-method) in a given subnet.

The relationship between a subnet address prefix and maximum number of runners it can hold can be calucalted with the `Convert-SubnetSizeToRunnersCount` function which is used in the script to automatically resolve the count of runners to allow for.

```powershell
Convert-SubnetSizeToRunnersCount "10.0.0.0/24" -Verbose
VERBOSE: Number of usable IPs: 251
VERBOSE: Maximum number of runners: 193
193


Convert-SubnetSizeToRunnersCount "10.0.0.0/24" -Verbose
VERBOSE: Number of usable IPs: 251
VERBOSE: Maximum number of runners: 193
193
```

Example values for common subnet sizes (/28 is the smallest useful subnet):

| Subnet size | IP addresses | Usable IP addresses | Max recommended # of runners |
|-------------|--------------|---------------------|------------------------------|
| /28         | 16           | 11                  | 8                            |
| /27         | 32           | 27                  | 20                           |
| /26         | 64           | 59                  | 45                           |
| /25         | 128          | 123                 | 94                           |
| /24         | 256          | 251                 | 193                          |
| /23         | 512          | 507                 | 390                          |

### Static IP not supported

A static public IP from GitHub is [not supported](https://docs.github.com/en/enterprise-cloud@latest/admin/configuring-settings/configuring-private-networking-for-hosted-compute-products/about-azure-private-networking-for-github-hosted-runners-in-your-enterprise#about-using-larger-runners-with-azure-vnet) for privately networked runners. To gain a static egress IP for internet-bound traffic you will need to use an Azure Firewall, a NAT Gateway or a Load Balancer. Read more about Azure outbound connectivity methods [here](https://learn.microsoft.com/en-us/azure/load-balancer/load-balancer-outbound-connections#scenarios).

Please note that default outbound access will [not be supported](https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/default-outbound-access) for new Azure subnets after September 30, 2025.

### Other options

If you are considering running runners for GitHub Actions in your own Azure private networking, and this scenario does not suit you, you can also consider:

- Running self-hosted runners on [Azure Container App Jobs](https://learn.microsoft.com/en-us/azure/container-apps/tutorial-ci-cd-runners-jobs?tabs=azure-powershell&pivots=container-apps-jobs-self-hosted-ci-cd-github-actions) (simple and cost-effective solution)
- Running self-hosted runners on [whatever compute and infrastructure you like](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners) (can be a hassle..)

### Official documentation

- [About networking for hosted compute products in your organization](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/about-networking-for-hosted-compute-products-in-your-organization)

- [About Azure private networking for GitHub-hosted runners in your organization](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/about-azure-private-networking-for-github-hosted-runners-in-your-organization)

- [Configuring private networking for GitHub-hosted runners in your organization](https://docs.github.com/en/enterprise-cloud@latest/organizations/managing-organization-settings/configuring-private-networking-for-github-hosted-runners-in-your-organization)

- [Troubleshoot Azure Private Network Configurations](https://docs.github.com/en/enterprise-cloud@latest/admin/configuring-settings/configuring-private-networking-for-hosted-compute-products/troubleshooting-azure-private-network-configurations-for-github-hosted-runners-in-your-enterprise)


## License

[MIT License](./LICENSE)