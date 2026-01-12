# HailoRT Package for Home Assistant OS

This package provides the HailoRT runtime library and CLI tools for Hailo-8 AI accelerators on Home Assistant OS.

## Package Contents

| Component | Description | Status |
|-----------|-------------|--------|
| `libhailort.so.4.21.0` | Core HailoRT library for AI inference | ✅ Working |
| `hailortcli` | Command-line tool for device management | ✅ Working |
| `libscheduler_mon_proto.so` | Scheduler monitoring protocol library | ✅ Working |
| `libprofiler_proto.so` | Profiler protocol library | ✅ Working |
| `libhef_proto.so` | HEF protocol library | ✅ Working |
| `libprotobuf-lite.so` | Protocol buffers lite (bundled) | ✅ Working |
| `libspdlog.so` | Logging library (bundled) | ✅ Working |
| `hailort_service` | Multi-Process Service daemon | ❌ Cannot build (see below) |

## What Works

- **Single-process inference** - Run AI models using libhailort directly
- **Model Scheduler** - Switch between multiple models within a single process (via VDevice)
- **hailortcli commands** - Scan devices, run benchmarks, parse HEF files
- **Python bindings** - pyhailort module (if Python is enabled in Buildroot)

## What Does NOT Work

### Multi-Process Service (`hailort_service`)

The `hailort_service` daemon cannot be built in this cross-compilation environment due to gRPC build issues.

**Impact:** You cannot share a single Hailo device between multiple processes simultaneously. Each application must have exclusive access to the device.

---

## Technical Details: The gRPC Cross-Compilation Problem

### What is gRPC?

**gRPC** (gRPC Remote Procedure Calls) is a high-performance framework developed by Google for inter-process and network communication. In HailoRT, it enables the Multi-Process Service:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  App 1 (Python) │     │  App 2 (C++)    │     │  App 3 (Python) │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         │    gRPC calls         │    gRPC calls         │
         └───────────────────────┼───────────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │    hailort_service     │
                    │  (Multi-Process Mgr)   │
                    └───────────┬────────────┘
                                │
                                ▼
                    ┌────────────────────────┐
                    │     Hailo-8 Device     │
                    │      /dev/hailo0       │
                    └────────────────────────┘
```

### What is Cross-Compilation?

Cross-compilation is compiling code on one type of computer (**host**) to run on a different type of computer (**target**).

| Role | Machine | Architecture | Purpose |
|------|---------|--------------|---------|
| **Host** | Development PC | x86_64 (Intel/AMD) | Runs the compiler and build tools |
| **Target** | Raspberry Pi 5 | aarch64 (ARM 64-bit) | Runs the compiled binaries |

```
┌─────────────────────────────────────────────────────────────────────┐
│                         HOST (Your PC)                              │
│                      Architecture: x86_64                           │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                    Docker Container                           │  │
│  │                    (hassos:local)                             │  │
│  │                                                               │  │
│  │   ┌─────────────────┐      ┌─────────────────────────────┐   │  │
│  │   │   Buildroot     │      │   Cross-Compiler Toolchain  │   │  │
│  │   │   Build System  │ ───▶ │   aarch64-buildroot-linux-  │   │  │
│  │   │                 │      │   gnu-gcc                   │   │  │
│  │   └─────────────────┘      └──────────────┬──────────────┘   │  │
│  │                                           │                   │  │
│  │                                           ▼                   │  │
│  │                            ┌─────────────────────────────┐   │  │
│  │                            │  Compiled binaries for      │   │  │
│  │                            │  ARM64 (aarch64)            │   │  │
│  │                            │  - libhailort.so            │   │  │
│  │                            │  - hailortcli               │   │  │
│  │                            └─────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ Flash image to SD card
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      TARGET (Raspberry Pi 5)                        │
│                      Architecture: aarch64                          │
│                                                                     │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                    Home Assistant OS                        │   │
│   │                                                             │   │
│   │   Runs the compiled ARM64 binaries:                         │   │
│   │   - /usr/lib/libhailort.so.4.21.0                          │   │
│   │   - /usr/bin/hailortcli                                     │   │
│   └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### The Problem: gRPC Host Tools

gRPC uses code generators (`protoc` + `grpc_cpp_plugin`) that must run on the **host** during compilation to generate C++ code from `.proto` files. These are **host tools** - they run on your x86_64 development machine, not on the ARM target.

#### What SHOULD Happen (Correct Cross-Compilation)

```
┌─────────────────────────────────────────────────────────────────────┐
│                              HOST (x86_64)                          │
│                                                                     │
│   BUILD TIME:                                                       │
│   ┌──────────────────────┐    ┌──────────────────────┐             │
│   │  grpc_cpp_plugin     │    │  protoc              │             │
│   │  (x86_64 binary)     │    │  (x86_64 binary)     │             │
│   │                      │    │                      │             │
│   │  Links against:      │    │  Links against:      │             │
│   │  HOST x86_64 libs    │    │  HOST x86_64 libs    │             │
│   └──────────┬───────────┘    └──────────┬───────────┘             │
│              │                           │                          │
│              └───────────┬───────────────┘                          │
│                          │                                          │
│                          ▼                                          │
│              ┌───────────────────────┐                              │
│              │  Generate C++ code    │                              │
│              │  from .proto files    │                              │
│              └───────────┬───────────┘                              │
│                          │                                          │
│                          ▼                                          │
│   ┌──────────────────────────────────────────────────────┐         │
│   │  Cross-compile generated code for TARGET (aarch64)   │         │
│   │  Using: aarch64-buildroot-linux-gnu-gcc              │         │
│   └──────────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────┘
```

#### What ACTUALLY Happens (The Bug)

```
┌─────────────────────────────────────────────────────────────────────┐
│                              HOST (x86_64)                          │
│                                                                     │
│   BUILD TIME:                                                       │
│   ┌──────────────────────┐                                         │
│   │  grpc_cpp_plugin     │                                         │
│   │  (being built...)    │                                         │
│   │                      │                                         │
│   │  Tries to link:      │                                         │
│   │  TARGET aarch64 libs │ ◀── WRONG! Can't run aarch64 on x86_64  │
│   │  (libsystemd.so)     │                                         │
│   └──────────────────────┘                                         │
│              │                                                      │
│              ▼                                                      │
│   ┌──────────────────────────────────────────────────────┐         │
│   │  ❌ ERROR: file in wrong format                      │         │
│   │  /usr/lib/libsystemd.so is aarch64, not x86_64       │         │
│   └──────────────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────────────┘
```

### The Error Message

```
/usr/bin/ld: /build/output/host/aarch64-buildroot-linux-gnu/sysroot/usr/lib/libsystemd.so: 
error adding symbols: file in wrong format
collect2: error: ld returned 1 exit status
gmake[3]: *** [CMakeFiles/grpc_cpp_plugin.dir/build.make:109: grpc_cpp_plugin] Error 1
```

**Translation:**
- The x86_64 linker (`/usr/bin/ld`) is trying to build `grpc_cpp_plugin` (a host tool)
- It's incorrectly trying to link against `libsystemd.so` from the **target sysroot** (aarch64 binary)
- x86_64 linker cannot use aarch64 libraries - incompatible binary formats
- Build fails

### Root Cause

HailoRT's CMake scripts use `FetchContent` to download and build gRPC internally. The CMake configuration doesn't properly separate:

1. **Host builds** - Tools that run during compilation (need host compiler + host libraries)
2. **Target builds** - Libraries/binaries for the target device (need cross-compiler + target libraries)

This is a common issue when cross-compiling projects that weren't designed with cross-compilation in mind.

---

## Workarounds for Multi-Process Support

If you need multi-process support, consider these alternatives:

### Option 1: Native Compilation on Raspberry Pi (Recommended)

Since cross-compilation fails because host tools link against target libraries,
compiling natively on the Pi eliminates this problem entirely:

```
┌─────────────────────────────────────────────────────────────────────┐
│             Native Compilation (Same Architecture)                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │              Raspberry Pi 5 (aarch64)                       │    │
│  │                                                             │    │
│  │   Host Tools:        Target Libraries:                      │    │
│  │   ┌──────────────┐   ┌──────────────────┐                   │    │
│  │   │ protoc       │   │ libsystemd.so    │                   │    │
│  │   │ (aarch64)    │   │ (aarch64)        │                   │    │
│  │   └──────────────┘   └──────────────────┘                   │    │
│  │         │                    │                              │    │
│  │         │    ┌───────────────┘                              │    │
│  │         │    │                                              │    │
│  │         ▼    ▼                                              │    │
│  │   ┌──────────────────────┐                                  │    │
│  │   │ grpc_cpp_plugin      │  ✓ Same architecture!            │    │
│  │   │ (aarch64)            │  ✓ No cross-compilation!         │    │
│  │   │ Links: aarch64 libs  │  ✓ Everything matches!           │    │
│  │   └──────────────────────┘                                  │    │
│  │                                                             │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### Step 1: Set Up Raspberry Pi OS

Use a separate SD card or USB drive with Raspberry Pi OS (64-bit):

```bash
# Download Raspberry Pi OS Lite (64-bit) from:
# https://www.raspberrypi.com/software/operating-systems/

# Or use Raspberry Pi Imager to flash it
```

#### Step 2: Install Build Dependencies

Boot into Raspberry Pi OS and install the required packages:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install build tools
sudo apt install -y \
    build-essential \
    cmake \
    git \
    pkg-config \
    libsystemd-dev \
    libprotobuf-dev \
    protobuf-compiler

# Verify versions
cmake --version    # Should be 3.16+
protoc --version   # Should be 3.x
```

#### Step 3: Clone and Build HailoRT

```bash
# Clone the repository
git clone --depth 1 --branch v4.21.0 https://github.com/hailo-ai/hailort.git
cd hailort

# Configure with service enabled
cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DHAILO_BUILD_SERVICE=ON \
    -DHAILO_BUILD_EXAMPLES=OFF

# Build (this will take a while on the Pi - ~30-60 minutes)
cmake --build build -j$(nproc)

# Verify the build succeeded
ls -la build/hailort/hailort_service/hailort_service
```

#### Step 4: Collect the Build Artifacts

```bash
# Create a directory for the artifacts
mkdir -p ~/hailort-artifacts/lib
mkdir -p ~/hailort-artifacts/bin

# Copy binaries
cp build/hailort/hailort_service/hailort_service ~/hailort-artifacts/bin/

# Copy all shared libraries
cp build/hailort/libhailort/src/libhailort.so* ~/hailort-artifacts/lib/
cp build/hailort/hailort_service/libscheduler_mon_proto.so ~/hailort-artifacts/lib/
cp build/hailort/hailort_service/libprofiler_proto.so ~/hailort-artifacts/lib/

# Copy gRPC-related libraries (built by FetchContent)
find build/_deps -name "*.so*" -exec cp {} ~/hailort-artifacts/lib/ \;

# Create a tarball
cd ~
tar czvf hailort-service-aarch64.tar.gz hailort-artifacts/
```

#### Step 5: Install on Home Assistant OS

There are several ways to get the binaries onto HAOS:

**Method A: Via SSH and data partition**

```bash
# From another machine, copy to HAOS
scp hailort-service-aarch64.tar.gz root@homeassistant.local:/mnt/data/

# SSH into HAOS
ssh root@homeassistant.local

# Extract
cd /mnt/data
tar xzvf hailort-service-aarch64.tar.gz
```

**Method B: Via Home Assistant addon/container**

Create a custom addon that mounts the hailort_service binary and starts it.

**Method C: Modify the HAOS image**

Mount the built HAOS image, copy the files to the rootfs, and re-flash:

```bash
# On your build machine
# Extract the image
gunzip haos_rpi5-64-17.1.dev0.img.gz

# Mount the rootfs partition (usually partition 3 or 4)
sudo losetup -P /dev/loop0 haos_rpi5-64-17.1.dev0.img
sudo mkdir -p /mnt/haos-rootfs
sudo mount /dev/loop0p3 /mnt/haos-rootfs

# Copy the natively-built service
sudo cp ~/hailort-artifacts/bin/hailort_service /mnt/haos-rootfs/usr/bin/
sudo cp ~/hailort-artifacts/lib/*.so* /mnt/haos-rootfs/usr/lib/

# Create systemd service
sudo tee /mnt/haos-rootfs/etc/systemd/system/hailort.service << 'EOF'
[Unit]
Description=HailoRT Multi-Process Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/hailort_service
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
sudo ln -sf /etc/systemd/system/hailort.service \
    /mnt/haos-rootfs/etc/systemd/system/multi-user.target.wants/hailort.service

# Unmount and clean up
sudo umount /mnt/haos-rootfs
sudo losetup -d /dev/loop0

# Re-compress
gzip haos_rpi5-64-17.1.dev0.img
```

#### Build Time Estimates (Raspberry Pi 5)

| Component | Approximate Time |
|-----------|-----------------|
| gRPC (FetchContent) | 15-25 min |
| HailoRT libraries | 10-15 min |
| hailort_service | 5-10 min |
| **Total** | **30-60 min** |

#### Disk Space Requirements

- Source code: ~500 MB
- Build directory: ~2-3 GB
- Final artifacts: ~50 MB

**Pros:** 
- ✅ Eliminates all cross-compilation issues
- ✅ Native toolchain handles everything correctly
- ✅ Works with any HailoRT version

**Cons:** 
- ⏱️ Slower build time on Pi vs x86 workstation
- 💾 Requires ~4 GB free disk space during build
- 🔧 Need separate Raspberry Pi OS installation

### Option 2: Use Hailo's Pre-built Packages

Check if Hailo provides pre-built aarch64 packages:
- Hailo Developer Zone: https://hailo.ai/developer-zone/
- Look for Debian/Ubuntu arm64 packages

**Pros:** No compilation needed  
**Cons:** May not be available or compatible with HAOS

### Option 3: Fix gRPC Cross-Compilation

Patch HailoRT's CMake to properly handle cross-compilation:

1. Build `protoc` and `grpc_cpp_plugin` as **host** packages in Buildroot
2. Modify hailort CMake to use pre-built host tools instead of building them
3. Only cross-compile the target gRPC libraries

#### What "Patching CMake" Would Mean

You'd need to modify HailoRT's CMake to do a **two-stage build**:

**Stage 1: Build Host Tools (Native)**

```cmake
# Create a separate "host" build for tools that run during compilation
include(ExternalProject)

ExternalProject_Add(grpc_host
    GIT_REPOSITORY https://github.com/grpc/grpc.git
    GIT_TAG v1.44.0
    # Use the HOST compiler, not the cross-compiler
    CMAKE_ARGS
        -DCMAKE_C_COMPILER=${CMAKE_HOST_C_COMPILER}
        -DCMAKE_CXX_COMPILER=${CMAKE_HOST_CXX_COMPILER}
        -DCMAKE_INSTALL_PREFIX=${HOST_TOOLS_DIR}
        # Only build the plugins, not libraries
        -DgRPC_BUILD_GRPC_CPP_PLUGIN=ON
        -DgRPC_BUILD_CODEGEN=ON
)
```

**Stage 2: Build Target Libraries (Cross-Compile)**

```cmake
# Now build gRPC libraries for the target (aarch64)
# But tell it to USE the host-built plugins
ExternalProject_Add(grpc_target
    GIT_REPOSITORY https://github.com/grpc/grpc.git
    GIT_TAG v1.44.0
    CMAKE_ARGS
        -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
        # Point to the HOST-built plugins
        -DProtobuf_PROTOC_EXECUTABLE=${HOST_TOOLS_DIR}/bin/protoc
        -DgRPC_CPP_PLUGIN_EXECUTABLE=${HOST_TOOLS_DIR}/bin/grpc_cpp_plugin
        # Don't try to build the plugins again
        -DgRPC_BUILD_CODEGEN=OFF
)
```

#### Visual Representation of the Fix

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    PROPER Cross-Compilation Setup                        │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  STAGE 1: Host Build (x86_64)         STAGE 2: Target Build (aarch64)   │
│  ┌────────────────────────────┐       ┌────────────────────────────┐    │
│  │ Build with HOST compiler   │       │ Build with CROSS compiler  │    │
│  │                            │       │                            │    │
│  │  protoc (x86_64)      ─────┼──────▶│ Use host protoc            │    │
│  │  grpc_cpp_plugin (x86_64)──┼──────▶│ Use host grpc_cpp_plugin   │    │
│  │                            │       │                            │    │
│  │  (runs on build machine)   │       │ libgrpc.so (aarch64)       │    │
│  └────────────────────────────┘       │ libgrpc++.so (aarch64)     │    │
│                                       │ hailort_service (aarch64)  │    │
│                                       │                            │    │
│                                       │ (runs on Raspberry Pi)     │    │
│                                       └────────────────────────────┘    │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

#### Why This Is Hard

1. **HailoRT uses FetchContent**, not ExternalProject - they have different paradigms
2. **gRPC has complex dependencies** (protobuf, abseil, etc.) - all need the same treatment
3. **CMake variables need careful separation** - host vs target compiler flags
4. **Build order dependencies** - host tools must complete before target build starts
5. **Buildroot already has host-protobuf** - need to wire that in correctly

#### What the Patch Would Look Like

You'd need to create a patch file like `buildroot-external/package/hailort/0001-fix-grpc-cross-compile.patch`:

```diff
--- a/hailort/hailort_service/CMakeLists.txt
+++ b/hailort/hailort_service/CMakeLists.txt
@@ -10,15 +10,35 @@
 # Instead of building gRPC from source, use pre-built host tools
 # and cross-compiled target libraries

+# If cross-compiling, expect host tools to be provided
+if(CMAKE_CROSSCOMPILING)
+    # Use Buildroot's host-built protoc
+    find_program(Protobuf_PROTOC_EXECUTABLE protoc
+        PATHS ${STAGING_DIR}/../host/bin
+        REQUIRED
+    )
+    
+    # Use Buildroot's host-built grpc_cpp_plugin
+    find_program(gRPC_CPP_PLUGIN_EXECUTABLE grpc_cpp_plugin
+        PATHS ${STAGING_DIR}/../host/bin
+        REQUIRED
+    )
+    
+    # Find target gRPC libraries
+    find_package(gRPC CONFIG REQUIRED)
+else()
+    # Native build - use FetchContent as before
     FetchContent_Declare(grpc
         GIT_REPOSITORY https://github.com/grpc/grpc.git
         GIT_TAG v1.44.0
     )
     FetchContent_MakeAvailable(grpc)
+endif()
```

And then in `hailort.mk`, you'd add:

```makefile
HAILORT_DEPENDENCIES += host-grpc host-protobuf grpc protobuf

HAILORT_CONF_OPTS += \
    -DProtobuf_PROTOC_EXECUTABLE=$(HOST_DIR)/bin/protoc \
    -DgRPC_CPP_PLUGIN_EXECUTABLE=$(HOST_DIR)/bin/grpc_cpp_plugin
```

#### The Catch

**Buildroot doesn't have a `host-grpc` package!** You'd need to:

1. Create `buildroot-external/package/host-grpc/` package
2. Build gRPC natively for the host
3. Then use those host binaries when cross-compiling HailoRT

#### Realistic Success Probability

| Approach | Success Chance | Time Investment |
|----------|---------------|-----------------|
| Native Pi compilation | **95%** | 2-3 hours |
| CMake patches (first attempt) | **10-20%** | 4-8 hours |
| CMake patches (with debugging) | **50-70%** | 2-5 days |
| CMake patches (production quality) | **80%** | 1-2 weeks |

#### When Patching Makes Sense

The patching approach makes sense if:

- You need to build HAOS images frequently in CI/CD
- You're contributing upstream to Home Assistant OS
- You have weeks to invest in getting it right
- You're comfortable maintaining the patches long-term

#### The "Right" Long-Term Solution

The proper fix would be for Hailo to fix their CMake to support cross-compilation. You could:

1. Open a GitHub issue on `hailo-ai/hailort`
2. Explain the cross-compilation use case
3. Point out that FetchContent doesn't work for code generators in cross-compile scenarios

This puts the maintenance burden on Hailo, who knows their codebase best.

**Pros:** Proper solution; enables automated CI/CD builds  
**Cons:** Significant development effort; requires deep CMake/gRPC knowledge; high chance of failure on first attempts

### Option 4: Design Around Single-Process

Structure your application to use a single process with the Model Scheduler:

```python
import hailo_platform

# Create a VDevice (Virtual Device) with scheduler
vdevice = hailo_platform.VDevice()

# Load multiple models - scheduler handles switching
model1 = vdevice.configure(hef1)
model2 = vdevice.configure(hef2)

# Run inference - scheduler manages device access
result1 = model1.infer(data1)
result2 = model2.infer(data2)
```

**Pros:** Works with current build  
**Cons:** All AI workloads must be in one process

---

## Package Configuration

### CMake Options Used

```makefile
HAILORT_CONF_OPTS = \
    -DCMAKE_BUILD_TYPE=Release \
    -DHAILO_BUILD_EXAMPLES=OFF \
    -DCMAKE_SKIP_INSTALL_ALL_DEPENDENCY=ON
    # -DHAILO_BUILD_SERVICE=ON  # Cannot enable due to gRPC issues
```

### Files Installed

```
/usr/lib/
├── libhailort.so -> libhailort.so.4
├── libhailort.so.4 -> libhailort.so.4.21.0
├── libhailort.so.4.21.0
├── libscheduler_mon_proto.so
├── libprofiler_proto.so
├── libhef_proto.so
├── libprotobuf-lite.so -> libprotobuf-lite.so.32
├── libprotobuf-lite.so.32 -> libprotobuf-lite.so.3.21.12.0
├── libprotobuf-lite.so.3.21.12.0
├── libspdlog.so -> libspdlog.so.1.14
├── libspdlog.so.1.14 -> libspdlog.so.1.14.1
└── libspdlog.so.1.14.1

/usr/bin/
└── hailortcli
```

---

## Testing on the Device

After flashing the image to your Raspberry Pi 5:

```bash
# Check hailortcli version
hailortcli --version

# Scan for Hailo devices
hailortcli scan

# Expected output:
# Hailo Devices:
# [-] Device: 0000:01:00.0
#     Type: HAILO8
```

---

## Related Packages

This package works together with other Hailo packages in HAOS:

| Package | Description |
|---------|-------------|
| `hailo-pci` | Kernel module for PCIe communication |
| `hailo8-firmware` | Firmware for the Hailo-8 chip |
| `gasket` | Google's Gasket driver framework |

---

## References

- [HailoRT GitHub Repository](https://github.com/hailo-ai/hailort)
- [Hailo Developer Zone](https://hailo.ai/developer-zone/)
- [HailoRT Documentation](https://hailo.ai/developer-zone/documentation/hailort/)
- [Buildroot Cross-Compilation](https://buildroot.org/downloads/manual/manual.html)

---

## Version Information

- **HailoRT Version:** v4.21.0
- **Build Date:** January 2026
- **Target Platform:** Raspberry Pi 5 (aarch64)
- **Home Assistant OS Version:** 17.1.dev0
