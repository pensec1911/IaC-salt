{#- formulas/ntp, every minion: the FRITZ!Box is the one time source (it
   answers NTP on its LAN address, stratum 2). No fallback — see the
   formula README. #}
{#- cloud-edge (OCI) can't reach the FRITZ!Box (gateway forwards no NTP
   through the tunnel) and uses Oracle's link-local NTP instead. Here and not
   in pillar/cloud-edge.sls: pillar_merge_lists would append it to the
   FRITZ!Box instead of replacing it. #}
{%- set servers = {'cloud-edge': ['169.254.169.254']}.get(grains['id'], ['192.168.178.1']) %}
ntp:
  lookup:
    servers: {{ servers | json }}
    fallback_servers: []
