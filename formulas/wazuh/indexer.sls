{% from "wazuh/map.jinja" import wazuh with context %}
{%- set node_dn = wazuh.indexer.get('node_dn') or 'CN=' ~ wazuh.indexer.node_name ~ ',OU=Wazuh,O=Wazuh,L=California,C=US' %}

include:
  - wazuh.certs

{#- Merge only the keys Wazuh's guide says to edit into the package-shipped
   opensearch.yml — it also carries path.data/path.logs, the cert paths
   (certs/indexer.pem, matching certs.sls) and the security plugin defaults,
   all of which a full template would drop. node_dn defaults to the DN
   wazuh-certs-tool.sh issues; README "Bootstrap" checks it against the
   real cert. #}
wazuh-indexer-config:
  file.serialize:
    - name: /etc/wazuh-indexer/opensearch.yml
    - serializer: yaml
    - merge_if_exists: True
    - dataset:
        network.host: {{ wazuh.indexer.network_host | yaml_dquote }}
        node.name: {{ wazuh.indexer.node_name | yaml_dquote }}
        cluster.initial_master_nodes:
          - {{ wazuh.indexer.node_name | yaml_dquote }}
        plugins.security.nodes_dn:
          - {{ node_dn | yaml_dquote }}
    - user: wazuh-indexer
    - group: wazuh-indexer
    - mode: '0640'
    - require:
      - pkg: wazuh-indexer-package

wazuh-indexer-service:
  service.running:
    - name: wazuh-indexer
    - enable: True
    - require:
      - cmd: wazuh-indexer-certs
    - watch:
      - file: wazuh-indexer-config
