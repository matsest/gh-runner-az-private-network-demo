# Configure env
$env:GH_PROMPT_DISABLED = "true"
$env:GH_PAGER = ""

function Get-GitHubOrgDatabaseId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Organzation
    )

    # https://docs.github.com/en/graphql/reference/objects#organization
    $res = gh api graphql -F login=$Organzation -f query='
query($login: String!){
  organization (login: $login)
  {
    login
    databaseId
  }
}
' | ConvertFrom-Json

    [string]$databaseId = $res.data.organization.databaseId
    if ([string]::IsNullOrEmpty($databaseId)) {
        throw "Could not determine database id for organization '$Organzation'"
    }

    $databaseId
}

# MARK: Hosted compute networking configuration
function Get-GitHubOrgHostedComputeNetworkingConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Organzation,
        [Parameter(Mandatory)]
        [string]$Name
    )

    # Required permissions: "Network configurations" organization permissions (read) (read:network_configurations)
    # https://docs.github.com/en/enterprise-cloud@latest/rest/orgs/network-configurations?apiVersion=2022-11-28#list-hosted-compute-network-configurations-for-an-organization
    $res = gh api --method GET `
        -H "Accept: application/vnd.github+json" `
        -H "X-GitHub-Api-Version: 2022-11-28" `
        --paginate --slurp `
        /orgs/$Organzation/settings/network-configurations `
    | ConvertFrom-Json -Depth 100

    if ($res.status -eq 404) {
        Write-Warning "Could not find any network configurations for organization '$Organzation'"
        return
    }

    $networkConfig = $res.network_configurations | Where-Object { $_.name -eq $Name }
    if (-not $networkConfig) {
        Write-Warning "Could not find network configuration with the name '$Name'. Found $($res.total_count) network configurations."
        return
    }

    $networkConfig
}

function New-GitHubOrgHostedComputeNetworkingConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Organzation,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$NetworkSettingsId,
        [Parameter()]
        [hashtable]$AdditionalSettings = @{}
    )

    $defaultSettings = @{
        name                   = $Name
        'network_settings_ids' = @($NetworkSettingsId)
        compute_service        = 'actions'
    }
    $allSettings = Merge-HashTable -Default $defaultSettings -Update $AdditionalSettings

    # Check if networking configuration already exist
    $existingNetworkConfig = Get-GitHubOrgHostedComputeNetworkingConfiguration -Organzation $Organzation -Name $Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if ($existingNetworkConfig) {
        Write-Warning "Networking configuration with the name '$Name' already exists."
        return $existingNetworkConfig
    }

    # Required permissions: "Network configurations" organization permissions (write) (write:network_configurations)
    # https://docs.github.com/en/enterprise-cloud@latest/rest/orgs/network-configurations?apiVersion=2022-11-28#create-a-hosted-compute-network-configuration-for-an-organization
    $res = ($allSettings | ConvertTo-Json) | gh api --method POST `
        -H "Accept: application/vnd.github+json" `
        -H "X-GitHub-Api-Version: 2022-11-28" `
        /orgs/$Organzation/settings/network-configurations `
        --input -
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create networking configuration: '$Name'`n$res"
    }

    $res | ConvertFrom-Json
}

# MARK: Runner group
function Get-GitHubOrgRunnerGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Organzation,
        [Parameter(Mandatory)]
        [string]$Name
    )

    # Required permissions: "Self-hosted runners" organization permissions (read)
    # https://docs.github.com/en/enterprise-cloud@latest/rest/actions/self-hosted-runner-groups?apiVersion=2022-11-28#list-self-hosted-runner-groups-for-an-organization
    $res = gh api --method GET `
        -H "Accept: application/vnd.github+json" `
        -H "X-GitHub-Api-Version: 2022-11-28" `
        /orgs/$Organzation/actions/runner-groups `
        --paginate --slurp
    | ConvertFrom-Json -Depth 100

    if ($res.status -eq 404) {
        Write-Warning "Could not find any runner groups for organization '$Organzation'"
        return
    }

    $runnerGroup = $res.runner_groups | Where-Object { $_.name -eq $Name }
    if (-not $runnerGroup) {
        Write-Warning "Could not find runner group with the name '$Name'. Found $($res.total_count) runner groups."
        return
    }

    $runnerGroup
}

function New-GitHubOrgRunnerGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Organzation,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter()]
        [string]$NetworkConfigurationId = $null,
        [Parameter()]
        [ValidateSet('all', 'selected', 'private')]
        [string]$Visibility = 'private',
        [Parameter()]
        [hashtable]$AdditionalSettings = @{}
    )

    # Required settings
    $defaultSettings = @{
        name       = $Name
        visibility = $Visibility
    }
    # Optional settings
    if ($NetworkConfigurationId) {
        $defaultSettings["network_configuration_id"] = $NetworkConfigurationId
    }
    # All settings
    $allSettings = Merge-HashTable -Default $defaultSettings -Update $AdditionalSettings

    # Check if runner group already exist
    $existingRunnerGroup = Get-GitHubOrgRunnerGroup -Organzation $Organzation -Name $Name -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if ($existingRunnerGroup) {
        Write-Warning "Runner group with the name '$Name' already exists."
        return $existingRunnerGroup
    }

    # Required permissions: "Self-hosted runners" organization permissions (write)
    # https://docs.github.com/en/enterprise-cloud@latest/rest/actions/self-hosted-runner-groups?apiVersion=2022-11-28#create-a-self-hosted-runner-group-for-an-organization
    $res = $($allSettings | ConvertTo-Json ) | gh api --method POST `
        -H 'Accept: application/vnd.github+json' `
        -H 'X-GitHub-Api-Version: 2022-11-28' `
        /orgs/$Organzation/actions/runner-groups `
        --input -
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create runner group: '$Name'`n$res"
    }

    # Return as object
    $res | ConvertFrom-Json
}

# MARK: Runner
function Get-GitHubOrgHostedRunner {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Organzation,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$RunnerGroupId
    )

    # Required permissions: "Administration" organization permissions (read)
    # https://docs.github.com/en/enterprise-cloud@latest/rest/actions/hosted-runners?apiVersion=2022-11-28#get-a-github-hosted-runner-for-an-organization
    $res = gh api --method GET `
        -H "Accept: application/vnd.github+json" `
        -H "X-GitHub-Api-Version: 2022-11-28" `
        /orgs/$Organzation/actions/hosted-runners `
    | ConvertFrom-Json -Depth 100

    if ($res.status -eq 404) {
        Write-Warning "Could not find any GitHub-hosted runners for organization '$Organzation'"
        return
    }

    $runner = $res.runners | Where-Object { $_.name -eq $Name -and $_.runner_group_id -eq $RunnerGroupId }
    if (-not $runner) {
        Write-Warning "Could not find GitHub-hosted runner with the name '$Name' in runner group with id '$RunnerGroupId'."
        return
    }

    $res
}

function Get-GitHubOwnedImage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Organzation,
        [Parameter(Mandatory)]
        [string]$Name
    )

    # Required permissions: "Administration" organization permissions (read)
    # https://docs.github.com/en/enterprise-cloud@latest/rest/actions/hosted-runners?apiVersion=2022-11-28#get-github-owned-images-for-github-hosted-runners-in-an-organization
    $res = gh api --method GET `
        -H "Accept: application/vnd.github+json" `
        -H "X-GitHub-Api-Version: 2022-11-28" `
        /orgs/$Organzation/actions/hosted-runners/images/github-owned `
    | ConvertFrom-Json -Depth 100

    if ($res.status -eq 404) {
        Write-Warning "Could not find any images for organization '$Organzation'"
        return
    }

    $image = $res.images | Where-Object { $_.display_name -match $Name }
    if (-not $image ) {
        Write-Warning "Could not find image with name '$Name'. Found: $($res.images.display_name -join ', ')"
        return
    }

    $image
}

function New-GitHubOrgHostedRunner {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Organzation,
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [int]$RunnerGroupId,
        [Parameter()]
        [int]$MaximumRunners = 10,
        [Parameter()]
        [ValidateSet('Ubuntu Latest', 'Ubuntu 24.04', 'Ubuntu 22.04')]
        [string]$ImageName = 'Ubuntu 24.04',
        [Parameter()]
        [ValidateSet('2-core', '4-core', '8-core', '16-core', '32-core', '64-core')]
        [string]$Size = '2-core',
        [Parameter()]
        [hashtable]$AdditionalSettings = @{}
    )

    # Check if runner already exist
    $existingRunner = Get-GitHubOrgHostedRunner -Organzation $Organzation -Name $Name -RunnerGroupId $RunnerGroupId -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    if ($existingRunner) {
        Write-Warning "Runner with the name '$Name' in runner group already exists."
        return $existingRunner
    }

    $image = Get-GitHubOwnedImage -Organzation $Organzation -Name $ImageName
    if (-not $image) {
        throw "Could not find image with the name '$ImageName'"
    }

    # Required settings
    $defaultSettings = @{
        name            = $Name
        runner_group_id = $RunnerGroupId
        maximum_runners = $MaximumRunners
        size            = $Size
        image           = @{
            id     = $image.id
            source = $image.source
        }
    }
    # All settings
    $allSettings = Merge-HashTable -Default $defaultSettings -Update $AdditionalSettings

    # Required permissions: "Administration" organization permissions (write)
    # https://docs.github.com/en/enterprise-cloud@latest/rest/actions/hosted-runners?apiVersion=2022-11-28#create-a-github-hosted-runner-for-an-organization
    # Question about too wide permissions required: https://github.com/orgs/community/discussions/149651#discussioncomment-12373322
    $res = ($allSettings | ConvertTo-Json) | gh api --method POST `
        -H "Accept: application/vnd.github+json" `
        -H "X-GitHub-Api-Version: 2022-11-28" `
        /orgs/$Organzation/actions/hosted-runners `
        --input -
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create runner: '$Name'`n$res"
    }

    # Return as object
    $res | ConvertFrom-Json
}

# MARK: Support functions
function Merge-HashTable {
    param(
        [hashtable]$Default,
        [hashtable]$Update
    )

    # check if one hashtable is $null
    if (-not $Default) {
        return $Update
    }
    if (-not $Update) {
        return $Default
    }

    $default1 = $Default.Clone();
    foreach ($key in $Update.Keys) {
        if ($default1.ContainsKey($key)) {
            $default1.Remove($key);
        }
    }

    # Union both sets
    $default1 + $Update
}

function Convert-SubnetSizeToRunnersCount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$SubnetAddressPrefix
    )

    # Find the number of usable IPs
    [int]$prefixLength = [System.Net.IPNetwork]::Parse($SubnetAddressPrefix).PrefixLength

    if ($prefixLength -gt 28) {
        throw "Number of available IPs is too small. Choose a larger subnet (min. /28). "
    }

    # Calculate the number of available IPs based on CIDR Prefix
    $numberOfIps = [math]::Pow(2, 32 - $prefixLength)
    # Azure reserves 5 IP addresses within each subnet
    $usableIps = $numberOfIps - 5
    Write-Verbose "Number of usable IPs: $usableIps"

    # We need to have a 30% buffer for the number of runners
    $buffer = 0.3
    $maxRunnersCount = [math]::Floor($usableIps / (1 + $buffer))
    Write-Verbose "Maximum number of runners: $maxRunnersCount"
    $maxRunnersCount
}