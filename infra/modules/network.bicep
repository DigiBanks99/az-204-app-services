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

param vnet VNet
param location string

resource vnetResource 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnet.name
  location: location
  properties: {
    addressSpace: vnet.addressSpace
    subnets: contains(vnet, 'subnets') ? vnet.subnets : []
  }
}
