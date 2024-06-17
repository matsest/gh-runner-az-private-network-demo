[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $OrganizationUsername
)

gh api graphql -F login=$OrganizationUsername -f query='
query($login: String!){
  organization (login: $login)
  {
    login
    databaseId
  }
}
'