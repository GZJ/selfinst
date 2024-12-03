param (
    [string]$isoPath
)

$qcow2Image="selfinst-debian.qcow2"
qemu-img create -f qcow2 $qcow2Image 20G
qemu-system-x86_64 -hda $qcow2Image -cdrom $isoPath -boot once=d -smp 4 -m 16G
