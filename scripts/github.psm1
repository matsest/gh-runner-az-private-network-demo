function Get-GitHubOrganizationDatabaseId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $OrganizationUsername
    )

    # https://docs.github.com/en/graphql/reference/objects#organization
    $res = gh api graphql -F login=$OrganizationUsername -f query='
query($login: String!){
  organization (login: $login)
  {
    login
    databaseId
  }
}
' | ConvertFrom-Json

    $res.data.organization.databaseId
}

$res | ConvertFrom-Json

function New-GitHubHostedComputeNetworkingConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$OrganizationUsername,
        [Parameter(Mandatory)]
        [string]$NetworkConfigurationName,
        [Parameter(Mandatory)]
        [string]$NetworkSettingsId
    )

    # https://docs.github.com/en/enterprise-cloud@latest/rest/orgs/network-configurations?apiVersion=2022-11-28#create-a-hosted-compute-network-configuration-for-an-organization
    $res = gh api --method POST `
        -H "Accept: application/vnd.github+json" `
        -H "X-GitHub-Api-Version: 2022-11-28" `
        /orgs/$OrganizationUsername/settings/network-configurations `
        -f "name=$NetworkConfigurationName" `
        -f "network_settings_ids[]=$NetworkSettingsId" `
        -f "compute_service=actions"

    $res | ConvertFrom-Json
}

function New-GitHubRunnerGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$OrganizationUsername,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$NetworkConfigurationId,
        [Parameter()]
        [ValidateSet('all', 'selected', 'private')]
        [string]$Visbility = 'all'
    )

    # https://docs.github.com/en/enterprise-cloud@latest/rest/actions/self-hosted-runner-groups?apiVersion=2022-11-28#create-a-self-hosted-runner-group-for-an-organization
    $res = gh api --method POST `
        -H "Accept: application/vnd.github+json" `
        -H "X-GitHub-Api-Version: 2022-11-28" `
        /orgs/$OrganizationUsername/actions/runner-groups `
        -f "name=$Name" `
        -f "network_configuration_id=$NetworkConfigurationId" `
        -f "visibility=$Visibility"

    $res | ConvertFrom-Json
}

function New-GitHubHostedRunner {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$OrganizationUsername,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [int]$RunnerGroupId,
        [Parameter()]
        [int]$MaximumRunners = 10,
        [Parameter()]
        [ValidateSet('ubuntu-latest', 'ubuntu-24.04', 'ubuntu-22.04')]
        [string]$ImageName = 'ubuntu-24.04',
        [Parameter()]
        [ValidateSet('2-core', '4-core', '8-core', '16-core', '32-core')]
        [string]$Size = '2-core'
    )

    # https://docs.github.com/en/enterprise-cloud@latest/rest/actions/hosted-runners?apiVersion=2022-11-28#create-a-github-hosted-runner-for-an-organization
    $res = gh api --method POST `
        -H "Accept: application/vnd.github+json" `
        -H "X-GitHub-Api-Version: 2022-11-28" `
        /orgs/$OrganizationUsername/actions/runners `
        -f "name=$Name" `
        -f "runner_group_id=$RunnerGroupId" `
        -f "maximum_runners=$MaximumRunners"`
        -f "image[id]=$ImageName" `
        -f "image[source]=github" `
        -f "image[version]=latest" `
        -f "size=$Size"

    $res | ConvertFrom-Json
}