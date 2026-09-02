// =============================================================================
// OPC Multi-Agent IQ - unified Bicep deployment (resource-group scope).
//
// Provisions, in the existing resource group:
//   - Log Analytics workspace           (monitoring)
//   - Azure Container Registry          (images)
//   - Azure Container Apps environment  (hosts the ACA workloads below)
//   - ACA app: web app (frontend)       -> "app on Azure Container Apps"
//   - ACA app: mcp + dataIQ (HTTP MCP)  -> "dataIQ and MCP on Azure Container Apps"
//   - ACA session pool (sandbox)        -> "agents' sandbox node" (dynamic sessions)
//   - AKS cluster                       -> runs the agents workload (k8s manifests)
//
// Deploy:  az deployment group create -g rg-multiagent-iq -f main.bicep -p main.bicepparam
// (Build & push images first; see scripts/deploy.sh.)
// =============================================================================
targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = 'swedencentral'

@description('Name of the AKS cluster.')
param aksName string = 'aks-iq-aks-agent-hol'

@description('Short prefix used to name resources.')
param namePrefix string = 'opciq'

@description('Globally-unique ACR name (lowercase alphanumeric). Provided by deploy.sh.')
param acrName string

@description('Container image tag to deploy.')
param imageTag string = 'latest'

@description('Backend URL the web app proxies /ask and /charts to (the AKS agents ingress). Updated by deploy.sh after AKS is up.')
param appBackendUrl string = 'http://127.0.0.1:9'

@description('Existing Azure AI Foundry / Cognitive Services account the agents call (granted to the AKS workload identity).')
param foundryAccountName string = 'my-ai-foundry'

var lawName = '${namePrefix}-logs'
var acaEnvName = '${namePrefix}-aca-env'
var sessionPoolName = '${namePrefix}sandbox'
var webAppName = '${namePrefix}-app'
var mcpAppName = '${namePrefix}-mcp-dataiq'
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var agentsIdentityName = '${namePrefix}-agents-identity'

// ---- Monitoring -------------------------------------------------------------
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    name: lawName
    location: location
  }
}

// ---- Azure Communication Services Email ------------------------------------
module communicationEmail 'modules/communicationEmail.bicep' = {
  name: 'communication-email'
  params: {
    namePrefix: namePrefix
  }
}

// ---- Container registry -----------------------------------------------------
module registry 'modules/registry.bicep' = {
  name: 'registry'
  params: {
    name: acrName
    location: location
  }
}

// ---- Container Apps environment --------------------------------------------
module acaEnv 'modules/containerAppsEnv.bicep' = {
  name: 'aca-env'
  params: {
    name: acaEnvName
    location: location
    logAnalyticsCustomerId: monitoring.outputs.customerId
    logAnalyticsSharedKey: monitoring.outputs.primarySharedKey
  }
}

// ---- ACA session pool (the sandbox node) -----------------------------------
module sandbox 'modules/sessionPool.bicep' = {
  name: 'sandbox'
  params: {
    name: sessionPoolName
    location: location
    environmentId: acaEnv.outputs.id
  }
}

// ---- ACA app: MCP + dataIQ (HTTP MCP service) ------------------------------
module mcpApp 'modules/containerApp.bicep' = {
  name: 'mcp-dataiq'
  params: {
    name: mcpAppName
    location: location
    environmentId: acaEnv.outputs.id
    acrName: registry.outputs.name
    acrLoginServer: registry.outputs.loginServer
    image: '${registry.outputs.loginServer}/opc-mcp-dataiq:${imageTag}'
    targetPort: 8080
    external: true
    minReplicas: 1
    maxReplicas: 2
    env: [
      { name: 'MCP_TRANSPORT', value: 'streamable-http' }
      { name: 'PORT', value: '8080' }
    ]
  }
}

// ---- ACA app: web frontend --------------------------------------------------
module webApp 'modules/containerApp.bicep' = {
  name: 'web-app'
  params: {
    name: webAppName
    location: location
    environmentId: acaEnv.outputs.id
    acrName: registry.outputs.name
    acrLoginServer: registry.outputs.loginServer
    image: '${registry.outputs.loginServer}/opc-app:${imageTag}'
    targetPort: 80
    external: true
    minReplicas: 1
    maxReplicas: 3
    env: [
      { name: 'AGENTS_BACKEND_URL', value: appBackendUrl }
    ]
  }
}

// ---- AKS cluster (runs the agents workload) --------------------------------
module aks 'modules/aks.bicep' = {
  name: 'aks'
  params: {
    name: aksName
    location: location
    logAnalyticsWorkspaceId: monitoring.outputs.id
  }
}

// ---- Workload identity for the agents pod (Entra ID auth, no API key) -------
module agentsIdentity 'modules/identity.bicep' = {
  name: 'agents-identity'
  params: {
    name: agentsIdentityName
    location: location
    oidcIssuerUrl: aks.outputs.oidcIssuerUrl
    foundryAccountName: foundryAccountName
  }
}

// Allow the AKS kubelet identity to pull agent images from ACR.
resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: acrName
}

resource aksAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, aksName, acrPullRoleId)
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: aks.outputs.kubeletObjectId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    registry
  ]
}

// ---- Outputs ----------------------------------------------------------------
output acrLoginServer string = registry.outputs.loginServer
output acrName string = registry.outputs.name
output aksClusterName string = aks.outputs.name
output webAppUrl string = 'https://${webApp.outputs.fqdn}'
output mcpUrl string = 'https://${mcpApp.outputs.fqdn}'
output sessionPoolEndpoint string = sandbox.outputs.poolManagementEndpoint
output agentsImage string = '${registry.outputs.loginServer}/opc-agents:${imageTag}'
output agentsIdentityClientId string = agentsIdentity.outputs.clientId
output communicationServiceName string = communicationEmail.outputs.communicationServiceName
output communicationEmailSenderAddress string = communicationEmail.outputs.senderAddress
