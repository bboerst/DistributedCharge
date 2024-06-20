packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "version" {
  type    = string
  default = "dev"
}

source "qemu" "cm4" {
  iso_url           = "http://cdimage.ubuntu.com/releases/22.04.4/release/ubuntu-22.04.4-preinstalled-server-arm64+raspi.img.xz"
  iso_checksum      = "file:http://cdimage.ubuntu.com/releases/22.04.4/release/SHA256SUMS"
  output_directory  = "output"
  shutdown_command  = "echo 'dc' | sudo -S shutdown -P now"
  disk_image        = true
  disk_size         = "5G"
  format            = "raw"
  accelerator       = "none"
  qemu_binary       = "qemu-system-aarch64"
  qemuargs = [
    ["-cpu", "cortex-a72"],
    ["-machine", "virt"],
    ["-smp", "2"],
    ["-m", "1G"],
    ["-nographic"],
    ["-drive", "file=output/cm4-custom-image-${var.version}.img,format=raw,if=virtio"],
    ["-netdev", "user,id=net0,hostfwd=tcp::22-:22"],
    ["-device", "virtio-net-pci,netdev=net0"],
    ["-kernel", "/usr/bin/qemu-arm-static"],
    ["-append", "root=/dev/vda2 console=ttyAMA0"]
  ]
  vm_name           = "cm4-custom-image-${var.version}.img"
  ssh_username      = "dc"
  ssh_password      = "dc"
  ssh_timeout       = "30m"
  headless          = true
}

build {
  sources = ["source.qemu.cm4"]

  provisioner "shell" {
    inline = [
      "sudo useradd -m -s /bin/bash dc",
      "echo 'dc:dc' | sudo chpasswd",
      "sudo usermod -aG sudo dc",
      "sudo apt-get update",
      "sudo apt-get install -y x11-xserver-utils xterm xinit vim git jq python3-pip build-essential cmake g++ libpcsclite-dev libcurl4-openssl-dev python3-pip libmbim-utils network-manager can-utils python3-tk python3-zmq",
      "sudo pip3 install python-can cantools can-isotp pillow pydbus gpiozero RPi.GPIO",
      "sudo pip3 install git+https://github.com/AndySchroder/RPi_mcp3008",
      "sudo pip3 install git+https://github.com/AndySchroder/helpers2",
      "sudo pip3 install git+https://github.com/AndySchroder/lnd-grpc-client.git",
      "sudo mkdir -p /home/dc/Desktop",
      "sudo git clone https://github.com/joshwardell/model3dbc /home/dc/Desktop/model3dbc",
      "cd /home/dc/Desktop/model3dbc && sudo git reset --hard 7ec978ca618f13be375f0be9b2f25c19da500d3f",
      "sudo git clone https://github.com/AndySchroder/DistributedCharge /home/dc/Desktop/DistributedCharge",
      "echo 'dtoverlay=mcp2515-can1,oscillator=16000000,interrupt=23' | sudo tee -a /boot/firmware/config.txt",
      "echo 'dtoverlay=mcp2515-can0,oscillator=16000000,interrupt=24' | sudo tee -a /boot/firmware/config.txt",
      "echo 'dtoverlay=spi1-1cs' | sudo tee -a /boot/firmware/config.txt",
      "echo '[Match]\nName=can0\n\n[CAN]\nBitRate=33300\n\n[Link]\nRequiredForOnline=no\n' | sudo tee /etc/systemd/network/80-can0.network",
      "echo '[Match]\nName=can1\n\n[CAN]\nBitRate=500000\n\n[Link]\nRequiredForOnline=no\n' | sudo tee /etc/systemd/network/80-can1.network",
      "sudo mkdir -p /home/dc/.dc",
      "sudo cp /home/dc/Desktop/DistributedCharge/SampleConfig/Config.yaml /home/dc/.dc/",
      "echo '@reboot xinit /home/dc/Desktop/DistributedCharge/Launcher-car' | sudo tee /var/spool/cron/crontabs/dc",
      "sudo sed -i -e 's/allowed_users=console/allowed_users=anybody/g' /etc/X11/Xwrapper.config",
      "echo '${var.version}' | sudo tee /etc/cm4-image-version",
      "sudo chown -R dc:dc /home/dc"
    ]
  }
}