// SPDX-License-Identifier: MIT
// Reproduce un archivo con DirectShow (RenderFile + Run) y espera EC_COMPLETE. Uso: ds_t.exe ruta [timeout_ms]
#include <dshow.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
    if (argc < 2) return 2;
    DWORD to = argc > 2 ? (DWORD)atoi(argv[2]) : 30000;
    WCHAR w[MAX_PATH]; MultiByteToWideChar(CP_ACP, 0, argv[1], -1, w, MAX_PATH);
    CoInitialize(NULL);
    IGraphBuilder *g; IMediaControl *mc; IMediaEvent *me;
    HRESULT hr = CoCreateInstance(&CLSID_FilterGraph, NULL, CLSCTX_INPROC_SERVER, &IID_IGraphBuilder, (void **)&g);
    if (FAILED(hr)) { printf("graph hr=%lx\n", hr); return 1; }
    hr = g->lpVtbl->RenderFile(g, w, NULL); printf("RenderFile hr=%lx\n", hr); if (FAILED(hr)) return 1;
    g->lpVtbl->QueryInterface(g, &IID_IMediaControl, (void **)&mc);
    g->lpVtbl->QueryInterface(g, &IID_IMediaEvent, (void **)&me);
    DWORD t0 = GetTickCount();
    hr = mc->lpVtbl->Run(mc); printf("Run hr=%lx\n", hr);
    long code = 0; hr = me->lpVtbl->WaitForCompletion(me, to, &code);
    printf("Wait hr=%lx code=%ld ms=%lu\n", hr, code, GetTickCount() - t0);
    mc->lpVtbl->Stop(mc);
    printf("%s\n", code == EC_COMPLETE ? "COMPLETE" : "NOCOMPLETE");
    return code == EC_COMPLETE ? 0 : 1;
}
