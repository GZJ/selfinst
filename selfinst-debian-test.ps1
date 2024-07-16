param (
    [string]$isoPath
)

$qcow2Image="selfinst-debian.qcow2"
$isoDirectory = "iso-debian/iso-new"

if (-not $isoPath) {
    $isoFiles = Get-ChildItem -Path $isoDirectory -Filter *.iso | Sort-Object Name
    if ($isoFiles.Count -eq 0) {
        Write-Error "No ISO files found in $isoDirectory."
        exit 1
    }
    $isoPath = $isoFiles[0].FullName
}

if (-not (Get-Command qemu-img -ErrorAction SilentlyContinue)) {
    Write-Error "qemu-img is not installed. Please install QEMU first."
    exit 1
}

if (-not (Get-Command qemu-system-x86_64 -ErrorAction SilentlyContinue)) {
    Write-Error "qemu-system-x86_64 is not installed. Please install QEMU first."
    exit 1
}

qemu-img create -f qcow2 $qcow2Image 20G
qemu-system-x86_64 -hda $qcow2Image -cdrom $isoPath -boot once=d -smp 2 -m 4G
