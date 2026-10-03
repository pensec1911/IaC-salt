salt-master:
  lookup:
    # Not secret — the AppRole role_id from OpenBao. See
    # todo/openbao-setup.md. secret_id (the actual credential) is a file
    # placed manually on the master, never pillar/git — see
    # formulas/salt-master/README.md "OpenBao AppRole".
    vault_role_id: "c0474c8f-8299-707f-c47e-ee49ffced87c"

    # Address the salt-master itself reaches OpenBao on — map.jinja's
    # default is a placeholder (vault.example.internal), so this must be
    # set here or AppRole auth never gets off the ground.
    vault_addr: "https://192.168.178.20:8200"

    # OpenBao's TLS cert — self-signed, so no system trust store knows it
    # and Salt needs it explicitly, or the handshake fails in a way that
    # looks like an auth error. Public data, hence plain in git (not an
    # sdb:// reference). SANs include IP 192.168.178.20, which is what
    # vault_addr connects to — a cert without that SAN can't be verified
    # by IP at all, regardless of trust. Expires 2031-10-02.
    vault_ca_cert: |
      -----BEGIN CERTIFICATE-----
      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
      dspgEA==
      -----END CERTIFICATE-----
