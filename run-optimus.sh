#!/usr/bin/env bash

### Run with discrete GPU on NVidia Optimus laptops.
### Same technique used as with Flatpaks

program="$1"
shift
__GLX_VENDOR_LIBRARY_NAME=nvidia __NV_PRIME_RENDER_OFFLOAD=1 "$program" $@
