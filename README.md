# self-hosted-runners

```yaml
# Set in PVE CT config
unprivileged: 0
lxc.cgroup2.devices.allow: c 10:232 rwm
lxc.mount.entry: /dev/kvm dev/kvm none bind,create=file 0 0
```

```bash
# Set .env and then...
./run.sh
```
