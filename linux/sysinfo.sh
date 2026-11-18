#!/usr/bin/env bash
# shellcheck disable=SC2016  # las comillas invertidas son markdown del informe
# SPDX-License-Identifier: MIT
# Angelos Armas - Rebirth · sysinfo.sh
# Crea la estructura del proyecto y genera un informe del sistema y de las
# dependencias del port. Solo lectura sobre game/. No usa sudo ni instala nada.
set -euo pipefail

usage() {
  cat <<'EOF'
Uso: sysinfo.sh [--root DIR] [--wine-mode auto|wow64|classic] [--no-game]

  --root DIR        Raíz del proyecto (por defecto: ~/aa_rebirth)
  --wine-mode MODO  auto: el instalado (si no hay ninguno, wow64) | wow64 | classic
  --no-game         No inspecciona game/
  -h, --help        Esta ayuda

Crea si faltan: repo/{scripts,docs,src,translations}, cache/{sysinfo,tools} y
repo/.env.local. Nunca escribe en game/. Al final imprime los comandos zypper
que debes ejecutar tú. Informe: <root>/cache/sysinfo/report-<fecha>.md
EOF
}

ROOT="$HOME/aa_rebirth"; WINE_MODE=auto; INSPECT_GAME=1
while (($#)); do
  case "$1" in
    --root) ROOT="${2:?falta DIR}"; shift 2 ;;
    --wine-mode) WINE_MODE="${2:?falta MODO}"; shift 2 ;;
    --no-game) INSPECT_GAME=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; usage >&2; exit 2 ;;
  esac
done
case "$WINE_MODE" in auto|wow64|classic) ;; *) echo "--wine-mode inválido: $WINE_MODE" >&2; exit 2 ;; esac
if [[ $EUID -eq 0 ]]; then echo "No lo ejecutes como root." >&2; exit 1; fi

ROOT="$(realpath -m "$ROOT")"
GAME_DIR="$ROOT/game"; REPO="$ROOT/repo"; CACHE="$ROOT/cache"; PREFIX="$ROOT/prefix"

# --- Estructura (idempotente; game/ no se toca) ---
mkdir -p "$REPO"/{scripts,docs,src,translations} "$CACHE"/{sysinfo,tools}
SELF="$(realpath "${BASH_SOURCE[0]}")"
[[ "$SELF" == "$REPO/linux/sysinfo.sh" ]] || cp -f "$SELF" "$REPO/linux/sysinfo.sh"
[[ -e "$REPO/.env.local" ]] || printf 'GAME_DIR=%q\nWINEPREFIX=%q\nBUILD_CACHE=%q\n' \
  "$GAME_DIR" "$PREFIX" "$CACHE" >"$REPO/.env.local"

REPORT="$CACHE/sysinfo/report-$(date +%Y%m%d-%H%M%S).md"
exec > >(tee "$REPORT") 2>&1

have() { command -v "$1" &>/dev/null; }
ok()   { printf -- '- [OK] %s\n' "$*"; }
miss() { printf -- '- **[FALTA]** %s\n' "$*"; }
warn() { printf -- '- **[AVISO]** %s\n' "$*"; }
info() { printf -- '- %s\n' "$*"; }
h2()   { printf '\n## %s\n\n' "$*"; }
indent() { sed 's/^/    /'; }

# Paquetes pedidos: se resuelven al final con una sola búsqueda de zypper.
W_KIND=(); W_CANDS=(); W_DESC=()
want() { W_KIND+=("$1"); W_CANDS+=("$2"); W_DESC+=("$3"); }   # req|opt "a|b" "desc"

check_cmd() {   # req|opt "cmd1|cmd2" "pkg1|pkg2" "descripción"
  local kind=$1 desc=$4 c; local -a cmds
  IFS='|' read -ra cmds <<<"$2"
  for c in "${cmds[@]}"; do
    if have "$c"; then ok "$desc: \`$(command -v "$c")\`"; return; fi
  done
  if [[ $kind == req ]]; then miss "$desc ($2)"; else warn "opcional: $desc ($2)"; fi
  want "$kind" "$3" "$desc"
}

printf '# Angelos Armas - Rebirth · informe del sistema\n\nFecha: %s · Raíz: `%s`\n' "$(date -Is)" "$ROOT"

# --- Sistema ---
h2 "Sistema"
# shellcheck disable=SC1091
OS_LINE=$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-?}|${ID:-?}|${VERSION_ID:-}")
IFS='|' read -r OS_PRETTY OS_ID OS_VER <<<"$OS_LINE"
info "SO: $OS_PRETTY (ID=$OS_ID ${OS_VER})"
info "Kernel: $(uname -r) · arch: $(uname -m)"
CPU=$(lscpu 2>/dev/null | awk -F: '/^Model name/{gsub(/^ +/,"",$2); print $2; exit}')
CPUS=$(nproc)
FLAGS=$(grep -m1 '^flags' /proc/cpuinfo || true)
EXT=""; for f in sse4_2 avx2 avx512f; do [[ " $FLAGS " == *" $f "* ]] && EXT+="$f "; done
info "CPU: ${CPU:-?} · hilos: $CPUS · ext: ${EXT:-ninguna}"
info "RAM: $(free -h | awk '/^Mem:/{print $2" total, "$7" disponible"}')"
info "Disco libre en la raíz: $(df -h --output=avail "$ROOT" | tail -1 | tr -d ' ')"
if [[ -e /dev/ntsync ]]; then
  if [[ -r /dev/ntsync && -w /dev/ntsync ]]; then ok "ntsync: /dev/ntsync accesible (Wine 11 lo usa)"
  else warn "ntsync: /dev/ntsync existe pero tu usuario no tiene lectura/escritura"; fi
else warn "ntsync: no hay /dev/ntsync (requiere kernel ≥ 6.14 + módulo). Solo rendimiento; no bloquea."; fi

# --- Sesión gráfica y monitores (D13: Hz, VRR, escalado) ---
h2 "Sesión gráfica"
info "Sesión: ${XDG_SESSION_TYPE:-?} · escritorio: ${XDG_CURRENT_DESKTOP:-?} · DISPLAY=${DISPLAY:-} · WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-}"
if have kscreen-doctor; then
  info "Monitores (kscreen-doctor, modo actual marcado con *):"
  kscreen-doctor -o 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk '
    /Output:/{o=$3}
    /Modes:/{for(i=1;i<=NF;i++) if($i ~ /\*/) print o ": " $i}
    /Scale:|[Vv]rr|Adaptive/{gsub(/^[ \t]+/,""); print o ": " $0}' | indent || true
elif have xrandr; then
  info "Monitores (xrandr; en Wayland son los de XWayland):"
  xrandr --current 2>/dev/null | awk '/ connected/{o=$1} /\*/{for(i=2;i<=NF;i++) if($i~/\*/) print o ": " $1 " @ " $i}' | indent || true
else
  warn "sin kscreen-doctor ni xrandr: no puedo listar resoluciones ni Hz"; want opt "xrandr" "listar monitores"
fi

# --- GPU ---
h2 "GPU y drivers"
GPU_VENDOR=""
if have lspci; then
  GPUS=$(lspci -nn | grep -Ei 'vga|3d|display' || true)
  printf '%s\n' "$GPUS" | indent
  case "${GPUS,,}" in *nvidia*) GPU_VENDOR=nvidia ;; *amd*|*ati*) GPU_VENDOR=amd ;; *intel*) GPU_VENDOR=intel ;; esac
else want opt "pciutils" "lspci"; fi
if have glxinfo; then
  glxinfo -B 2>/dev/null | grep -E 'OpenGL (renderer|core profile version|version) string' | indent || true
else warn "opcional: glxinfo (Mesa-demo-x)"; want opt "Mesa-demo-x" "glxinfo"; fi
if have vulkaninfo; then
  timeout 20 vulkaninfo --summary 2>/dev/null | grep -E 'deviceName|driverName|driverInfo|apiVersion' | sort -u | indent || true
else warn "opcional: vulkaninfo (vulkan-tools), útil si el juego resulta d3d8/9 → DXVK"; want opt "vulkan-tools" "vulkaninfo"; fi

# --- Locale y fuentes (F1, F6) ---
h2 "Locale y fuentes"
info "LANG actual: ${LANG:-?}"
LOCALES=$(locale -a 2>/dev/null || true)
if grep -qiE '^ja_JP\.utf-?8$' <<<"$LOCALES"; then ok "locale ja_JP.UTF-8 disponible"
else miss "locale ja_JP.UTF-8"; want req "glibc-locale" "locale ja_JP.UTF-8"; fi
JA_FONTS=$(fc-list :lang=ja family 2>/dev/null | sort -u || true)
if [[ -n $JA_FONTS ]]; then ok "fuentes con japonés: $(wc -l <<<"$JA_FONTS") familias (p. ej. $(head -1 <<<"$JA_FONTS"))"
else miss "ninguna fuente con japonés"; want req "google-noto-sans-cjk-fonts|noto-sans-cjk-fonts" "fuente CJK"; fi

# --- Wine ---
h2 "Wine"
INSTALLED_MODE=""
if have wine; then
  WROOT=$(dirname "$(dirname "$(readlink -f "$(command -v wine)")")")
  if compgen -G "$WROOT/lib*/wine/i386-unix/ntdll.so" >/dev/null || compgen -G "$WROOT/lib*/*/wine/i386-unix/ntdll.so" >/dev/null
  then INSTALLED_MODE=classic; else INSTALLED_MODE=wow64; fi
  WVER=$(wine --version 2>/dev/null || echo "?")
  info "Instalado: $WVER · modo: $INSTALLED_MODE"
fi
if [[ $WINE_MODE == auto ]]; then MODE=${INSTALLED_MODE:-wow64}; else MODE=$WINE_MODE; fi
info "Modo objetivo: **$MODE** (wow64 = sin libs de 32 bits en el host; classic = wine + wine-32bit + GStreamer -32bit)"
if [[ -z $INSTALLED_MODE ]]; then
  miss "wine"
  if [[ $MODE == wow64 ]]; then want req "wine-wow64|wine-staging-wow64" "wine (WoW64 nuevo)"; else want req "wine" "wine (WoW64 clásico)"; fi
elif [[ $INSTALLED_MODE != "$MODE" ]]; then
  warn "instalado en modo $INSTALLED_MODE, pediste $MODE: cambiarlo implica que zypper reemplace el paquete de wine"
  if [[ $MODE == wow64 ]]; then want req "wine-wow64|wine-staging-wow64" "wine (WoW64 nuevo)"; else want req "wine" "wine (WoW64 clásico)"; fi
else
  WMAJ=$(sed -nE 's/^wine-([0-9]+).*/\1/p' <<<"$WVER")
  if [[ $MODE == wow64 && -n $WMAJ && $WMAJ -lt 11 ]]; then warn "WoW64 nuevo antes de Wine 11 era experimental; actualiza a ≥ 11"
  else ok "wine en modo $MODE"; fi
fi
if [[ -f $PREFIX/system.reg ]]; then info "Prefijo: \`$PREFIX\` ($(grep -m1 '^#arch=' "$PREFIX/system.reg" || echo 'arch ?'))"
else info "Prefijo \`$PREFIX\`: aún no creado (lo crea 03-wineprefix.sh; debe ser de 64 bits, WINEARCH=win32 no vale en wow64)"; fi

# --- GStreamer (F5: video de las cinemáticas) ---
h2 "GStreamer para Wine (modo $MODE)"
if [[ $MODE == wow64 ]]; then GDIR=/usr/lib64/gstreamer-1.0; SFX=""; else GDIR=/usr/lib/gstreamer-1.0; SFX="-32bit"; fi
GST_SET=(base good bad ugly libav)
GST_SO=(libgstplayback.so libgstdeinterlace.so libgstmpegpsdemux.so libgstmpeg2dec.so libgstlibav.so)
for i in "${!GST_SET[@]}"; do
  k=${GST_SET[$i]}
  if [[ -e $GDIR/${GST_SO[$i]} ]]; then ok "gstreamer-plugins-$k$SFX (${GST_SO[$i]})"
  else miss "gstreamer-plugins-$k$SFX (no hay $GDIR/${GST_SO[$i]})"; want req "gstreamer-plugins-$k$SFX" "GStreamer $k"; fi
done
PACKMAN=0
if have zypper && zypper --no-refresh lr -u 2>/dev/null | grep -qi packman; then PACKMAN=1; ok "repo Packman configurado"
else warn "repo Packman no configurado: libav (y parte de ugly/bad) solo viene de Packman"; fi
if have rpm && rpm -q "gstreamer-plugins-libav$SFX" &>/dev/null; then
  info "proveedor de libav: $(rpm -q --qf '%{VENDOR}' "gstreamer-plugins-libav$SFX")"
fi

if [[ $MODE == classic ]]; then
  h2 "GL/Vulkan de 32 bits (solo modo classic)"
  if [[ -e /usr/lib/libGL.so.1 ]]; then ok "libGL 32 bits"; else miss "libGL 32 bits"; want req "Mesa-libGL1-32bit" "libGL 32 bits"; fi
  if [[ -e /usr/lib/libvulkan.so.1 ]]; then ok "loader Vulkan 32 bits"; else miss "loader Vulkan 32 bits"; want req "libvulkan1-32bit" "Vulkan 32 bits"; fi
  case $GPU_VENDOR in
    amd|intel)
      icd=radeon; [[ $GPU_VENDOR == intel ]] && icd=intel
      if [[ -e /usr/share/vulkan/icd.d/${icd}_icd.i686.json ]]; then ok "ICD Vulkan $icd 32 bits"
      else miss "ICD Vulkan $icd 32 bits"; want req "libvulkan_${icd}-32bit" "Vulkan $icd 32 bits"; fi ;;
    nvidia)
      if [[ -e /usr/lib/libGLX_nvidia.so.0 ]]; then ok "driver NVIDIA 32 bits"
      else miss "driver NVIDIA 32 bits (paquete *-32bit del repo de NVIDIA, según tu rama G0x)"; fi ;;
  esac
fi

# --- Herramientas (lista de la fase 0) ---
h2 "Herramientas"
check_cmd req git git "git"
check_cmd req "i686-w64-mingw32-gcc" "mingw32-cross-gcc" "MinGW i686 C"
check_cmd req "i686-w64-mingw32-g++" "mingw32-cross-gcc-c++" "MinGW i686 C++"
check_cmd req cmake cmake "cmake"
check_cmd req ninja "ninja" "ninja"
check_cmd req python3 python3 "python3"
check_cmd req winetricks winetricks "winetricks"
check_cmd req ffprobe "ffmpeg-8|ffmpeg-7|ffmpeg" "ffmpeg/ffprobe"
check_cmd req Xvfb xorg-x11-server-Xvfb "Xvfb"
check_cmd req xdotool xdotool "xdotool"
check_cmd req "magick|convert" ImageMagick "ImageMagick"
check_cmd req "7z|7zz" "7zip|p7zip-full|p7zip" "7-Zip"
check_cmd req shellcheck ShellCheck "shellcheck"
check_cmd req gh gh "GitHub CLI"
check_cmd req gitleaks gitleaks "gitleaks"
check_cmd req file file "file"
check_cmd opt gst-inspect-1.0 gstreamer-utils "gst-inspect-1.0"
info "Versiones:"
{
  for c in cmake i686-w64-mingw32-gcc python3 gh; do have "$c" && echo "$c: $("$c" --version 2>&1 | head -1)"; done
  have ffprobe && echo "ffprobe: $(ffprobe -version 2>&1 | head -1)"
  true
} | indent

# --- Juego (solo lectura) ---
h2 "Juego (solo lectura): \`$GAME_DIR\`"
if ((INSPECT_GAME == 0)); then info "omitido (--no-game)"
elif [[ ! -d $GAME_DIR ]]; then miss "no existe $GAME_DIR: copia ahí los archivos del juego"
else
  NFILES=$(find "$GAME_DIR" -type f | wc -l)
  info "Tamaño: $(du -sh "$GAME_DIR" | cut -f1) · archivos: $NFILES"
  if [[ -n $(find "$GAME_DIR" -writable -print -quit) ]]; then
    warn "game/ es escribible. Recomendado: \`chmod -R a-w '$GAME_DIR'\` (revierte con u+w)"
  else ok "game/ en solo lectura"; fi

  ALLNAMES=$(find "$GAME_DIR" -mindepth 1 -printf '%P\n')
  BADNAMES=$(LC_ALL=C.UTF-8 grep -axv '.*' <<<"$ALLNAMES" || true)
  if [[ -n $BADNAMES ]]; then
    warn "F2: $(wc -l <<<"$BADNAMES") nombres no son UTF-8 válido (¿SJIS crudo?). Muestra:"
    head -5 <<<"$BADNAMES" | while IFS= read -r n; do printf '%q\n' "$n"; done | indent
  else ok "todos los nombres son UTF-8 válido"; fi
  NONASCII=$(LC_ALL=C grep -P '[^\x00-\x7F]' <<<"$ALLNAMES" || true)
  if [[ -n $NONASCII ]]; then info "Nombres no ASCII (revisar mojibake tipo «ƒ…» / «Ã…»):"; head -10 <<<"$NONASCII" | indent; fi

  info "Extensiones:"
  find "$GAME_DIR" -type f -printf '%f\n' | awk -F. 'NF>1{print tolower($NF); next}{print "(sin ext)"}' \
    | sort | uniq -c | sort -rn | head -20 | indent || true
  info "Árbol (profundidad 2; tipo, bytes, ruta):"
  find "$GAME_DIR" -mindepth 1 -maxdepth 2 -printf '%y %12s  %P\n' | LC_ALL=C sort -k3 | head -80 | indent || true
  info "Archivos más grandes y sus primeros 8 bytes (formato de contenedor):"
  find "$GAME_DIR" -type f -printf '%s\t%P\n' | sort -rn | head -12 | while IFS=$'\t' read -r sz rel; do
    hex=$(od -An -tx1 -N8 "$GAME_DIR/$rel" | tr -s ' ' | sed 's/^ //')
    asc=$(head -c8 "$GAME_DIR/$rel" | LC_ALL=C tr -c '[:print:]' '.')
    printf '%12s  %-23s %-8s  %s\n' "$sz" "$hex" "$asc" "$rel"
  done | indent || true

  OBJDUMP=""
  for c in i686-w64-mingw32-objdump x86_64-w64-mingw32-objdump objdump; do
    if have "$c" && "$c" -i 2>/dev/null | grep -q '^pei-i386'; then OBJDUMP=$c; break; fi
  done
  info "Ejecutables y DLL (PE):"
  mapfile -t PES < <(find "$GAME_DIR" -type f \( -iname '*.exe' -o -iname '*.dll' \) -printf '%P\n' | LC_ALL=C sort | head -20)
  for rel in "${PES[@]}"; do
    f="$GAME_DIR/$rel"
    printf -- '- `%s` · %s\n    sha256 %s\n' "$rel" "$(file -b "$f" | cut -c1-80)" "$(sha256sum "$f" | cut -c1-64)"
    if [[ -n $OBJDUMP ]]; then
      dlls=$("$OBJDUMP" -p "$f" 2>/dev/null | awk '/DLL Name:/{print $3}' | sort -fu | paste -sd' ' || true)
      secs=$("$OBJDUMP" -h "$f" 2>/dev/null | awk '$1 ~ /^[0-9]+$/{print $2}' | paste -sd' ' || true)
      printf '    imports: %s\n    secciones: %s\n' "${dlls:-?}" "${secs:-?}"
      if grep -qiE 'securom|stxt|\.pec|upx|\.cms_|enigma|themida|aspack|\.vmp|\.svkp' <<<"$secs"; then
        warn "posible protección o packer por nombre de sección en $rel → la fase 0 debe confirmarlo antes de seguir (D6)"
      fi
    fi
  done
  ((${#PES[@]})) || warn "no hay .exe/.dll en game/"
  [[ -n $OBJDUMP ]] || warn "sin objdump con soporte PE: instala MinGW y repite para ver imports"
fi

# --- Resumen e instalación ---
h2 "Resumen"
declare -A AVAIL=()
if have zypper; then
  mapfile -t CANDS < <(printf '%s\n' "${W_CANDS[@]}" | tr '|' '\n' | sed '/^$/d' | sort -u)
  if ((${#CANDS[@]})); then
    while IFS= read -r n; do [[ -n $n ]] && AVAIL[$n]=1; done < <(
      LC_ALL=C timeout 60 zypper --no-refresh -q se -x -t package "${CANDS[@]}" 2>/dev/null \
        | awk -F'|' '/\|/{gsub(/^ +| +$/,"",$2); if($2!="Name" && $2!="Nombre") print $2}' || true)
  fi
fi
REQ=(); OPT=(); NOTFOUND=()
for i in "${!W_CANDS[@]}"; do
  pick=""; IFS='|' read -ra cs <<<"${W_CANDS[$i]}"
  for p in "${cs[@]}"; do [[ -n ${AVAIL[$p]:-} ]] && { pick=$p; break; }; done
  if [[ -z $pick ]]; then NOTFOUND+=("${W_CANDS[$i]} — ${W_DESC[$i]}")
  elif [[ ${W_KIND[$i]} == req ]]; then REQ+=("$pick"); else OPT+=("$pick"); fi
done
dedup() { printf '%s\n' "$@" | sed '/^$/d' | sort -u | paste -sd' '; }

if ((${#W_CANDS[@]} == 0)); then ok "no falta nada"; fi
if ((${#REQ[@]})); then printf 'Requeridos (ejecútalo tú):\n\n```\nsudo zypper install %s\n```\n\n' "$(dedup "${REQ[@]}")"; fi
if ((${#OPT[@]})); then printf 'Opcionales de diagnóstico:\n\n```\nsudo zypper install %s\n```\n\n' "$(dedup "${OPT[@]}")"; fi
if ((${#NOTFOUND[@]})); then
  echo "No encontrados en tus repos (según la caché de zypper):"
  for n in "${NOTFOUND[@]}"; do
    hint=""
    case $n in
      *libav*|*ugly*|*bad*) ((PACKMAN)) || hint=" → necesita Packman: \`sudo zypper install opi && opi codecs\` (pasa los códecs a Packman), luego repite" ;;
      *mingw32*) hint=" → en Leap: repo OBS windows:mingw:win32" ;;
      *gitleaks*) hint=" → binario de github.com/gitleaks/gitleaks/releases en ~/.local/bin" ;;
      *wine-wow64*) hint=" → repo OBS Emulators:Wine, o usa --wine-mode classic" ;;
    esac
    info "$n$hint"
  done
  if ! have zypper; then info "(sin zypper: no pude comprobar disponibilidad)"; fi
  echo
fi
info "Si algo sale «no encontrado» sin motivo: \`sudo zypper refresh\` y repite."
info "Tras instalar, vuelve a ejecutar: \`$REPO/linux/sysinfo.sh\`"
info "Informe guardado en: \`$REPORT\`"
