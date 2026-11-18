#!/bin/bash
# SPDX-License-Identifier: MIT
# Crea el prefijo de 64 bits (WoW64 nuevo) y registra D: como cdrom (HKLM; ver PREGUNTAS sobre HKCU).
. "$(dirname "$0")/lib-wine.sh"
wineboot -u; wineserver -w
wine reg add 'HKLM\Software\Wine\Drives' /v 'd:' /d cdrom /f
wine reg query 'HKLM\SYSTEM\CurrentControlSet\Control\Nls\CodePage' /v ACP   # debe ser 932
