# Azure NixOS server

`ryra/azure` starts with the Ryra server template and adds Hyper-V storage/network
support, DHCP, the Azure Linux agent, accelerated networking drivers and serial
console output. The OS disk uses the base template's btrfs layout.

Supported conversion target: **x86-64, Generation 2 (UEFI), SCSI OS disk at
`/dev/sda`, Secure Boot disabled**. Other generations, ARM, NVMe OS disks,
encrypted or LVM root layouts need a different hardware configuration. Ryra's
installer checks these assumptions before starting nixos-anywhere.

Installing repartitions `/dev/sda` and removes its existing data. Snapshot or back
up the OS disk first and retain Azure console access. The temporary resource disk
and attached data disks are not formatted by this template or the Azure agent.
Azure NSG rules must allow SSH on port 22 during and after the installer reboot.
The existing administrator account needs passwordless sudo and a plain SSH key.

Azure provisioning and cloud-init are disabled for this conversion: the machine
already exists, and Ryra's declaration owns the accounts and certificate authority.
The Azure agent remains enabled for fabric communication and extensions. Azure
extensions retain their usual ability to manage the VM.

Choose this template in Ryra's **Install NixOS** preparation step, save the
configuration in a new folder, review it, then confirm installation separately.
For a local template checkout, set `RYRA_TEMPLATES` to this repository's path.

References:
- https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/virtualisation/azure-common.nix
- https://learn.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-generic
