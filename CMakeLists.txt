# SPDX-License-Identifier: MIT
cmake_minimum_required(VERSION 3.20)
project(aa_rebirth C)
# MinHook (BSD-2) se busca en MINHOOK_DIR (por defecto third_party/minhook); no se incluye en el repo.
set(MINHOOK_DIR "${CMAKE_SOURCE_DIR}/third_party/minhook" CACHE PATH "MinHook")
add_library(aafix SHARED src/aafix/aafix.c src/aafix/ui.c
  ${MINHOOK_DIR}/src/buffer.c ${MINHOOK_DIR}/src/hook.c ${MINHOOK_DIR}/src/trampoline.c ${MINHOOK_DIR}/src/hde/hde32.c)
target_include_directories(aafix PRIVATE ${MINHOOK_DIR}/include)
set_target_properties(aafix PROPERTIES PREFIX "")
target_link_options(aafix PRIVATE -static-libgcc)
# H2: proxy sin launcher = misma logica de aafix, instalada como npmm.dll (original renombrado a npmm_real.dll)
add_library(npmm_proxy SHARED src/aafix/aafix.c src/aafix/ui.c src/aafix/npmm_proxy.def
  ${MINHOOK_DIR}/src/buffer.c ${MINHOOK_DIR}/src/hook.c ${MINHOOK_DIR}/src/trampoline.c ${MINHOOK_DIR}/src/hde/hde32.c)
target_include_directories(npmm_proxy PRIVATE ${MINHOOK_DIR}/include)
set_target_properties(npmm_proxy PROPERTIES PREFIX "" OUTPUT_NAME npmm)
target_link_options(npmm_proxy PRIVATE -static-libgcc)
add_executable(aalauncher src/launcher/aalauncher.c)
target_compile_definitions(aalauncher PRIVATE UNICODE _UNICODE)
target_link_options(aalauncher PRIVATE -municode -static-libgcc)
