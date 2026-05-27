# AMIBIOS DMI Update Driver

**Language / Idioma:** [🇺🇸 English](README.md) | [🇧🇷 Português](README.pt-BR.md)

![Language: C](https://img.shields.io/badge/Language-C-blue) 
![License: GPLv2](https://img.shields.io/badge/License-GPLv2-green) 
![Platform: Linux](https://img.shields.io/badge/Platform-Linux-orange)

A Linux kernel module to update DMI/SMBIOS information in AMI BIOS via System Management Interrupt (SMI) calls.

This is a **maintained fork** of the original work by [Claudio Matsuoka](https://github.com/cmatsuoka/amibios_dmi) (2013), updated to support modern enterprise hardware and Linux kernels where the original driver fails to compile or load.

---

## 🎯 Why This Fork?

The original `amibios_dmi` was written for AMI BIOS with SMBIOS 2.4–2.8 and older Linux kernels (circa 2013). In modern environments, it fails with:

| Error | Cause | Fix in this fork |
|-------|-------|-----------------|
| `unsupported SMBIOS version` | Hardcoded check for SMBIOS 2.4–2.8; modern AMI Aptio V uses SMBIOS 3.0 | Expanded version validation to accept SMBIOS 2.0+ through 3.x |
| `__write_overflow` (FORTIFY_SOURCE) | `strcpy()` without bounds checking on kernel 5.14+ / 6.4+ | Replaced with `memcpy()` + explicit null termination |
| `No such file or directory` during build | Deprecated `SUBDIRS=$(PWD)` in Makefile | Updated to modern `M=$(shell pwd)` out-of-tree build directive |
| `Invalid module format` | Module compiled on different kernel version | Documented per-kernel compilation requirement |

---

## 🧪 Tested Environment

This fork was validated in a **production scenario**:

| Component | Details |
|-----------|---------|
| **Motherboard** | Gigabyte GA-H110TN-M (customized by PERTO SA) |
| **BIOS** | American Megatrends Inc. F23, Aptio V |
| **SMBIOS Version** | 3.0.0 |
| **Operating Systems** | SUSE Linux Enterprise Server (SLES) 12 SP5, 15 SP5, 15 SP6, 15 SP7 |
| **Kernels** | 5.14.21-150500.x (SLES 15 SP5), 6.4.0-150700.x (SLES 15 SP7) |
| **Use Case** | Remote correction of `chassis-asset-tag` and `baseboard-asset-tag` fields left as "Default string" by manufacturer |

---

## 🚀 Changes from Original

### 1. SMBIOS 3.0+ Compatibility (`amibios_smi.c`)
```c
// Original (rejected SMBIOS 3.0):
if (amibios_data-&gt;info.version &lt; 0x24 || amibios_data-&gt;info.version &gt; 0x28)

// This fork (accepts 2.0 through 3.x):
if (amibios_data-&gt;info.version &lt; 0x20) {
    pr_err("amibios_dmi: unsupported SMBIOS version (too old): 0x%04x\n", ...);
    goto err2;
} else if (amibios_data-&gt;info.version &gt; 0x0300) {
    pr_warn("amibios_dmi: very new SMBIOS version 0x%04x - proceeding anyway\n", ...);
}
```


### 2. FORTIFY_SOURCE Compliance (amibios_smi.c)
```c
// Original (kernel 6.4 panics with __write_overflow):
strcpy(amibios_data->write.data.data.raw + 4, s);

// This fork (bounds-checked):
size_t len = strlen(s);
if (len >= sizeof(amibios_data->write.data.data.raw) - 4) {
    len = sizeof(amibios_data->write.data.data.raw) - 5;
}
memcpy(amibios_data->write.data.data.raw + 4, s, len);
amibios_data->write.data.data.raw[4 + len] = '\0';
```

### 3. Modern Build System (Makefile)
```makefile
# Original (deprecated, fails on SLES 15):
make -C $(KERNEL) SUBDIRS=$(PWD) $@

# This fork (works with kernel 5.14+ and 6.4+):
make -C $(KERNEL) M=$(shell pwd) $@
```

---

## ⚙️ Requirements

| Package        | SUSE (zypper)          | Purpose                             |
| -------------- | ---------------------- | ----------------------------------- |
| Kernel headers | `kernel-default-devel` | Module compilation                  |
| Build tools    | `gcc`, `make`          | Compilation                         |
| Optional       | `dkms`                 | Automatic rebuild on kernel updates |

**Note:** Kernel modules must be compiled for the exact running kernel version. A module built on SLES 15 SP5 (kernel 5.14.x) will not load on SLES 15 SP7 (kernel 6.4.x). Plan per-SP compilation or use DKMS for heterogeneous fleets.

---

## 🛠️ Building
```bash
# 1. Clone
git clone https://github.com/mariosergiosl/amibios_dmi.git
cd amibios_dmi

# 2. Ensure kernel headers match running kernel
uname -r
# Example output: 6.4.0-150700.53.52-default

# 3. On SLES, prepare build environment if needed
sudo zypper in -y kernel-default-devel kernel-syms kernel-source
cd /lib/modules/$(uname -r)/build
sudo make modules_prepare

# 4. Compile
cd /path/to/amibios_dmi
make clean && make
```

---

## 📋 Usage
```bash
# Load module
sudo insmod amibios_dmi.ko

# Check for device nodes
ls -l /dev/dmi*
# Expected: /dev/dmi_read, /dev/dmi_write

# Check kernel log for success
sudo dmesg | tail -10
# Expected: "amibios_dmi: SMBIOS version 0x0300 accepted"

# Read current Chassis Asset Tag
cat /sys/firmware/amibios/chassis/asset_tag

# Write new Chassis Asset Tag
echo "ASSET-123" | sudo tee /dev/dmi_write

# Verify change
cat /sys/firmware/amibios/chassis/asset_tag

# Verify with dmidecode (independent of module)
sudo dmidecode -s chassis-asset-tag
sudo dmidecode -s baseboard-asset-tag
sudo dmidecode -s system-serial-number

# Unload module (sysfs interfaces disappear, but DMI data persists in BIOS)
sudo rmmod amibios_dmi
```

---

# 🏭 Enterprise Deployment Notes
For fleets with mixed SLES versions:
*   **Per-kernel compilation:** Build amibios_dmi.ko separately for each kernel version in your fleet.
*   **DKMS packaging:** Create a DKMS package for automatic rebuild on kernel updates.
*   **Remote execution:** The module runs entirely in Linux — no reboot or UEFI Shell required. Ideal for SSH-based automation (Ansible, Salt, custom scripts).
*   **Persistence test:** Always verify that written values survive a reboot before fleet deployment. Some AMI implementations may not persist SMI-written DMI data.

---

# ⚠️ Risks & Limitations

| Risk                                                   | Mitigation                                                                                   |
| ------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| BIOS does not persist SMI-written data after reboot    | Test on 1 representative machine first; fallback to `AMIDEEFIx64.EFI` via one-shot UEFI boot |
| SMI handler rejects command (incompatible protocol)    | Check `dmesg` for SMI error codes; do not retry blindly                                      |
| Kernel module compilation fails on new kernel versions | Update `Makefile` or headers; this fork targets kernels 5.14–6.4.x                           |
| Data written to wrong DMI field                        | Verify with `dmidecode -t <type>` before and after; recoverable by rewriting                 |

**Critical:** This driver writes directly to BIOS-managed SMBIOS tables via SMI. While the SMI handler is designed to reject invalid commands, always test on non-production hardware first. The authors are not responsible for bricked systems or voided warranties.

---


# SLES 12 SP5 Troubleshooting

## Kernel Version Mismatch

### Error
```
$ sudo insmod amibios_dmi.ko 
insmod: ERROR: could not insert module amibios_dmi.ko: Invalid module format
```

### Cause
Module was compiled on SLES 15 SP5 (kernel 5.14.x) and is being loaded on SLES 12 SP5 (kernel 4.12.14-150.48-default).

### Solution
Recompile on SLES 12 SP5:
```bash
# On SLES 12 SP5
sudo zypper in -y kernel-default-devel kernel-syms kernel-source
cd /lib/modules/$(uname -r)/build
sudo make modules_prepare

cd /path/to/amibios_dmi
make clean && make
sudo insmod amibios_dmi.ko
```

# 📜 License & Attribution
* Original copyright © 2013 Claudio Matsuoka
* Fork maintained by Mario Luz for modern enterprise deployment
* Released under the GPL v2 license
