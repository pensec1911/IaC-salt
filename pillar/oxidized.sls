{#- Oxidized on monitoring (formulas/oxidized): pulls network device configs
   hourly and pushes every change to the private Forgejo repo
   homelab/network-configs. Devices and the enable switch come from
   pillar/oxidized.jinja — nothing renders until the Forgejo deploy key and
   at least one device key are in OpenBao. #}
{%- from 'oxidized.jinja' import oxidized with context %}
{%- if oxidized.enabled %}
oxidized:
  lookup:
    enabled: True
    host_port: {{ oxidized.host_port }}
    remote_repo: ssh://git@192.168.178.29:2222/homelab/network-configs.git
    # Deploy key with write access on homelab/network-configs (README
    # "Forgejo repo"). Legacy PEM RSA — Rugged/libssh2 needs that format.
    forgejo_key: {{ oxidized.forgejo_key | yaml_encode }}
    forgejo_key_pub: {{ oxidized.forgejo_key_pub | yaml_encode }}
    # Forgejo's built-in SSH server (forgejo .29:2222), same key as in
    # pillar/salt-master.sls — /opt/forgejo/data/ssh/gitea.rsa.pub, matched
    # against ssh-keyscan 2026-11-14. Public data.
    known_hosts:
      - host: 192.168.178.29
        port: 2222
        enc: ssh-rsa
        key: AAAAB3NzaC1yc2EAAAADAQABAAACAQC8ekmTEyT42SZmnQL+fR443nsym87XYrjkgyv6+VWzHIKFZ0fBXQ0JOHb1JyhRrPun7iUmfrJB+XQ6XmM3Zk1YoziUnDli3KP6kde6Dx5a99V64A1V6kAikiHJiVoc2MRi7BKrwzBvqNaez1CgncqAzJRxAaahdai38ZOPqx9e0V2Ogol7nPjYi/3jvknX/w1hIeOWl4WQjvN6Okg9Vyiw9qVWcHutCt2LxcIpiLzwEe4bPNMW3zuYDS3asJe2H4AbgB/M2vGm+iA8yvlxAhWfWAycRaxgOH6OvmmTl9G2ML/1wmYBtdRMm1fHutQAYS98Uus0jrhoE0zeWrNJzqmCsEyUYz1MxZTywoBJzf4A6OniKB3CZzak7ob82p6JVPPeqB3ch68zOOulKSfOsm2iNcpsECrc4ebaWoYXfDZCNPsBrrDjjyACBARqdgH2yNuifzc+3TAxfI42Gg7EXUht8s0O196JZjAgnyVjvNMHyvytf6VhqKMfNiiLkyPVnVf0Pv2qK3GTdMiFvPFZB9n0yNJHh16JDcQLoUZ3kcgS6GgqtPbaWy73qexVU0wVjVvxV2IwO8zzhAzBrKgGAypqfezfqGREb83Qu1eqQn15EWC3/sOFOMCnccjZzoB23ebbOEd7l/ao8HCXUanogKt2VPfS8cixHfLgyam2+yNrAQ==
    devices:
{%- for name, d in oxidized.devices | dictsort %}
      {{ name }}:
        model: {{ d.model }}
        host: {{ d.host }}
        port: {{ d.port }}
        username: {{ d.username }}
        host_key:
          enc: {{ d.host_key.enc }}
          key: {{ d.host_key.key }}
        ssh_key: {{ d.ssh_key | yaml_encode }}
{%- endfor %}

{#- Fetch check for pillar/prometheus.sls' `oxidized` job: oxidized-web's
   /nodes.json carries each device's last status; the probe fails while any
   device's last fetch failed (no_connection / fail). "never" (not yet
   fetched) passes. #}
blackbox-exporter:
  lookup:
    modules:
      oxidized_nodes_ok:
        prober: http
        timeout: 10s
        http:
          preferred_ip_protocol: ip4
          valid_status_codes: [200]
          fail_if_body_matches_regexp:
            - '"status": ?"(fail|no_connection)"'
{%- endif %}
