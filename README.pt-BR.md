# AMIBIOS DMI Update Driver

**Idioma / Language:** [🇺🇸 English](README.md) | [🇧🇷 Português](README.pt-BR.md)

![Language: C](https://img.shields.io/badge/Language-C-blue) 
![License: GPLv2](https://img.shields.io/badge/License-GPLv2-green) 
![Platform: Linux](https://img.shields.io/badge/Platform-Linux-orange)
![SLES](https://img.shields.io/badge/Tested%20on-SLES%2012%20SP5%20%7C%2015%20SP5--SP7-73ba25)
![Kernel](https://img.shields.io/badge/Kernel-5.14%20%7C%206.4-blue)

Um modulo de kernel Linux para atualizar informacoes DMI/SMBIOS em BIOS AMI por meio de chamadas de System Management Interrupt (SMI).

Este e um **fork mantido** do trabalho original de [Claudio Matsuoka](https://github.com/cmatsuoka/amibios_dmi) (2013), atualizado para dar suporte a hardware corporativo moderno e a versoes recentes do kernel Linux, onde o driver original falha ao compilar ou ao carregar.

---

## 🎯 Por que este fork?

O `amibios_dmi` original foi escrito para BIOS AMI com SMBIOS 2.4 a 2.8 e kernels Linux mais antigos (por volta de 2013). Em ambientes modernos, ele falha com:

| Erro | Causa | Correcao neste fork |
|------|-------|---------------------|
| `unsupported SMBIOS version` | Verificacao fixa para SMBIOS 2.4 a 2.8; o AMI Aptio V moderno usa SMBIOS 3.0 | Validacao de versao ampliada para aceitar de SMBIOS 2.0 ate 3.x |
| `__write_overflow` (FORTIFY_SOURCE) | `strcpy()` sem verificacao de limites no kernel 5.14+ / 6.4+ | Substituido por `memcpy()` com terminacao nula explicita |
| `No such file or directory` durante o build | Diretiva obsoleta `SUBDIRS=$(PWD)` no Makefile | Atualizado para a diretiva moderna de build out-of-tree `M=$(shell pwd)` |
| `Invalid module format` | Modulo compilado em uma versao diferente de kernel | Requisito de compilacao por kernel documentado |

---

## 🧪 Ambiente testado

Este fork foi validado em um **cenario de producao**:

| Componente | Detalhes |
|------------|----------|
| **Placa-mae** | Gigabyte GA-H110TN-M (customizada pela PERTO SA) |
| **BIOS** | American Megatrends Inc. F23, Aptio V |
| **Versao do SMBIOS** | 3.0.0 |
| **Sistemas operacionais** | SUSE Linux Enterprise Server (SLES) 12 SP5, 15 SP5, 15 SP6, 15 SP7 |
| **Kernels** | 5.14.21-150500.x (SLES 15 SP5), 6.4.0-150700.x (SLES 15 SP7) |
| **Caso de uso** | Correcao remota dos campos `chassis-asset-tag` e `baseboard-asset-tag` deixados como "Default string" pelo fabricante |

---

## 🚀 Mudancas em relacao ao original

### 1. Compatibilidade com SMBIOS 3.0+ (`amibios_smi.c`)
```c
// Original (rejected SMBIOS 3.0):
if (amibios_data->info.version < 0x24 || amibios_data->info.version > 0x28)

// This fork (accepts 2.0 through 3.x):
if (amibios_data->info.version < 0x20) {
    pr_err("amibios_dmi: unsupported SMBIOS version (too old): 0x%04x\n", ...);
    goto err2;
} else if (amibios_data->info.version > 0x0300) {
    pr_warn("amibios_dmi: very new SMBIOS version 0x%04x - proceeding anyway\n", ...);
}
```


### 2. Conformidade com FORTIFY_SOURCE (`amibios_smi.c`)
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

### 3. Sistema de build moderno (`Makefile`)
```makefile
# Original (deprecated, fails on SLES 15):
make -C $(KERNEL) SUBDIRS=$(PWD) $@

# This fork (works with kernel 5.14+ and 6.4+):
make -C $(KERNEL) M=$(shell pwd) $@
```

---

## ⚙️ Requisitos

| Pacote          | SUSE (zypper)          | Finalidade                              |
| --------------- | ---------------------- | --------------------------------------- |
| Headers do kernel | `kernel-default-devel` | Compilacao do modulo                  |
| Ferramentas de build | `gcc`, `make`     | Compilacao                              |
| Opcional        | `dkms`                 | Reconstrucao automatica em atualizacoes de kernel |

**Observacao:** Os modulos de kernel precisam ser compilados para a versao exata do kernel em execucao. Um modulo construido no SLES 15 SP5 (kernel 5.14.x) nao sera carregado no SLES 15 SP7 (kernel 6.4.x). Planeje a compilacao por SP ou utilize DKMS para frotas heterogeneas.

---

## 🛠️ Compilacao
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

## 📋 Uso
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

# 🏭 Notas de implantacao corporativa
Para frotas com versoes mistas de SLES:
*   **Compilacao por kernel:** Construa o `amibios_dmi.ko` separadamente para cada versao de kernel da sua frota.
*   **Empacotamento DKMS:** Crie um pacote DKMS para reconstrucao automatica em atualizacoes de kernel.
*   **Execucao remota:** O modulo roda inteiramente no Linux, sem necessidade de reboot ou de UEFI Shell. Ideal para automacao via SSH (Ansible, Salt, scripts proprios).
*   **Teste de persistencia:** Sempre verifique se os valores gravados sobrevivem a um reboot antes da implantacao na frota. Algumas implementacoes AMI podem nao persistir dados DMI gravados via SMI.

---

# ⚠️ Riscos e limitacoes

| Risco                                                       | Mitigacao                                                                                       |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| A BIOS nao persiste dados gravados via SMI apos reboot       | Teste primeiro em 1 maquina representativa; alternativa via `AMIDEEFIx64.EFI` em boot UEFI unico |
| O handler de SMI rejeita o comando (protocolo incompativel)  | Verifique os codigos de erro de SMI no `dmesg`; nao repita as tentativas as cegas                |
| A compilacao do modulo de kernel falha em versoes novas      | Atualize o `Makefile` ou os headers; este fork mira os kernels 5.14 a 6.4.x                     |
| Dados gravados no campo DMI errado                           | Verifique com `dmidecode -t <type>` antes e depois; recuperavel por nova gravacao                |

**Critico:** Este driver grava diretamente nas tabelas SMBIOS gerenciadas pela BIOS via SMI. Embora o handler de SMI seja projetado para rejeitar comandos invalidos, sempre teste primeiro em hardware fora de producao. Os autores nao se responsabilizam por sistemas inutilizados (bricked) ou garantias anuladas.

---


# Solucao de problemas no SLES 12 SP5

## Incompatibilidade de versao de kernel

### Erro
```
$ sudo insmod amibios_dmi.ko 
insmod: ERROR: could not insert module amibios_dmi.ko: Invalid module format
```

### Causa
O modulo foi compilado no SLES 15 SP5 (kernel 5.14.x) e esta sendo carregado no SLES 12 SP5 (kernel 4.12.14-150.48-default).

### Solucao
Recompile no SLES 12 SP5:
```bash
# On SLES 12 SP5
sudo zypper in -y kernel-default-devel kernel-syms kernel-source
cd /lib/modules/$(uname -r)/build
sudo make modules_prepare

cd /path/to/amibios_dmi
make clean && make
sudo insmod amibios_dmi.ko
```

# 📜 Licenca e atribuicao
* Copyright original © 2013 Claudio Matsuoka
* Fork mantido por Mario Luz para implantacao corporativa moderna
* Distribuido sob a licenca GPL v2
