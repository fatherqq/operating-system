################################################################################
#
# hailo10h-pci
#
################################################################################

HAILO10H_PCI_VERSION = v5.4.0
# TODO: Before upstream PR, switch back to:
#   HAILO10H_PCI_SITE = $(call github,hailo-ai,hailort-drivers,$(HAILO10H_PCI_VERSION))
HAILO10H_PCI_SITE = https://github.com/mikehailodev/operating-system/releases/download/hailo10h-driver-v5.4.0
HAILO10H_PCI_SOURCE = hailort-drivers-v5.4.0.tar.gz
HAILO10H_PCI_LICENSE = GPL-2.0
HAILO10H_PCI_LICENSE_FILES = LICENSE
HAILO10H_PCI_MODULE_SUBDIRS = linux/pcie

$(eval $(kernel-module))
$(eval $(generic-package))
