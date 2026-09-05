// Lab 05-1 · 资源受限路线：只部署学员自己的 Web Container App。
//
// 与 main.bicep 的区别：main.bicep 建一整套（AKS、ACR、会话池、ACS、监控），
// 这里全部复用讲师预置的共享资源，学员只新建一个 Container App。
// 所有 `existing` 资源都必须已经由讲师创建好。
targetScope = 'resourceGroup'

@description('共享 Container Apps 环境所在区域。')
param location string = resourceGroup().location

@description('学员自己的 Web Container App 名称，需在资源组内唯一。')
@minLength(3)
@maxLength(32)
param webAppName string

@description('讲师预置的共享 Container Apps 环境名称。')
param containerAppsEnvironmentName string

@description('讲师预置的共享 ACR 登录服务器，例如 myregistry.azurecr.io。')
param acrLoginServer string

@description('讲师预置的、拥有 AcrPull 权限的用户分配托管身份名称。')
param registryIdentityName string

@description('讲师预置的 Web 镜像标签。')
param webImageTag string = 'workshop'

@description('共享 AKS 上 Agent API 的地址，供 nginx 反向代理使用。')
param agentsBackendUrl string

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' existing = {
  name: containerAppsEnvironmentName
}

resource registryIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: registryIdentityName
}

resource webApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: webAppName
  location: location
  identity: {
    // 用托管身份拉镜像，学员不需要 ACR 管理员用户名密码。
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${registryIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
        allowInsecure: false
      }
      registries: [
        {
          server: acrLoginServer
          identity: registryIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'web'
          image: '${acrLoginServer}/opc-app:${webImageTag}'
          env: [
            {
              // nginx 用它把 /ask、/charts、/send-email 反代到共享 AKS。
              name: 'AGENTS_BACKEND_URL'
              value: agentsBackendUrl
            }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        // 本实验的资源边界：不用时缩到 0，最多 1 个副本。
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

output WEB_APP_NAME string = webApp.name
output WEB_APP_URL string = 'https://${webApp.properties.configuration.ingress.fqdn}'
output WEB_APP_IMAGE string = webApp.properties.template.containers[0].image
output AGENTS_BACKEND_URL string = agentsBackendUrl
