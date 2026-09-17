# Optional overrides for formulas/users, plus the accounts list itself.
# See CLAUDE.md "Established patterns" for the design: any formula needing
# a dedicated user appends its account(s) here instead of creating them
# locally with its own user.present state.
users:
  lookup:
    default_shell: /bin/bash
    sudo_group: sudo
    home_base: /home

  # One entry per account, merged across every pillar sls that sets this
  # key (requires pillar_merge_lists: True in master config — see
  # formulas/salt-master/config.sls). pillar/GLOBAL.sls adds one
  # self-named login account per minion via grains.id; service formulas
  # (e.g. homepage) add their own system accounts from pillar/<name>.sls.
  accounts:
    # Service account: no login, no password. The established pattern for
    # a formula that just needs a dedicated system user — the formula
    # itself does `require: - user: user-homepage`, never creates it.
    - name: homepage
      system: true
      shell: /usr/sbin/nologin
      home: /var/lib/homepage

    # Login account: sudo + an SSH key + a password sourced from OpenBao.
    # `password` MUST be an already-hashed value (sha512-crypt, as found
    # in /etc/shadow) — never a plaintext password, sdb-referenced or not.
    # See formulas/users/README.md for how the sdb:// reference resolves.
    - name: someminion
      password: "sdb://osvault/homelab/data/users/shared?password"
      sudo: true
      ssh_authorized_keys:
        - "ssh-ed25519 AAAA...replace-me... admin@laptop"

    # Optional per-account overrides available on any entry above:
    #   group: <name>       # defaults to the account name
    #   home: /custom/path  # defaults to <home_base>/<name>
    #   shell: /bin/zsh     # defaults to lookup.default_shell
    #   uid: 970            # pin instead of auto-assigning — needed when a
    #   gid: 970            # consuming formula's own map.jinja has to know
    #                       # this number too (e.g. a Docker PUID/PGID env
    #                       # var, or a docker_container.running `user:`
    #                       # param) — see formulas/arrstack for an example.
