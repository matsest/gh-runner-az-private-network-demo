using './main.bicep'

param githubDatabaseId = ''
param location = ''
param existingVnetName = ''
param subnetPrefix = ''
param subnetName = 'gh-runner'
param baseName = '${existingVnetName}-${subnetName}'
param nsgName = '${baseName}-nsg'
param networkSettingsName = '${baseName}-networksettings'

