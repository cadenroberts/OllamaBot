# Plan: Smoke Test
policy: accrue_all_ideas=false

- [ ] id=step1 lane=1 payload=@cmd:echo hello > /tmp/code_smoke.txt
- [ ] id=step2 lane=2 deps=step1 payload=@cmd:test -f /tmp/code_smoke.txt
- [ ] id=step3 lane=3 deps=step2 payload=@cmd:cat /tmp/code_smoke.txt
