{#- Only the timer is a state. The orchestrate SLS files (orch.reboot,
   orch.rollout) run
   on the master via salt-run state.orchestrate and are never included. #}
include:
  - orch.timer
