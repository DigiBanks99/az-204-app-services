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

type SubnetInfo = {
  subnetName: string
  vNetName: string
  resourceGroupName: string?
}

type SqlInfo = {
  serverName: string
  databaseName: string
}

param location string

param appPlan AppPlan
param webApp WebApp
param storageAccountName string
param subnetInfo SubnetInfo
param sql SqlInfo

param baseTime string = utcNow('u')

resource appPlanResource 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appPlan.name
  location: location
  kind: appPlan.os == 'linux' ? appPlan.os : 'app'
  sku: {
    name: appPlan.sku
  }
  properties: {
    reserved: appPlan.os == 'linux' ? true : false
  }
}

var connectionStrings = [
  {
    name: 'AZURE_SQL_CONNECTIONSTRING'
    connectionString: 'Server=tcp:${sql.serverName}${environment().suffixes.sqlServerHostname},1433;Initial Catalog=${sql.databaseName};Min Pool Size=1;Authentication=Active Directory MSI;'
    type: 'SQLAzure'
  }
]

var siteConfig = {
  connectionStrings: connectionStrings
  ftpsState: 'Disabled'
  http20Enabled: true
  linuxFxVersion: appPlan.os == 'linux' ? webApp.runtime : null
  metadata: [
    {
      name: 'CURRENT_STACK'
      value: 'dotnetcore'
    }
  ]
  minTlsVersion: '1.2'
  netFrameworkVersion: 'v7.0'
  use32BitWorkerProcess: false
  webSocketsEnabled: true
  windowsFxVersion: appPlan.os == 'windows' ? webApp.runtime : null
}

resource webAppResource 'Microsoft.Web/sites@2022-09-01' = {
  identity: {
    type: 'SystemAssigned'
  }
  location: location
  name: webApp.name
  properties: {
    httpsOnly: true
    serverFarmId: appPlanResource.id
    siteConfig: siteConfig
  }
}

resource slotStage 'Microsoft.Web/sites/slots@2022-09-01' =
  if (webApp.hasSlots) {
    name: 'stage'
    location: location
    parent: webAppResource
    properties: {
      httpsOnly: true
      serverFarmId: appPlanResource.id
      siteConfig: siteConfig
    }
  }

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

var sasAccessToken = storageAccount.listAccountSas(
  '2023-01-01',
  {
    signedExpiry: dateTimeAdd(baseTime, 'P6M')
    signedPermission: 'rwdlacup'
    signedResourceTypes: 'sco'
    signedServices: 'bfqt'
  }
).accountSasToken

resource logs 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'logs'
  parent: webAppResource
  properties: {
    applicationLogs: {
      azureBlobStorage: {
        level: 'Verbose'
        retentionInDays: 10
        sasUrl: '${storageAccount.properties.primaryEndpoints.blob}${webApp.logContainerName}?${sasAccessToken}'
      }
    }
    detailedErrorMessages: {
      enabled: true
    }
    failedRequestsTracing: {
      enabled: true
    }
  }
}

resource appsettings 'Microsoft.Web/sites/config@2019-08-01' = {
  name: 'appsettings'
  parent: webAppResource
  properties: {
    ASPNETCORE_ENVIRONMENT: 'Development'
    WEBSITE_VNET_ROUTE_ALL: '1'
  }
}

resource networkConfig 'Microsoft.Web/sites/networkConfig@2022-09-01' = {
  name: 'virtualNetwork'
  parent: webAppResource
  properties: {
    subnetResourceId: resourceId(
      'Microsoft.Network/virtualNetworks/subnets',
      subnetInfo.vNetName,
      subnetInfo.subnetName
    )
    swiftSupported: true
  }
}
