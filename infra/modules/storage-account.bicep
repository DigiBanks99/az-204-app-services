type BlobContainer  = {
  name: string
  publicAccess: 'Blob' | 'Container' | 'None'
}
type SubnetInfo = {
  subnetName: string
  vNetName: string
  resourceGroupName: string?
}
type PrivateEndpoint = {
  name: string
  dnsGroupName: string
}

param name string
param location string
param blobs BlobContainer[]
param privateEndpoint PrivateEndpoint?
param subnetInfo SubnetInfo?

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Disabled'
    supportsHttpsTrafficOnly: true
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    containerDeleteRetentionPolicy: {
      days: 10
      enabled: true
    }
  }
}

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = [for blob in blobs: {
  parent: blobServices
  name: blob.name
  properties: {
    publicAccess: blob.publicAccess
  }
}]

module privateEndpointDeployment './private-endpoint.bicep' = if (privateEndpoint != null) {
  name: 'private-endpoint-storage'
  params: {
    location: location
    privateDnsGroupName: '${privateEndpoint!.name}/${privateEndpoint!.dnsGroupName}'
    privateDnsZoneName: 'privatelink${environment().suffixes.storage}'
    privateEndpointName: privateEndpoint!.name
    serviceGroup: 'blob'
    serviceId: storageAccount.id
    subnet: {
      subnetName: subnetInfo!.subnetName
      vNetName: subnetInfo!.vNetName
      resourceGroupName: contains(subnetInfo!, 'resourceGroupName') ? subnetInfo!.resourceGroupName : null
    }
  }
}
