# Azure Private Networking for GitHub-hosted Runners Demo

Learning to set up Azure Private Networking for GitHub-hosted runners. Based on [this guide](https://docs.github.com/en/organizations/managing-organization-settings/configuring-private-networking-for-github-hosted-runners-in-your-organization) with some personal preferences with regards to using PowerShell and Bicep.

Why? You can use GitHub-hosted runners in an Azure VNET. This enables you to use GitHub-managed infrastructure for CI/CD while providing you with full control over the networking policies of your runners. See more details in [the documentation](https://docs.github.com/en/organizations/managing-organization-settings/about-azure-private-networking-for-github-hosted-runners-in-your-organization).

> [!TIP]
> I am currently re-working this demo with support for new GitHub API's allowing for full end-to-end automated deployment. You can check out the previous (still functional!) version see [v1 here](https://github.com/matsest/gh-runner-az-private-network-demo/tree/v1). (Run `git checkout v1` after cloning.)

## Pre-requisites

- An Azure subscription with Contributor and Network Contributor permissions (least privilege) or Owner permissions
- An Enterprise Cloud GitHub organization with [CI/CD Admin](https://github.blog/changelog/2024-09-25-introducing-ci-cd-admin-a-new-pre-defined-organization-role-for-github-actions/) (least privilege) or organization Owner
- [GitHub CLI](https://cli.github.com/) (tested with 2.67)
- PowerShell 7.x with [Azure PowerShell modules](https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell) (tested with Az.Resources 7.8.1)
- Azure Bicep (tested with 0.33.93)

Note that there is limited support for Azure Regions. See supported regions [here](https://docs.github.com/en/organizations/managing-organization-settings/about-azure-private-networking-for-github-hosted-runners-in-your-organization#about-supported-regions).

## Usage

1. Authenticate to GitHub CLI by running [`gh auth login`](https://cli.github.com/manual/gh_auth_login)
    - TODO: correct token usage or scope

2. Find your organization id by running the following script and providing the username of your GitHub organization:

```powershell
./scripts/gh-api-prereqs.ps1 -OrganizationUsername <org-username>

# Output:
{
  "data": {
    "organization": {
      "login": "<org-username>",
      "databaseId": <id>
    }
  }
}
```

:point_right: Copy the value from the `"databaseId"` field for the next step.

3. Deploy a subnet

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

4. Configure the network configuration for your organization in GitHub

See steps [here](https://docs.github.com/en/organizations/managing-organization-settings/configuring-private-networking-for-github-hosted-runners-in-your-organization#creating-a-network-configuration-for-your-organization-in-github). Remember to connect the runner to a runner group and configure labels accordingly.

5. Use the new privately networked GitHub-hosted runner!

You should be able to use the runner by following the same steps as in:

- [Controlling Access to runner groups](https://docs.github.com/en/actions/using-github-hosted-runners/about-larger-runners/controlling-access-to-larger-runners)
- [Run jobs on larger runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-larger-runners/running-jobs-on-larger-runners)

## End-to-end deployment

As of Q1 2025 it's [now possible](https://github.blog/changelog/2025-01-29-actions-github-hosted-larger-runner-network-configuration-rest-apis-ga/) to configure all of this programmatically!

## Clean-up

See details about deleting the configuration [here](https://docs.github.com/en/organizations/managing-organization-settings/configuring-private-networking-for-github-hosted-runners-in-your-organization#deleting-a-subnet).

After completing clean-up in Azure you can also delete the resource group if you have deployed it as a sandbox.

## Links

- [About private networking](https://docs.github.com/en/organizations/managing-organization-settings/about-networking-for-hosted-compute-products-in-your-organization)

- [About Azure Private networking](https://docs.github.com/en/organizations/managing-organization-settings/about-azure-private-networking-for-github-hosted-runners-in-your-organization)

- [Configuring private networking](https://docs.github.com/en/organizations/managing-organization-settings/configuring-private-networking-for-github-hosted-runners-in-your-organization)

## Other options

If you are considering running runners for GitHub Actions in your own Azure private networking, and this scenario does not suit you, you can also consider:

- Running self-hosted runners on [Azure Container App Jobs](https://learn.microsoft.com/en-us/azure/container-apps/tutorial-ci-cd-runners-jobs?tabs=azure-powershell&pivots=container-apps-jobs-self-hosted-ci-cd-github-actions) (simple and cost-effective solution)
- Running self-hosted runners on [whatever compute and infrastructure you like](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners) (can be a hassle..)


## Subnet size and runner concurrency

Based on [GitHub documentation](https://docs.github.com/en/enterprise-cloud@latest/admin/configuring-settings/configuring-private-networking-for-hosted-compute-products/configuring-private-networking-for-github-hosted-runners-in-your-enterprise#prerequisites) it's recommended to add a 30% buffer to the maximum job concurrency you anticipate. This needs to be taken into account when choosing the subnet size (Azure) and the maximum count of runners (GitHub) in the setup. Note that Azure reserves [five of the IP addresses](https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/private-ip-addresses#allocation-method) in a given subnet.

| Subnet size | IP addresses | Usable IP addresses | Max recommended # of runners |
|-------------|--------------|---------------------|------------------------------|
| /28         | 16           | 11                  | 8                            |
| /27         | 32           | 27                  | 20                           |
| /26         | 64           | 59                  | 45                           |
| /25         | 128          | 123                 | 94                           |
| /24         | 256          | 251                 | 190                          |
| /23         | 512          | 507                 | 390                          |