#!/bin/bash

function printLatestStableLinuxKernelVersion {
  unparsedStableKernel=$(curl -s https://www.kernel.org/ | tr -d '[:space:]' | grep -Po '<td>stable:</td><td><strong>[0-9]+.[0-9]+.[0-9]+</strong></td>')
  currentKernel=$(echo $unparsedStableKernel | grep -Po '[0-9]+.[0-9]+.[0-9]+')
  echo $currentKernel
}

dir="$PWD"
MOUNT_PATH="$PWD/imagesd"
IMAGE_FILE_PATH="$PWD/image.img"
KERNEL_VERSION=$(printLatestStableLinuxKernelVersion)

echo "Latest kernel version: $KERNEL_VERSION"

function setup {
  # Download GNU keyring to verify GNU utilities
  curl -OL https://ftp.gnu.org/gnu/gnu-keyring.gpg
  ls -la
}

function kernel {
  # Download kernel source, verify source, & build kernel
  export INSTALL_PATH="$MOUNT_PATH/boot"
  curl -OL "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.xz"
  curl -OL "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.sign"
  gpg2 --locate-keys torvalds@kernel.org gregkh@kernel.org
  gpg2 --verify "linux-$KERNEL_VERSION.tar.sign"
  unxz "linux-$KERNEL_VERSION.tar.xz"
  gpg2 --verify "linux-$KERNEL_VERSION.tar.sign" "linux-$KERNEL_VERSION.tar"
  tar -xf "linux-$KERNEL_VERSION.tar"
  cd "linux-$KERNEL_VERSION"
  make --quiet ARCH=x86_64 defconfig
  make --quiet -j $(nproc)
  make --quiet modules_install
  make --quiet install
  tree .
}

# Create a directory for the final image & setup
# using "Filesystem Hierarchy Standard" as a guide, creating
# just the required directories for now.
function create_file_system {
  mkdir -vp $MOUNT_PATH
  mkdir -vp $MOUNT_PATH/{bin,boot,dev,etc,lib,media,mnt,opt,run,sbin,srv,tmp,var}
  mkdir -vp $MOUNT_PATH/etc/opt
  mkdir -vp $MOUNT_PATH/usr/{bin,lib,sbin,share,include}
  mkdir -vp $MOUNT_PATH/usr/local/{bin,etc,games,include,lib,man,sbin,share,src}
}

# glibc: Download, build, & install
function add_glibc {
  curl -OL http://ftp.wayne.edu/gnu/libc/glibc-2.30.tar.xz.sig
  curl -OL http://ftp.wayne.edu/gnu/libc/glibc-2.30.tar.xz
  gpg2 --verify --keyring ./gnu-keyring.gpg glibc-2.30.tar.xz.sig
  gpg2 --verify --keyring ./gnu-keyring.gpg glibc-2.30.tar.xz.sig glibc-2.30.tar.xz
  tar -xf glibc-2.30.tar.xz
  cd glibc-2.30
  mkdir "$PWD/glibcbuild"
  cd "$PWD/glibcbuild"
  "$dir/glibc-2.30/configure" --prefix="$MOUNT_PATH/usr"
  make --quiet
  make --quiet install 
}

# GNU Coreutils: Download, build, & install
function add_coreutils {
  curl -OL https://ftp.gnu.org/gnu/coreutils/coreutils-8.31.tar.xz.sig
  curl -OL https://ftp.gnu.org/gnu/coreutils/coreutils-8.31.tar.xz
  gpg2 --verify --keyring ./gnu-keyring.gpg coreutils-8.31.tar.xz.sig
  gpg2 --verify --keyring ./gnu-keyring.gpg coreutils-8.31.tar.xz.sig coreutils-8.31.tar.xz
  tar xf coreutils-8.31.tar.xz
  cd "$dir/coreutils-8.31"
  ./configure --prefix="$MOUNT_PATH"
  make --quiet
  make --quiet install
}

# systemd: Download, build, & install
function add_systemd {
  curl -OL https://github.com/systemd/systemd/archive/v243.tar.gz
  tar xf v243.tar.gz
  cd systemd-243
  ./configure
  make --quiet
  make --quiet install DESTDIR="$MOUNT_PATH"
}

# Download & Build Bash
function add_bash {
  curl -OL https://ftp.gnu.org/gnu/bash/bash-5.0.tar.gz
  curl -OL https://ftp.gnu.org/gnu/bash/bash-5.0.tar.gz.sig
  gpg2 --verify --keyring ./gnu-keyring.gpg bash-5.0.tar.gz.sig
  gpg2 --verify --keyring ./gnu-keyring.gpg bash-5.0.tar.gz.sig bash-5.0.tar.gz
  tar xf bash-5.0.tar.gz
  cd bash-5.0
  ./configure --prefix="$MOUNT_PATH"
  make --quiet
  make --quiet install
}

function add_syslinux {
  curl -OL https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.gz
  curl -OL https://mirrors.edge.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.sign
  gpg2 --verify ./syslinux-6.03.tar.sign
  gpg2 --verify ./syslinux-6.03.tar.sign syslinux-6.03.tar.gz
  tar xf syslinux-6.03.tar.gz
  cp ./syslinux-6.03/efi64/efi/syslinux.efi $MOUNT_PATH
  cp ./syslinux-6.03/efi64/com32/elflink/ldlinux/ldlinux.e64 $MOUNT_PATH
}

function make_image {
  grub-mkimage -o $IMAGE_FILE_PATH $MOUNT_PATH
  ls -la ./
}

function build_a_linux_os {
  make_image
  setup
  create_file_system
  add_glibc
  add_coreutils
  add_kernel
  add_syslinux
  add_systemd
  add_grub2
  make_image
}

build_a_linux_os

