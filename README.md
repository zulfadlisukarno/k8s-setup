# k8s-setup

Bash scripts to provision a single-control-plane Kubernetes cluster on three virtual machines — one control plane (`server01`) and two worker nodes (`server02`, `server03`). Designed for local lab environments using **KVM** or **VirtualBox**.

---

## Cluster Layout

| Role          | Hostname   | IP Address       |
|---------------|------------|------------------|
| Control Plane | `server01` | `192.168.122.10` |
| Worker        | `server02` | `192.168.122.11` |
| Worker        | `server03` | `192.168.122.12` |

- **Kubernetes version:** v1.32  
- **Container runtime:** containerd  
- **CNI plugin:** Flannel (`10.244.0.0/16`)

---

## Prerequisites

### Host machine
- KVM/QEMU or VirtualBox installed.

### Virtual machines (all three)
- **OS:** Ubuntu 22.04 / Debian 12 (or any `apt`-based distro).
- **vCPUs:** 2 minimum (control plane requires at least 2).
- **RAM:** 2 GB minimum per node.
- **Disk:** 20 GB minimum per node.
- **Static IP addresses** as listed in the table above.
- Root or `sudo` access.

---

## Network Setup

Each VM must have a **host-only** network interface with a static IP. This lets VMs reach each other and lets the host reach the cluster without exposing it to external networks.

### KVM (libvirt)

KVM's default `virbr0` network (`192.168.122.0/24`) is already a host-only-style bridge. The recommended way to assign static IPs is via **DHCP host reservations** in virt-manager, so the addresses are guaranteed at the hypervisor level without touching each VM's network config.

#### Using virt-manager (recommended)

1. Open **virt-manager** → **Edit → Connection Details → Virtual Networks** tab.
2. Select **default** → click the **XML** tab.
3. Inside the `<dhcp>` block, after the `<range ... />` line, add one `<host>` entry per VM with its MAC address, hostname, and desired IP:

```xml
<network connections="3">
  <name>default</name>
  <uuid>5c362d3c-a688-4583-9fe0-4766de493bd9</uuid>
  <forward mode="nat">
    <nat>
      <port start="1024" end="65535"/>
    </nat>
  </forward>
  <bridge name="virbr0" stp="on" delay="0"/>
  <mac address="52:54:00:1a:ee:63"/>
  <ip address="192.168.122.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.122.2" end="192.168.122.254"/>
      <host mac="52:54:00:47:c8:10" name="server01" ip="192.168.122.10"/>
      <host mac="52:54:00:89:89:f2" name="server02" ip="192.168.122.11"/>
      <host mac="52:54:00:71:87:55" name="server03" ip="192.168.122.12"/>
    </dhcp>
  </ip>
</network>
```

> Replace the `mac` values with the actual MAC addresses of each VM's network interface. You can find them in virt-manager under each VM's **NIC** hardware details.

4. Apply the change by restarting the virtual network:

```bash
virsh net-destroy default
virsh net-start default
```

> **Tip — run `virsh` without `sudo`:** By default `virsh` connects to the session URI (`qemu:///session`). To connect to the system URI automatically, add the following to `~/.config/libvirt/libvirt.conf` (create the file if it doesn't exist):
>
> ```
> uri_default = "qemu:///system"
> ```

5. Reboot (or `sudo dhclient`) each VM — they will now always receive the reserved IP from the hypervisor's DHCP.

#### Alternative: static IP inside the VM (netplan)

If you prefer to configure the IP inside the VM instead, edit `/etc/netplan/01-static.yaml` on each node:

```yaml
network:
  version: 2
  ethernets:
    enp1s0:
      addresses: [192.168.122.10/24]
      gateway4: 192.168.122.1
      nameservers:
        addresses: [8.8.8.8]
```

Run `sudo netplan apply` after saving. Adjust the interface name (`enp1s0`) and IP per node.

### VirtualBox

VirtualBox does **not** create a host-only network automatically — you must do this first:

1. Open **File → Host Network Manager** (or `vboxmanage hostonlyif create`).
2. Create a host-only adapter, e.g. `vboxnet0`, with:
   - **IPv4 address:** `192.168.122.1`
   - **Subnet mask:** `255.255.255.0`
   - **DHCP server:** disabled.
3. For each VM, go to **Settings → Network → Adapter 2**, set to **Host-only Adapter**, and select `vboxnet0`.
4. Inside each VM, configure a static IP on that interface (same netplan approach as above, targeting the second NIC).

> Keep Adapter 1 as NAT so VMs retain internet access for package downloads during setup.

---

## Scripts

| Script                       | Run on              | Purpose                                              |
|------------------------------|---------------------|------------------------------------------------------|
| `01-common-all-nodes.sh`     | All three nodes     | System prep, containerd, kubeadm/kubelet/kubectl     |
| `02-control-plane-server01.sh` | `server01` only   | `kubeadm init`, kubectl config, Flannel CNI          |
| `03-worker-nodes.sh`         | `server02`, `server03` | Join workers to the cluster                     |
| `04-verify-cluster.sh`       | `server01`          | Health check — nodes, pods, and a test nginx pod     |

---

## Step-by-Step Usage

### 1. Prepare all nodes

Run on **server01**, **server02**, and **server03**:

```bash
sudo bash 01-common-all-nodes.sh
```

This will:
- Add hostname entries to `/etc/hosts`.
- Disable swap.
- Load required kernel modules (`overlay`, `br_netfilter`).
- Apply sysctl networking parameters.
- Install and configure `containerd` with `SystemdCgroup`.
- Install and pin `kubeadm`, `kubelet`, and `kubectl` (v1.32).

### 2. Initialize the control plane

Run on **server01** only:

```bash
sudo bash 02-control-plane-server01.sh
```

This will:
- Run `kubeadm init` with the control plane IP and Flannel pod CIDR.
- Copy `admin.conf` to the invoking user's `~/.kube/config`.
- Deploy the Flannel CNI.
- Print the **`kubeadm join`** command — **copy it**, you will need it in the next step.

### 3. Join worker nodes

Run on **server02** and **server03**:

```bash
sudo bash 03-worker-nodes.sh
```

When prompted, paste the `kubeadm join` command printed at the end of step 2.

### 4. Verify the cluster

Run on **server01**:

```bash
sudo bash 04-verify-cluster.sh
```

Expected output shows all three nodes in `Ready` state, all `kube-system` and `kube-flannel` pods running, and a test nginx pod scheduled successfully.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Nodes stuck in `NotReady` | Flannel pods not running | Check `kubectl get pods -n kube-flannel`; ensure pod CIDR matches `10.244.0.0/16` |
| `kubeadm join` fails with TLS error | Token expired (24 h TTL) | Regenerate with `kubeadm token create --print-join-command` on server01 |
| VMs cannot reach each other | Static IP not applied | Verify `ip addr` shows the expected IP on the host-only interface |
| `containerd` not starting | Missing kernel modules | Run `modprobe overlay br_netfilter` and recheck `systemctl status containerd` |

---

## Customization

To use a different IP range, edit the following before running the scripts:

- **`01-common-all-nodes.sh`** — update the `/etc/hosts` block with your actual IPs.
- **`02-control-plane-server01.sh`** — update `CONTROL_PLANE_IP` and `POD_CIDR`.
- Match `POD_CIDR` to the Flannel manifest you apply (default is `10.244.0.0/16`).
