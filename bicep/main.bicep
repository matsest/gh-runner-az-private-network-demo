@description('GitHub Database Id for the organization')
param githubDatabaseId string
@description('Location for all resources - must match the location for the existing virtual network!')
param location string
@description('Name of the existing virtual network')
param existingVnetName string
@description('Address prefix for the subnet. To determine the appropriate subnet IP address range, we recommend adding a 30% buffer to the maximum job concurrency you anticipate. For instance, if your network configurations runners are set to a maximum job concurrency of 300, its recommended to utilize a subnet IP address range that can accommodate at least 390 runners.')
param subnetPrefix string

// Optional params
@description('Name of the subnet')
param subnetName string = 'gh-runner'
@description('Base name for new resources')
param baseName string = '${existingVnetName}-${subnetName}'
@description('Name of the network security group')
param nsgName string = '${baseName}-nsg'
@description('Name of the network settings')
param networkSettingsName string = '${baseName}-networksettings'

// Existing resources
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' existing = {
  name: existingVnetName
}

// Resources
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'deny-inbound-all'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'allow-vnet-outbound-to-vnet'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 200
          direction: 'Outbound'
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'allow-outbound-to-github1'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          access: 'Allow'
          priority: 210
          direction: 'Outbound'
          destinationAddressPrefixes: [
            '4.175.114.51/32'
            '20.102.35.120/32'
            '4.175.114.43/32'
            '20.72.125.48/32'
            '20.19.5.100/32'
            '20.7.92.46/32'
            '20.232.252.48/32'
            '52.186.44.51/32'
            '20.22.98.201/32'
            '20.246.184.240/32'
            '20.96.133.71/32'
            '20.253.2.203/32'
            '20.102.39.220/32'
            '20.81.127.181/32'
            '52.148.30.208/32'
            '20.14.42.190/32'
            '20.85.159.192/32'
            '52.224.205.173/32'
            '20.118.176.156/32'
            '20.236.207.188/32'
            '20.242.161.191/32'
            '20.166.216.139/32'
            '20.253.126.26/32'
            '52.152.245.137/32'
            '40.118.236.116/32'
            '20.185.75.138/32'
            '20.96.226.211/32'
            '52.167.78.33/32'
            '20.105.13.142/32'
            '20.253.95.3/32'
            '20.221.96.90/32'
            '51.138.235.85/32'
            '52.186.47.208/32'
            '20.7.220.66/32'
            '20.75.4.210/32'
            '20.120.75.171/32'
            '20.98.183.48/32'
            '20.84.200.15/32'
            '20.14.235.135/32'
            '20.10.226.54/32'
            '20.22.166.15/32'
            '20.65.21.88/32'
            '20.102.36.236/32'
            '20.124.56.57/32'
            '20.94.100.174/32'
            '20.102.166.33/32'
            '20.31.193.160/32'
            '20.232.77.7/32'
            '20.102.38.122/32'
            '20.102.39.57/32'
            '20.85.108.33/32'
            '40.88.240.168/32'
            '20.69.187.19/32'
            '20.246.192.124/32'
            '20.4.161.108/32'
            '20.22.22.84/32'
            '20.1.250.47/32'
            '20.237.33.78/32'
            '20.242.179.206/32'
            '40.88.239.133/32'
            '20.121.247.125/32'
            '20.106.107.180/32'
            '20.22.118.40/32'
            '20.15.240.48/32'
            '20.84.218.150/32'
          ]
        }
      }
      {
        name: 'allow-outbound-to-github2'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          access: 'Allow'
          priority: 220
          direction: 'Outbound'
          destinationAddressPrefixes: [
            '140.82.112.0/20'
            '143.55.64.0/20'
            '185.199.108.0/22'
            '192.30.252.0/22'
            '20.175.192.146/32'
            '20.175.192.147/32'
            '20.175.192.149/32'
            '20.175.192.150/32'
            '20.199.39.227/32'
            '20.199.39.228/32'
            '20.199.39.231/32'
            '20.199.39.232/32'
            '20.200.245.241/32'
            '20.200.245.245/32'
            '20.200.245.246/32'
            '20.200.245.247/32'
            '20.200.245.248/32'
            '20.201.28.144/32'
            '20.201.28.148/32'
            '20.201.28.149/32'
            '20.201.28.151/32'
            '20.201.28.152/32'
            '20.205.243.160/32'
            '20.205.243.164/32'
            '20.205.243.165/32'
            '20.205.243.166/32'
            '20.205.243.168/32'
            '20.207.73.82/32'
            '20.207.73.83/32'
            '20.207.73.85/32'
            '20.207.73.86/32'
            '20.207.73.88/32'
            '20.233.83.145/32'
            '20.233.83.146/32'
            '20.233.83.147/32'
            '20.233.83.149/32'
            '20.233.83.150/32'
            '20.248.137.48/32'
            '20.248.137.49/32'
            '20.248.137.50/32'
            '20.248.137.52/32'
            '20.248.137.55/32'
            '20.26.156.216/32'
            '20.27.177.113/32'
            '20.27.177.114/32'
            '20.27.177.116/32'
            '20.27.177.117/32'
            '20.27.177.118/32'
            '20.29.134.17/32'
            '20.29.134.18/32'
            '20.29.134.19/32'
            '20.29.134.23/32'
            '20.29.134.24/32'
            '20.87.245.0/32'
            '20.87.245.1/32'
            '20.87.245.4/32'
            '20.87.245.6/32'
            '20.87.245.7/32'
            '4.208.26.196/32'
            '4.208.26.197/32'
            '4.208.26.198/32'
            '4.208.26.199/32'
            '4.208.26.200/32'
          ]
        }
      }
      {
        name: 'allow-outbound-storage'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          priority: 230
          direction: 'Outbound'
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'deny-outbound-internet'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          access: 'Deny'
          priority: 400
          direction: 'Outbound'
        }
      }
    ]
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  name: subnetName
  parent: vnet
  properties: {
    addressPrefix: subnetPrefix
    delegations: [
      {
        name: 'GitHub.Network/networkSettings'
        properties: {
          serviceName: 'GitHub.Network/networkSettings'
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// Deployed as module due to unsupported resource type in Bicep
module networkSettings 'networkSettings.json' = {
  name: networkSettingsName
  params: {
    name: networkSettingsName
    location: location
    subnetName: subnet.name
    vnetName: vnet.name
    databaseId: githubDatabaseId
  }
}

output networkSettingsId string = networkSettings.outputs.id
