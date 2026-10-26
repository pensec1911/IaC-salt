{#- Reactor SLS (not a state) — wired up in /etc/salt/master.d/reactor.conf
   by formulas/salt-master. Fired by salt-api when the git server (Forgejo)
   posts a push to /hook/git; `data` is {body: <raw>, post: <parsed JSON>,
   headers: {...}}. The hook needs no Salt auth, so the signature is the
   only proof of the sender: X-Hub-Signature-256 = sha256=<HMAC of the raw
   body with homelab_git_hmac_secret>. Missing, malformed or wrong:
   nothing happens.

   Only a push to the deployed branch counts. Then the gitfs fetch runs
   now instead of at the next poll; its update event (changed = True)
   starts the push deploy (reactor/gitfs-update.sls, orch.push) as before.
   The payload itself is never used beyond the ref. #}
{%- set expected = opts.get('homelab_git_hmac_secret', '') %}
{%- set sig = data.get('headers', {}).get('X-Hub-Signature-256', '') %}
{%- set ref = 'refs/heads/' ~ opts.get('gitfs_base', 'main') %}
{%- if expected and sig.startswith('sha256=')
      and salt['hashutil.github_signature'](data.get('body', ''), expected, sig)
      and data.get('post', {}).get('ref') == ref %}
git-push-fetch:
  runner.fileserver.update: []
{%- endif %}
