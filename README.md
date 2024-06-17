# Azure Private Networking for GitHub-hosted Runners Demo

Learning to set up Azure Private Networking for GitHub-hosted runners. Based on [this guide](https://docs.github.com/en/organizations/managing-organization-settings/configuring-private-networking-for-github-hosted-runners-in-your-organization) with some personal preferences with regards to using PowerShell and Bicep.

Why? You can use GitHub-hosted runners in an Azure VNET. This enables you to use GitHub-managed infrastructure for CI/CD while providing you with full control over the networking policies of your runners. 

> :warning: Azure Private Networking is currently (June 2024) in public beta and subject to change.

## Pre-requisites

- An Azure subscription with Contributor permissions
- An GitHub organization with organization admin
- [GitHub CLI](https://cli.github.com/) (tested with 2.51)
- PowerShell 7.x with [Azure PowerShell modules](https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell) (tested with Az.Resources 7.1)
- Azure Bicep (tested with 0.28.1)

Note that there is limited support for Azure Regions in the public beta phase. See supported regions [here](https://docs.github.com/en/organizations/managing-organization-settings/about-azure-private-networking-for-github-hosted-runners-in-your-organization#about-supported-regions).

## Usage

1. Authenticate to GitHub CLI by running [`gh auth login`](https://cli.github.com/manual/gh_auth_login)

2. Find your organization id by running the following script and providing the username of your GitHub organization:

```powershell
./gh-api-prereqs.ps1 -OrganizationUsername <org-username>

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
./deploy.ps1 -GitHubDatabaseId <databaseId>

# Output
Registring GitHub.Network resource provider...
Configuring resource group and virtual network...
Deploying template...
✅ Deployment complete!
Network Settings Resource Id:
<network settings resource id>
```

:point_right: Copy the `Network Settings Resource Id` value for the next step.

**Option 2: Deploy to existing vnet**: If you want to set up a new subnet in an existing virtual network you can deploy the [`main.bicep`](./main.bicep) and provide the necessary parameters by editing the `main.bicepparam` file, and then running the following command:

```powershell
$resourceGroupName = "" # existing resource group

$deploy = New-AzResourceGroupDeployment -Name "gh-private-runners-$now" `
    -ResourceGroupName $resourceGroupName -TemplateFile 'main.bicep' `
    -TemplateParameterFile "./main.bicepparam"

$networkSettings = Get-AzResource -ResourceId $deploy.Outputs.networkSettingsId.value

Write-Host "Network Settings Resource Id:"
Write-Host $networkSettings.Tags['GitHubId']

```

:point_right: Copy the `Network Settings Resource Id` value for the next step.

4. Configure the network configuration for your organization in GitHub

See steps [here](https://docs.github.com/en/organizations/managing-organization-settings/configuring-private-networking-for-github-hosted-runners-in-your-organization#creating-a-network-configuration-for-your-organization-in-github). Remember to connect the runner to a runner group and configure labels accordingly.

5. Use the new privately networked GitHub-hosted runner!

You should be able to use the running by following the same steps as in:

- [Controlling Access to runner groups](https://docs.github.com/en/actions/using-github-hosted-runners/about-larger-runners/controlling-access-to-larger-runners)
- [Run jobs on larger runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-larger-runners/running-jobs-on-larger-runners)


## Clean-up

See details about deleting the configuration [here](https://docs.github.com/en/organizations/managing-organization-settings/configuring-private-networking-for-github-hosted-runners-in-your-organization#deleting-a-subnet).

After completing clean-up in Azure you can also delete the resource group if you have deployed it as a sandbox.

## Links

- [About private networking](https://docs.github.com/en/organizations/managing-organization-settings/about-networking-for-hosted-compute-products-in-your-organization)

- [About Azure Private networking](https://docs.github.com/en/organizations/managing-organization-settings/about-azure-private-networking-for-github-hosted-runners-in-your-organization)

- [Configuring private networking](https://docs.github.com/en/organizations/managing-organization-settings/configuring-private-networking-for-github-hosted-runners-in-your-organization)