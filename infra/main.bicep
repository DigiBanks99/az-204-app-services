param location string
@allowed([
  'linux'
  'windows'
])
param os string

param baseTime string = utcNow('u')

var appConfig = {
  ftpsState: 'Disabled'
  http20Enabled: true
  linuxFxVersion: os == 'linux' ? 'DOTNETCORE|7.0' : null
  minTlsVersion: '1.2'
  netFrameworkVersion: null
  webSocketsEnabled: true
  windowsFxVersion: os == 'windows' ? 'DOTNETCORE|7.0' : null
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'sawilcobsbx'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
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

var blobContainerName = toLower('${webApp.name}-logs')
resource webAppLogsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = {
  parent: blobServices
  name: blobContainerName
  properties: {
    publicAccess: 'None'
  }
}

resource appPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'asp-wilcob-sbx'
  location: location
  kind: os == 'linux' ? os : 'app'
  sku: {
    name: 'S1'
  }
  properties: {
    reserved: os == 'linux' ? true : false
  }
}

resource webApp 'Microsoft.Web/sites@2022-09-01' = {
  identity: {
    type: 'SystemAssigned'
  }
  location: location
  name: 'app-wilcob-sbx'
  properties: {
    httpsOnly: true
    serverFarmId: appPlan.id
    siteConfig: appConfig
  }
}

resource slotStage 'Microsoft.Web/sites/slots@2022-09-01' = {
  name: 'stage'
  location: location
  parent: webApp
  properties: {
    httpsOnly: true
    serverFarmId: appPlan.id
    siteConfig: appConfig
  }
}

var sasAccessToken = storageAccount.listAccountSas('2023-01-01', {
    signedExpiry: dateTimeAdd(baseTime, 'P6M')
    signedPermission: 'rwdlacup'
    signedResourceTypes: 'sco'
    signedServices: 'bfqt'
  }).accountSasToken

resource logs 'Microsoft.Web/sites/config@2022-09-01' = {
  name: 'logs'
  parent: webApp
  properties: {
    applicationLogs: {
      azureBlobStorage: {
        level: 'Verbose'
        retentionInDays: 10
        sasUrl: '${storageAccount.properties.primaryEndpoints.blob}${blobContainerName}?${sasAccessToken}'
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
