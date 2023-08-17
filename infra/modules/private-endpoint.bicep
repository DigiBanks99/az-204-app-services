type SubnetInfo = {
  subnetName: string
  vNetName: string
  resourceGroupName: string?
}

param location string
param privateEndpointName string
param privateDnsZoneName string
param privateDnsGroupName string
param subnet SubnetInfo
param serviceId string
param serviceGroup  'blob' | 'file' | 'redisCache' | 'sqlServer'

resource vnetResource 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: subnet.vNetName
  scope: contains(subnet, 'resourceGroupName') && subnet.resourceGroupName != null ? resourceGroup(subnet.resourceGroupName!) : resourceGroup()
}

resource subnetRef 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' existing = {
  parent: vnetResource
  name: subnet.subnetName
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: subnetRef.id
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: serviceId
          groupIds: [
            serviceGroup
          ]
        }
      }
    ]
  }
}

resource privateDnsZoneResource 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZoneResource
  name: '${privateDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetResource.id
    }
  }
}

resource pvtEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  name: privateDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneResource.id
        }
      }
    ]
  }
  dependsOn: [
    privateEndpoint
  ]
}
