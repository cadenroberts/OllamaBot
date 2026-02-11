# Plan: Example Read Tools Implementation
policy: accrue_all_ideas=true, no_refactor=true

- [ ] id=learn.entrypoints lane=1 payload=@cmd:echo "scanning entrypoints..."
- [ ] id=learn.deps lane=1 payload=@doc:LLM_TASK review go.mod and identify dependencies
- [ ] id=code.readtools lane=2 deps=learn.entrypoints,learn.deps payload=@file:docs/code_runtime/specs/readtools.diff
- [ ] id=code.adapters lane=2 deps=code.readtools payload=@file:docs/code_runtime/specs/adapters.diff
- [ ] id=test.readtools lane=3 deps=code.readtools payload=@cmd:echo "tests would run here"
- [ ] id=test.adapters lane=3 deps=code.adapters,test.readtools payload=@cmd:echo "adapter tests would run here"
- [ ] id=verify.all lane=3 deps=test.readtools,test.adapters payload=@cmd:echo "all verified"
