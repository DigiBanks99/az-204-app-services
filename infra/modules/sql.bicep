type SubnetInfo = {
  subnetName: string
  vNetName: string
  resourceGroupName: string?
}
type PrivateEndpoint = {
  name: string
  dnsGroupName: string
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

param location string
param config SqlConfig
param subnetInfo SubnetInfo?

resource sqlServerResource 'Microsoft.Sql/servers@2022-11-01-preview' = {
  name: config.server.name
  location: location
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      login: config.server.administrator.name
      azureADOnlyAuthentication: true
      principalType: config.server.administrator.principalType
      sid: config.server.administrator.objectId
      tenantId: subscription().tenantId
    }
    version: '12.0'
    minimalTlsVersion: '1.2'
  }
}

resource sqlDB 'Microsoft.Sql/servers/databases@2022-11-01-preview' = {
  parent: sqlServerResource
  name: config.database.name
  location: location
  sku: {
    name: config.database.sku
    tier: config.database.sku
  }
}

module privateEndpoint './private-endpoint.bicep' = if (contains(config.server, 'privateEndpoint') && subnetInfo != null) {
  name: 'private-endpoint-sql'
  params: {
    location: location
    privateDnsGroupName: '${config.server.privateEndpoint!.name}/${config.server.privateEndpoint!.dnsGroupName}'
    privateDnsZoneName: 'privatelink${environment().suffixes.sqlServerHostname}'
    privateEndpointName: config.server.privateEndpoint!.name
    serviceGroup: 'sqlServer'
    serviceId: sqlServerResource.id
    subnet: {
      subnetName: subnetInfo!.subnetName
      vNetName: subnetInfo!.vNetName
      resourceGroupName: contains(subnetInfo!, 'resourceGroupName') ? subnetInfo!.resourceGroupName : null
    }
  }
}

output fullyQualifiedDomainName string = sqlServerResource.properties.fullyQualifiedDomainName
