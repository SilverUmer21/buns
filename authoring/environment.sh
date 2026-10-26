# Optional writable runtime directories for restricted environments.
# Source from any working directory: . /absolute/path/to/authoring/environment.sh
export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-/tmp/bunbreak-tools/config}
export XDG_CACHE_HOME=${XDG_CACHE_HOME:-/tmp/bunbreak-tools/cache}
export XDG_DATA_HOME=${XDG_DATA_HOME:-/tmp/bunbreak-tools/data}
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
