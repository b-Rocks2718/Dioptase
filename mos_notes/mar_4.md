# MOS Notes 3/4

## Preemption
isr just sets `need_resched` flag, scheduler called outside isr

core pinning can be preferable to disabling preemption in some cases (core pinning still allows you to block)



