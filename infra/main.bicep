type OS = 'linux' | 'windows'
type AppPlan = {
  name: string
  os: OS
  sku: 'F1' | 'B1' | 'S1'
}
type WebApp = {
  name: string
  hasSlots: bool
  runtime: 'DOTNET|7.0' | 'DOTNET|6.0'
  logContainerName: string
}
type SqlAdministrator = {
  name: string
  principalType: 'Application' | 'Group' | 'User'
  objectId: string
}
type SqlServer = {
  name: string
  administrator: SqlAdministrator
  privateEndpoint: PrivateEndpoint
}
type Db = {
  name: string
  sku: 'Standard' | 'Free' | 'Basic'
}

type SqlConfig = {
  server: SqlServer
  database: Db
}

type VNet = {
  name: string
  addressSpace: AddressSpace
  subnets: Subnet[]?
}

type AddressSpace = {
  addressPrefixes: string[]
}

type SubnetDelegation = {
  name: string
  properties: {
    serviceName: string
  }
}

type ServiceEndpoint = {
  service: string
}

type Subnet = {
  name: string
  properties: {
    addressPrefix: string
    delegations: SubnetDelegation[]?
    serviceEndpoints: ServiceEndpoint[]?
    privateEndpointNetworkPolicies: 'Enabled' | 'Disabled' | null
  }
}

type PrivateEndpoint = {
  name: string
  dnsGroupName: string
}

type StorageAccountConfig = {
  name: string
  privateEndpoint: PrivateEndpoint?
}

param location string

param appPlan AppPlan
param webApp WebApp
param storageAccount StorageAccountConfig
param sqlConfig SqlConfig
param vnet VNet

module vnetDeployment 'modules/network.bicep' = {
  name: 'vnet'
  params: {
    location: location
    vnet: vnet
  }
}

module storageAccountDeployment 'modules/storage-account.bicep' = {
  name: 'storage-account'
  params: {
    blobs: [{ name: webApp.logContainerName, publicAccess: 'None' }]
    location: location
    name: storageAccount.name
    privateEndpoint: contains(storageAccount, 'privateEndpoint') ? storageAccount.privateEndpoint : null
    subnetInfo: {
      subnetName: 'storage'
      vNetName: vnet.name
    }
  }
}

module sqlDeployment 'modules/sql.bicep' = {
  name: 'sql'
  dependsOn: [
    vnetDeployment
  ]
  params: {
    config: sqlConfig
    location: location
    subnetInfo: {
      subnetName: 'sql'
      vNetName: vnet.name
    }
  }
}

module webAppDeployment 'modules/web-app.bicep' = {
  name: 'web-app'
  dependsOn: [
    sqlDeployment
  ]
  params: {
    appPlan: appPlan
    location: location
    sql: {
      databaseName: sqlConfig.database.name
      serverName: sqlConfig.server.name
    }
    storageAccountName: storageAccount.name
    subnetInfo: {
      subnetName: 'serverFarms'
      vNetName: vnet.name
    }
    webApp: webApp
  }
}
