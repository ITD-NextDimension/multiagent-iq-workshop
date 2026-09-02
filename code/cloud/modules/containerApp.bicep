// Reusable Azure Container App that pulls its image from ACR using the
// registry admin credentials (avoids the managed-identity AcrPull
// role-propagation race that causes "Operation expired" on first revision).
param name string
param location string
param environmentId string
param acrName string
param acrLoginServer string
param image string
param targetPort int = 8080
param external bool = true
param cpu string = '0.5'
param memory string = '1.0Gi'
param minReplicas int = 0
param maxReplicas int = 3
param env array = []

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = {
  name: acrName
}

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      ingress: {
        external: external
        targetPort: targetPort
        transport: 'auto'
      }
      secrets: [
        {
          name: 'acr-password'
          value: acr.listCredentials().passwords[0].value
        }
      ]
      registries: [
        {
          server: acrLoginServer
          username: acr.listCredentials().username
          passwordSecretRef: 'acr-password'
        }
      ]
    }
    template: {
      containers: [
        {
          name: name
          image: image
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: env
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

output fqdn string = app.properties.configuration.ingress.fqdn
output name string = app.name
