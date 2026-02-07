# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # "public" network so that we can access the panel interface
  config.vm.network "public_network"

  # Provision a symbolic link to the shared script
  config.vm.provision "shell",
    inline: "ln -sf /vagrant/lib/lib.sh /tmp/lib.sh"

  # Define Ubuntu VMs
  config.vm.define "ubuntu_noble" do |ubuntu_noble|
    ubuntu_noble.vm.box = "alvistack/ubuntu-24.04"
    ubuntu_noble.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  config.vm.define "ubuntu_jammy" do |ubuntu_jammy|
    ubuntu_jammy.vm.box = "ubuntu/jammy64"
    ubuntu_jammy.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  # Define Debian VMs
  config.vm.define "debian_buster" do |debian_buster|
    debian_buster.vm.box = "debian/buster64"
    debian_buster.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  config.vm.define "debian_bullseye" do |debian_bullseye|
    debian_bullseye.vm.box = "debian/bullseye64"
    debian_bullseye.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  config.vm.define "debian_bookworm" do |debian_bookworm|
    debian_bookworm.vm.box = "debian/bookworm64"
    debian_bookworm.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  config.vm.define "debian_trixie" do |debian_trixie|
    debian_trixie.vm.box = "debian/trixie64"
    debian_trixie.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  # Define AlmaLinux VMs
  config.vm.define "almalinux_8" do |almalinux_8|
    almalinux_8.vm.box = "almalinux/8"
    almalinux_8.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  config.vm.define "almalinux_9" do |almalinux_9|
    almalinux_9.vm.box = "almalinux/9"
    almalinux_9.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  # Define Rocky Linux VMs
  config.vm.define "rockylinux_8" do |rockylinux_8|
    rockylinux_8.vm.box = "bento/rockylinux-8"
    rockylinux_8.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  config.vm.define "rockylinux_9" do |rockylinux_9|
    rockylinux_9.vm.box = "bento/rockylinux-9"
    rockylinux_9.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  # Define Arch Linux VM
  config.vm.define "archlinux" do |archlinux|
    archlinux.vm.box = "archlinux/archlinux"
    archlinux.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  # Define Gentoo VM
  config.vm.define "gentoo" do |gentoo|
    gentoo.vm.box = "generic/gentoo"
    gentoo.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  # Define Void Linux VM
  config.vm.define "voidlinux" do |voidlinux|
    voidlinux.vm.box = "generic/void"
    voidlinux.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  # Define Fedora VMs
  config.vm.define "fedora_39" do |fedora_39|
    fedora_39.vm.box = "generic/fedora39"
    fedora_39.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  config.vm.define "fedora_40" do |fedora_40|
    fedora_40.vm.box = "generic/fedora40"
    fedora_40.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  config.vm.define "fedora_41" do |fedora_41|
    fedora_41.vm.box = "generic/fedora41"
    fedora_41.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  # Define FreeBSD VMs
  config.vm.define "freebsd_13" do |freebsd_13|
    freebsd_13.vm.box = "generic/freebsd13"
    freebsd_13.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  config.vm.define "freebsd_14" do |freebsd_14|
    freebsd_14.vm.box = "generic/freebsd14"
    freebsd_14.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  # Define Artix Linux VMs
  config.vm.define "artix_runit" do |artix_runit|
    artix_runit.vm.box = "generic/artix"
    artix_runit.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  config.vm.define "artix_openrc" do |artix_openrc|
    artix_openrc.vm.box = "generic/artix"
    artix_openrc.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  # Define EndeavourOS VM
  config.vm.define "endeavouros" do |endeavouros|
    endeavouros.vm.box = "generic/endeavouros"
    endeavouros.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end

  # Define Slackware VM
  config.vm.define "slackware_15" do |slackware_15|
    slackware_15.vm.box = "generic/slackware15"
    slackware_15.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
    end
  end
end
