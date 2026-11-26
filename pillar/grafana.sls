{%- from 'edge-routes.jinja' import urls %}
{%- set oidc = urls['auth'] ~ '/application/o' %}
grafana:
  lookup:
    admin_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/grafana/admin?password') | yaml_encode }}
    # Login via Authentik (OIDC provider "grafana", formulas/authentik). Only
    # Authentik's admin group may log in there, so every login is Grafana
    # Admin. The local admin stays for emergencies:
    # https://grafana.<domain>/login?disableAutoLogin=true (or the IP).
    env:
      GF_SERVER_ROOT_URL: "{{ urls['grafana'] }}/"
      GF_AUTH_GENERIC_OAUTH_ENABLED: "true"
      GF_AUTH_GENERIC_OAUTH_NAME: Authentik
      GF_AUTH_GENERIC_OAUTH_CLIENT_ID: grafana
      GF_AUTH_GENERIC_OAUTH_SCOPES: openid profile email
      GF_AUTH_GENERIC_OAUTH_AUTH_URL: "{{ oidc }}/authorize/"
      GF_AUTH_GENERIC_OAUTH_TOKEN_URL: "{{ oidc }}/token/"
      GF_AUTH_GENERIC_OAUTH_API_URL: "{{ oidc }}/userinfo/"
      GF_AUTH_GENERIC_OAUTH_USE_PKCE: "true"
      GF_AUTH_GENERIC_OAUTH_ALLOW_SIGN_UP: "true"
      GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH: "'Admin'"
      GF_AUTH_SIGNOUT_REDIRECT_URL: "{{ oidc }}/grafana/end-session/"
      GF_AUTH_OAUTH_AUTO_LOGIN: "true"
    secret_env:
      GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET: {{ salt['sdb.get']('sdb://osvault/homelab/data/authentik/oidc-grafana?client_secret') | yaml_encode }}

  # Fixed uids so dashboards/links can reference them. Grafana runs in its
  # own container, so the host IP rather than localhost.
  datasources:
    - name: Prometheus
      uid: prometheus
      type: prometheus
      access: proxy
      url: http://192.168.178.25:9090
      isDefault: true
    - name: Alertmanager
      uid: alertmanager
      type: alertmanager
      access: proxy
      url: http://192.168.178.25:9093
      jsonData:
        implementation: prometheus
    # Logs (formulas/loki), shipped by formulas/alloy on the docker hosts.
    - name: Loki
      uid: loki
      type: loki
      access: proxy
      url: http://192.168.178.25:3100

  # grafana.com dashboards, pinned. To bump: new revision + its sha256
  # (curl -sL <dashboards_source> | sha256sum).
  dashboards:
    - name: node-exporter-full
      gnet_id: 1860
      revision: 45
      sha256: 184c6b7409f306da75525d7772f71945b10cea23ad16b5d78c4698ea0ea51986
    - name: cadvisor
      gnet_id: 19792
      revision: 6
      sha256: 96348d7c68e6d29ced3ba9a8da4358b8605be6815be52daf6d8be85a44f94971
