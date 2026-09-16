#!/usr/bin/env bash
# Lavapipe CPU-rendering profile for 4-vCPU Linux runners.
# Source this file before launching MarathonRecomp, or execute it with a command:
#   source scripts/lavapipe-4cpu-profile.sh
#   ./MarathonRecomp
#
# The profile intentionally sets only variables relevant to Mesa/Lavapipe and
# avoids RADV/GPU-specific tuning. A GitHub-hosted runner has no real GPU.

set -euo pipefail

# Use the software Vulkan ICD explicitly. Prefer the modern loader variable,
# while keeping VK_ICD_FILENAMES for runners with older Vulkan loaders.
LAVAPIPE_ICD=""
for candidate in \
  /usr/share/vulkan/icd.d/lvp_icd.x86_64.json \
  /usr/share/vulkan/icd.d/lvp_icd.i686.json \
  /usr/share/vulkan/icd.d/lvp_icd.json; do
  if [[ -f "$candidate" ]]; then
    LAVAPIPE_ICD="$candidate"
    break
  fi
done

if [[ -z "$LAVAPIPE_ICD" ]]; then
  echo "ERROR: Lavapipe Vulkan ICD was not found under /usr/share/vulkan/icd.d/" >&2
  echo "Install the Mesa Vulkan software-rendering package first." >&2
  exit 1
fi

export VK_DRIVER_FILES="$LAVAPIPE_ICD"
export VK_ICD_FILENAMES="$LAVAPIPE_ICD"

# Lavapipe/LLVM software rasterization. Four vCPUs are available on the
# GitHub-hosted runner used by this project, so use all four raster threads.
export LP_NUM_THREADS="${LP_NUM_THREADS:-4}"

# Keep OpenGL fallbacks on software Mesa as well. Vulkan itself is selected by
# the ICD above; these variables do not replace the Vulkan ICD selection.
export LIBGL_ALWAYS_SOFTWARE="1"
export MESA_LOADER_DRIVER_OVERRIDE="llvmpipe"

# The runner has no physical ALSA device. SDL's dummy backend prevents the
# missing-audio-device error from aborting the game.
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-dummy}"

# Headless X11 used by the runner/noVNC desktop.
export DISPLAY="${DISPLAY:-:99}"

# Keep shader cache enabled; repeated launches can reuse compiled shaders.
export MESA_SHADER_CACHE_DISABLE="${MESA_SHADER_CACHE_DISABLE:-false}"
export MESA_SHADER_CACHE_DIR="${MESA_SHADER_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/mesa-shader-cache}"
mkdir -p "$MESA_SHADER_CACHE_DIR"

# Report the selected configuration without enabling verbose Vulkan loader logs.
echo "Lavapipe profile: ICD=$LAVAPIPE_ICD LP_NUM_THREADS=$LP_NUM_THREADS DISPLAY=$DISPLAY"

echo "Vulkan device check:"
vulkaninfo --summary 2>&1 | grep -E 'deviceName|driverName|driverInfo|Vulkan Instance Version' || true
