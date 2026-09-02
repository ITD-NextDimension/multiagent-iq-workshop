# Web frontend image (runs on Azure Container Apps).
# Serves the static chat UI and proxies /ask, /charts, /health to the agents
# backend (AGENTS_BACKEND_URL is substituted at container start by nginx).
# Build context = repository root.
FROM nginx:alpine

COPY app /usr/share/nginx/html
COPY cloud/nginx/default.conf.template /etc/nginx/templates/default.conf.template

# Overridden by the container app env at deploy time (points at the AKS agents ingress).
ENV AGENTS_BACKEND_URL=http://127.0.0.1:9
EXPOSE 80
