{% from "users/map.jinja" import users with context %}
{%- for account in salt['pillar.get']('users:accounts', []) %}

group-{{ account.name }}:
  group.present:
    - name: {{ account.get('group', account.name) }}
    - system: {{ account.get('system', False) }}

user-{{ account.name }}:
  user.present:
    - name: {{ account.name }}
    - home: {{ account.get('home', users.home_base ~ '/' ~ account.name) }}
    - shell: {{ account.get('shell', users.default_shell) }}
    - system: {{ account.get('system', False) }}
    - gid: {{ account.get('group', account.name) }}
    - groups:
      - {{ account.get('group', account.name) }}
      {%- if account.get('sudo') %}
      - {{ users.sudo_group }}
      {%- endif %}
    {%- if account.get('password') %}
    - password: {{ account.password }}
    {%- endif %}
    - require:
      - group: group-{{ account.name }}
{%- for key in account.get('ssh_authorized_keys', []) %}

ssh-auth-{{ account.name }}-{{ loop.index }}:
  ssh_auth.present:
    - user: {{ account.name }}
    - name: {{ key }}
    - require:
      - user: user-{{ account.name }}
{%- endfor %}
{%- endfor %}
