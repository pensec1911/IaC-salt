{#- Offline runner registration: the same 40-hex secret on both sides
   (forgejo:lookup:runners + forgejo-runner:lookup:secret). #}
{%- set runner_secret = salt['sdb.get']('sdb://osvault/homelab/data/forgejo/runner?secret') %}
{%- from 'edge-routes.jinja' import edge, urls %}
users:
  accounts:
    # Pinned uid/gid — the rootless container runs as it via a docker
    # `user:` override. Must match forgejo:lookup:uid/gid below. Named "git",
    # not "forgejo": that's the minion's own login account (pillar/GLOBAL.sls).
    - name: git
      system: true
      shell: /usr/sbin/nologin
      home: /var/lib/git
      uid: 972
      gid: 972
    # Pinned for the runner container (`user:` override, owns its data dir).
    # Must match forgejo-runner:lookup:uid/gid below.
    - name: forgejo-runner
      system: true
      shell: /usr/sbin/nologin
      home: /var/lib/forgejo-runner
      uid: 973
      gid: 973

forgejo:
  lookup:
    uid: 972
    gid: 972
    app_ini:
      # Web under its name behind Caddy (links, clone URLs over https, OAuth
      # callback). SSH stays on the IP: gitfs (pillar/salt-master.sls) and
      # every local remote use ssh://git@192.168.178.29:2222. The IP:3000
      # still answers (webhooks, runner registration, emergency access).
      server:
        DOMAIN: git.{{ edge.domain }}
        SSH_DOMAIN: 192.168.178.29
        ROOT_URL: {{ urls['git'] }}/
      # Push webhooks to salt-api on the master (formulas/salt-master) —
      # Forgejo only delivers to private IPs that are listed.
      webhook:
        ALLOWED_HOST_LIST: 192.168.178.28
    # Login via Authentik (OIDC provider "forgejo", formulas/authentik). An
    # existing local account is linked on the first OAuth login (sign in
    # with its password once); members of Authentik's admin group are
    # Forgejo admins. Registration stays off.
    oauth_sources:
      authentik:
        key: forgejo
        secret: {{ salt['sdb.get']('sdb://osvault/homelab/data/authentik/oidc-forgejo?client_secret') | yaml_encode }}
        discovery_url: {{ urls['auth'] }}/application/o/forgejo/.well-known/openid-configuration
        group_claim: groups
        admin_group: authentik Admins
        skip_local_2fa: true
    # Scope homelab: the runner only takes jobs from the org's repos.
    runners:
      forgejo:
        scope: homelab
        secret: {{ runner_secret | yaml_encode }}
    # salt-api's self-signed cert (formulas/salt-master README "salt-api
    # TLS", SAN IP 192.168.178.28, expires 2031-10-25) — the push webhook
    # to /hook/git verifies against it. Public data; same PEM as in
    # pillar/alertmanager.sls, re-issued: paste the new one in both.
    extra_ca_certs:
      salt-api: |
        -----BEGIN CERTIFICATE-----
        MIIBsDCCAVagAwIBAgIUaSoGYkucZnJssbEDf/GQcCEFCM4wCgYIKoZIzj0EAwIw
        JTEQMA4GA1UECgwHaG9tZWxhYjERMA8GA1UEAwwIc2FsdC1hcGkwHhcNMjYxMDI2
        MTI0MTE0WhcNMzExMDI1MTI0MTE0WjAlMRAwDgYDVQQKDAdob21lbGFiMREwDwYD
        VQQDDAhzYWx0LWFwaTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABEhiYHcdChtl
        CFUnk9UR0BmLEn2ZBtNlXky1wZRuiq4zE+W770w6lnlpy8J2SsEPZMwZ7k8jzuMQ
        sk8/z2+K9bujZDBiMB0GA1UdDgQWBBRtKiKSuJBgjpCp/2+OncHETVnOvzAfBgNV
        HSMEGDAWgBRtKiKSuJBgjpCp/2+OncHETVnOvzAPBgNVHREECDAGhwTAqLIcMA8G
        A1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDSAAwRQIhAPYFoMyEuLMYHXushxT6
        W7CoeJ9ETeaO2h0cQeXqXn0DAiAyW8FoTWHOeKjOKx4sfijvJalZtsa5VXBNnx+Q
        iIUfNg==
        -----END CERTIFICATE-----

forgejo-runner:
  lookup:
    uid: 973
    gid: 973
    instance_url: http://192.168.178.29:3000/
    secret: {{ runner_secret | yaml_encode }}
    # Job containers (inside dind) checkout from ROOT_URL = git.<edge domain>;
    # dind's DNS is public, where Porkbun's wildcard answers — pin it to edge.
    job_options: "--add-host=git.{{ edge.domain }}:{{ edge.ip }}"
