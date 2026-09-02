@description('Prefix used to create globally unique Communication Services resource names.')
param namePrefix string

@description('ACS data residency location. Must match for Communication Services and Email.')
param dataLocation string = 'Europe'

var uniqueSuffix = uniqueString(subscription().id, resourceGroup().id)
var communicationServiceName = '${namePrefix}-acs-${uniqueSuffix}'
var emailServiceName = '${namePrefix}-email-${uniqueSuffix}'

resource emailService 'Microsoft.Communication/emailServices@2025-09-01' = {
  name: emailServiceName
  location: 'global'
  properties: {
    dataLocation: dataLocation
  }
}

resource managedDomain 'Microsoft.Communication/emailServices/domains@2025-09-01' = {
  parent: emailService
  name: 'AzureManagedDomain'
  location: 'global'
  properties: {
    domainManagement: 'AzureManaged'
    userEngagementTracking: 'Disabled'
  }
}

resource communicationService 'Microsoft.Communication/communicationServices@2025-09-01' = {
  name: communicationServiceName
  location: 'global'
  properties: {
    dataLocation: dataLocation
    disableLocalAuth: false
    linkedDomains: [
      managedDomain.id
    ]
    publicNetworkAccess: 'Enabled'
  }
}

output communicationServiceName string = communicationService.name
output senderAddress string = 'DoNotReply@${managedDomain.properties.mailFromSenderDomain}'
