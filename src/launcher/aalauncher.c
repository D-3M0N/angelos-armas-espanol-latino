// SPDX-License-Identifier: MIT
// aalauncher.exe <juego.exe> <aafix.dll>: crea el proceso suspendido, inyecta aafix.dll (LoadLibraryW remoto) y reanuda.
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

int wmain(int argc, wchar_t **argv) {
    if (argc < 3) { fputs("uso: aalauncher juego.exe aafix.dll\n", stderr); return 2; }
    wchar_t dll[MAX_PATH]; if (!GetFullPathNameW(argv[2], MAX_PATH, dll, NULL)) return 2;
    STARTUPINFOW si = { sizeof si }; PROCESS_INFORMATION pi;
    if (!CreateProcessW(argv[1], NULL, NULL, NULL, FALSE, CREATE_SUSPENDED, NULL, NULL, &si, &pi)) { fprintf(stderr, "CreateProcess: %lu\n", GetLastError()); return 1; }
    SIZE_T n = (wcslen(dll) + 1) * sizeof(wchar_t);
    void *mem = VirtualAllocEx(pi.hProcess, NULL, n, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    HANDLE th = NULL;
    if (mem && WriteProcessMemory(pi.hProcess, mem, dll, n, NULL))
        th = CreateRemoteThread(pi.hProcess, NULL, 0, (LPTHREAD_START_ROUTINE)GetProcAddress(GetModuleHandleW(L"kernel32"), "LoadLibraryW"), mem, 0, NULL);
    if (!th) { fprintf(stderr, "inyeccion fallida: %lu\n", GetLastError()); TerminateProcess(pi.hProcess, 1); return 1; }
    WaitForSingleObject(th, 10000);
    DWORD code = 0; GetExitCodeThread(th, &code);
    if (!code) { fputs("LoadLibrary devolvio NULL\n", stderr); TerminateProcess(pi.hProcess, 1); return 1; }
    ResumeThread(pi.hThread);
    WaitForSingleObject(pi.hProcess, INFINITE);
    return 0;
}
