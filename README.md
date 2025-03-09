# Azure Private Networking for GitHub-hosted Runners Demo

Learning to set up Azure Private Networking for GitHub-hosted runners. This repository provides an end-to-end automated deployment of Azure _and_ GitHub resources using PowerShell, Bicep and GitHub CLI - **all in less than one minute!** :zap:

Why? You can use GitHub-hosted runners in an Azure VNET to connect privately to other resources. This enables you to use GitHub-managed infrastructure for CI/CD while providing you with full control over the networking policies of your runners. See more details in [the documentation](#official-documentation).

> [!TIP]
> This repo has been massively updated to support the [new GitHub API's allowing for full end-to-end automated deployment](https://github.blog/changelog/2025-01-29-actions-github-hosted-larger-runner-network-configuration-rest-apis-ga/) for a full end to end deployment. You can check out the previous (still functional but not end-to-end automated) version see [v1 here](https://github.com/matsest/gh-runner-az-private-network-demo/tree/v1). (Run `git checkout v1` after cloning.)

## Prerequisites

- An Azure subscription with **Contributor** and **Network Contributor** permissions (least privilege) or **Owner** permissions
- An **Team** or **Enterprise Cloud** GitHub organization with **organization Owner role** (required to run operations via GH CLI with Oauth scopes)
  - Working on identifying if a lesser-privileged approach is supported, either using Oauth scopes, GitHub Apps or fine-grained tokens (awaiting [discussion](https://github.com/orgs/community/discussions/149651#discussioncomment-12373322))
- [GitHub CLI](https://cli.github.com/) (tested with 2.68.1)
- PowerShell 7.x with [Azure PowerShell modules](https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell) (tested with PowerShell 7.5.0 and Az.Resources 7.8.1)
- [Azure Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install) (tested with 0.33.93)

Note that there is limited support for Azure regions with Azure Private Networking. See supported Azure regions [here](https://docs.github.com/en/organizations/managing-organization-settings/about-azure-private-networking-for-github-hosted-runners-in-your-organization#about-supported-regions).

## Usage

1. [Authenticate with GitHub CLI](https://cli.github.com/manual/gh_auth_login) by running:

``` powershell
# Login
gh auth login -s admin:org,write:network_configurations

# If already logged in refresh scopes by running:
gh auth refresh -h github.com -s admin:org,write:network_configurations
```

2. [Authenticate with Azure PowerShell](https://learn.microsoft.com/en-us/powershell/azure/authenticate-azureps) by running:

```powershell
# Login
Connect-AzAccount
# Set context to subscription
Set-AzContext -Subscription <subscription name or id>
```

3. Deploy Azure and GitHub configuration:

**Option 1: Sandbox deployment**: Run the following script to create a new resource group, a new virtual network and configure a new subnet:

```powershell
./deploy.ps1 -GitHubOrgUserName <github org name>
```

**Option 2: Deploy to existing vnet**: Run the following  script to create a new subnet in an existing virtual network and resource group:

```powershell
$vnet = Get-AzVirtualNetwork -ResourceGroupName -Name <name>

./deploy.ps1 -GitHubOrgUserName <github org name> `
    -SubnetAddressPrefix <address prefix> `
    -SubnetName <subnet name>
```

### What will be deployed?
- Azure:
  - Sandbox deploy: resource group, vnet with subnet, NSG and network settings
  - Existing vnet: subnet, NSG and network settings
- GitHub (all configurations will be named after the vnet name):
  - Hosted Compute Networking Configuration
  - Runner Group (only available to private repositories)
  - Runner (Ubuntu 24.04, 2-core)

### Example output

```powershell

--------------------------------------------------------------------------------

🚀 Deploying GitHub-hosted runners with Azure Private Networking

Using GitHub organization '<org name>'
Using Azure subscription: '<sub name>'
Running in sandbox mode - will deploy everything into a new resource group

--------------------------------------------------------------------------------

- Registring GitHub.Network resource provider...
    - Provider already registered!
- Configuring resource group and virtual network...
- Deploying Azure subnet configuration...
    - Configured subnet: github-runner!
- Creating GitHub hosted networking configuration...
    - Created networking configuration: gh-private-vnet!
- Creating GitHub runner group...
    - Created runner group: gh-private-vnet!
- Creating GitHub runner...
    - Created runner: gh-private-vnet-ubuntu-24.04!

✅ Deployment complete!

Deployment for Azure and GitHub completed in: 0m50s

--------------------------------------------------------------------------------

🔗 Link to Azure resource group:
https://portal.azure.com/#@<tenant i>/resource/subscriptions/<sub id>/resourceGroups/gh-private-runners

🔗 Link to GitHub hosted compute networking configuration:
https://github.com/organizations/<org name>/settings/network_configurations/<id>

🔗 Link to GitHub runner group with runner:
https://github.com/organizations/<org name>/settings/actions/runner-groups/<id>

💡 Add the following to a GitHub Actions workflow to get started:

.github/workflows/az-private-networking-demo.yml:
---

name: az-private-networking-demo
on: [push]
jobs:
  demo:
    runs-on:
      group: gh-private-vnet
    steps:
      - uses: actions/checkout@v4
      - name: Show local IP address
        run: hostname -I

```

## Clean-up

### GitHub

Done via GitHub.com (in order):

1. [Delete the runner](https://docs.github.com/en/enterprise-cloud@latest/actions/hosting-your-own-runners/managing-self-hosted-runners/removing-self-hosted-runners) (might take a few minutes)
2. [Delete the runner group](https://docs.github.com/en/enterprise-cloud@latest/actions/hosting-your-own-runners/managing-self-hosted-runners/managing-access-to-self-hosted-runners-using-groups#removing-a-self-hosted-runner-group)
3. [Delete the hosted networking configuration](https://docs.github.com/en/organizations/managing-organization-settings/configuring-private-networking-for-github-hosted-runners-in-your-organization#deleting-a-subnet)

### Azure

<details>

#### Full deploy option

```powershell
# Remove the resource group with all resources
Remove-AzResourceGroup -Name <name>
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

The relationship between a subnet address prefix and maximum number of runners it can hold can be calculated with the [`Convert-SubnetSizeToRunnersCount`](https://github.com/matsest/gh-runner-az-private-network-demo/blob/4134c5a6392f034d1662505f577723c01529c354/pwsh/github.psm1#L343) function which is used in the script to automatically resolve the count of runners to allow for.

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

### Filtering traffic by FQDN via a Firewall

If you are deploying into an existing vnet with a default route to a firewall that filters traffic (e.g. Azure Firewall) you will can whitelist [these URL's](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners#communication-between-self-hosted-runners-and-github) to allow traffic from the runner to GitHub.

Optionally you kan simplify the outbound NSG-rules to allow traffic to 'Internet' and handle the granular filtering based on FQDNs in firewall rules.

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