################################################################################
#
# hailort
#
################################################################################

HAILORT_VERSION = v4.21.0
HAILORT_SITE = $(call github,hailo-ai,hailort,$(HAILORT_VERSION))
HAILORT_LICENSE = MIT
HAILORT_LICENSE_FILES = LICENSE
HAILORT_SUPPORTS_IN_SOURCE_BUILD = NO

# Dependencies
HAILORT_DEPENDENCIES = host-cmake

# CMake build type
HAILORT_CONF_OPTS = \
    -DCMAKE_BUILD_TYPE=Release \
    -DHAILO_BUILD_EXAMPLES=OFF \
    -DCMAKE_SKIP_INSTALL_ALL_DEPENDENCY=ON

# Optional: Enable GenAI memory optimization support
# Uncomment if needed:
# HAILORT_CONF_OPTS += -DHAILO_BUILD_CLIENT_TOKENIZER=ON

# Optional: Build Python bindings (pyhailort)
# Requires python3 to be enabled in Buildroot
ifeq ($(BR2_PACKAGE_PYTHON3),y)
HAILORT_DEPENDENCIES += python3
HAILORT_CONF_OPTS += -DHAILO_BUILD_PYHAILORT=ON
else
HAILORT_CONF_OPTS += -DHAILO_BUILD_PYHAILORT=OFF
endif

# Fix CMake export targets that cause build errors
# 1. Remove "EXPORT HailoRTTargets" line from install(TARGETS...) block
# 2. Remove the entire install(EXPORT HailoRTTargets...) block
define HAILORT_FIX_CMAKE_EXPORTS
	$(SED) '/^[[:space:]]*EXPORT HailoRTTargets$$/d' $(@D)/hailort/libhailort/src/CMakeLists.txt
	$(SED) '/^install(EXPORT HailoRTTargets/,/^)$$/d' $(@D)/hailort/libhailort/src/CMakeLists.txt
	$(SED) '/^install(EXPORT HailoRTTargets/,/^)$$/d' $(@D)/hailort/CMakeLists.txt
endef
HAILORT_POST_EXTRACT_HOOKS += HAILORT_FIX_CMAKE_EXPORTS

# Manual install since CMake install may not work correctly
define HAILORT_INSTALL_TARGET_CMDS
	# Main hailort library
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/hailort/libhailort/src/libhailort.so.4.21.0 \
		$(TARGET_DIR)/usr/lib/libhailort.so.4.21.0
	ln -sf libhailort.so.4.21.0 $(TARGET_DIR)/usr/lib/libhailort.so.4
	ln -sf libhailort.so.4 $(TARGET_DIR)/usr/lib/libhailort.so
	# Protocol buffer libraries required by hailortcli
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/hailort/libhailort/libscheduler_mon_proto.so \
		$(TARGET_DIR)/usr/lib/libscheduler_mon_proto.so
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/hailort/libhailort/libprofiler_proto.so \
		$(TARGET_DIR)/usr/lib/libprofiler_proto.so
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/hailort/libhailort/libhef_proto.so \
		$(TARGET_DIR)/usr/lib/libhef_proto.so
	# Protobuf-lite library
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/_deps/protobuf-build/libprotobuf-lite.so.3.21.12.0 \
		$(TARGET_DIR)/usr/lib/libprotobuf-lite.so.3.21.12.0
	ln -sf libprotobuf-lite.so.3.21.12.0 $(TARGET_DIR)/usr/lib/libprotobuf-lite.so.32
	ln -sf libprotobuf-lite.so.32 $(TARGET_DIR)/usr/lib/libprotobuf-lite.so
	# Spdlog library
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/_deps/spdlog-build/libspdlog.so.1.14.1 \
		$(TARGET_DIR)/usr/lib/libspdlog.so.1.14.1
	ln -sf libspdlog.so.1.14.1 $(TARGET_DIR)/usr/lib/libspdlog.so.1.14
	ln -sf libspdlog.so.1.14 $(TARGET_DIR)/usr/lib/libspdlog.so
	# CLI tool
	$(INSTALL) -D -m 0755 $(@D)/buildroot-build/hailort/hailortcli/hailortcli \
		$(TARGET_DIR)/usr/bin/hailortcli
endef

$(eval $(cmake-package))