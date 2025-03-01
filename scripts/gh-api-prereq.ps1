[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $OrganizationUsername
)

# https://docs.github.com/en/graphql/reference/objects#organization
gh api graphql -F login=$OrganizationUsername -f query='
query($login: String!){
  organization (login: $login)
  {
    login
    databaseId
  }
}
'