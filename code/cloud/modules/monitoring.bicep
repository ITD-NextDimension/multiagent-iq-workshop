// Log Analytics workspace shared by ACA and AKS.
param name string
param location string

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

output id string = law.id
output customerId string = law.properties.customerId
@secure()
output primarySharedKey string = law.listKeys().primarySharedKey
