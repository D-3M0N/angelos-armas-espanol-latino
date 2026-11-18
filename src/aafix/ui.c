// SPDX-License-Identifier: MIT
// ui.c: traduccion de la interfaz Win32 de nps.exe (menu emergente, dialogos de ajustes, MessageBox, pestanas).
// Tabla: AAFIX_UI_TSV=ruta  (formato translations/ui-es.tsv: hash FNV-1a64 del texto cp932 original <TAB> texto UTF-8; \t \n \\ escapados).
// El espanol NO pasa por cp932 (no tiene a e i o u n): todo se aplica con APIs W (SetMenuItemInfoW, SetWindowTextW, MessageBoxW, TCM_*ITEMW).
// AAFIX_UI_TRACE=1 registra (en AAFIX_LOG) hash y bytes cp932 hex de los textos sin traduccion, solo para ampliar ui-es.tsv en local.
#include <windows.h>
#include <commctrl.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdint.h>
#include <string.h>
#include "MinHook.h"

static void ulog(const char *fmt, ...) {
    const char *p = getenv("AAFIX_LOG"); if (!p) return;
    FILE *f = fopen(p, "a"); if (!f) return;
    va_list ap; va_start(ap, fmt); vfprintf(f, fmt, ap); va_end(ap); fclose(f);
}

typedef struct { unsigned long long h; WCHAR *t; } UEnt;
static UEnt *g_ut; static size_t g_nut; static int g_trace;
static unsigned long long ufnv(const char *s) { unsigned long long h = 14695981039346656037ULL; for (; *s; s++) { h ^= (unsigned char)*s; h *= 1099511628211ULL; } return h; }
static int ucmp(const void *a, const void *b) { unsigned long long x = ((const UEnt *)a)->h, y = ((const UEnt *)b)->h; return x < y ? -1 : x > y; }

static void ui_load(const char *path) {
    FILE *f = fopen(path, "rb"); if (!f) { ulog("ui: no abre %s\n", path); return; }
    static char line[4096]; size_t cap = 0;
    while (fgets(line, sizeof line, f)) {
        char *e = line + strlen(line); while (e > line && (e[-1] == '\n' || e[-1] == '\r')) *--e = 0;
        char *tab = line[0] == '#' ? NULL : strchr(line, '\t'); if (!tab || tab - line != 16 || !tab[1]) continue;
        char *o = tab + 1, *d = o;  // desescapar en sitio
        for (char *s = o; *s; s++) {
            if (*s == '\\' && s[1] == 't') { *d++ = '\t'; s++; } else if (*s == '\\' && s[1] == 'n') { *d++ = '\n'; s++; } else if (*s == '\\' && s[1] == '\\') { *d++ = '\\'; s++; } else *d++ = *s;
        }
        *d = 0;
        WCHAR *w = malloc(2048 * sizeof(WCHAR)); if (!w) continue;
        if (MultiByteToWideChar(65001, 0, o, -1, w, 2048) <= 0) { free(w); continue; }
        if (g_nut == cap) { cap = cap ? cap * 2 : 128; g_ut = realloc(g_ut, cap * sizeof *g_ut); }
        g_ut[g_nut].h = strtoull(line, NULL, 16); g_ut[g_nut].t = w; g_nut++;
    }
    fclose(f); qsort(g_ut, g_nut, sizeof *g_ut, ucmp); ulog("ui: %u textos de %s\n", (unsigned)g_nut, path);
}
static const WCHAR *ui_find(unsigned long long h) {
    size_t lo = 0, hi = g_nut;
    while (lo < hi) { size_t m = (lo + hi) / 2; if (g_ut[m].h < h) lo = m + 1; else hi = m; }
    return lo < g_nut && g_ut[lo].h == h ? g_ut[lo].t : NULL;
}
static void ui_miss(const char *where, const char *s, unsigned long long h) {
    if (!g_trace || !*s) return;
    char hx[1100]; size_t n = strlen(s); if (n > 500) n = 500; for (size_t i = 0; i < n; i++) sprintf(hx + 2 * i, "%02x", (unsigned char)s[i]);
    ulog("UIMISS %s %016llx %s\n", where, h, hx);
}
// Traduccion de un texto cp932 (A) o de un WCHAR original; devuelve NULL si no hay.
static const WCHAR *tr_a(const char *where, const char *s) {
    if (!s || !*s || !g_nut) return NULL;
    unsigned long long h = ufnv(s); const WCHAR *r = ui_find(h); if (!r) ui_miss(where, s, h); return r;
}
static const WCHAR *tr_w(const char *where, const WCHAR *w) {
    char b[1024]; if (!w || !*w || !g_nut) return NULL;
    int n = WideCharToMultiByte(932, 0, w, -1, b, sizeof b, NULL, NULL); if (n <= 0) return NULL;
    return tr_a(where, b);
}


// Textos dinamicos mezclados (informacion del sistema): se sustituyen fragmentos conocidos; los numeros y el resto quedan intactos.
static const struct { const WCHAR *ja, *es; } FRAG[] = {
    { L"\u753b\u9762\u89e3\u50cf\u5ea6", L"Resoluci\u00f3n de pantalla" },
    { L"\u30ea\u30d5\u30ec\u30c3\u30b7\u30e5\u30ec\u30fc\u30c8", L"Frecuencia" },
    { L"\u30e1\u30e2\u30ea", L"Memoria" },
    { L"\u7a7a\u304d\u5bb9\u91cf", L"Libre" },
    { L"\u7dcf\u5bb9\u91cf", L"Total" },
    { L"\u30b7\u30b9\u30c6\u30e0\u30c9\u30e9\u30a4\u30d6", L"Unidad del sistema" },
    { L"\uff0f", L"/" }
};
static const WCHAR *tr_frag(const char *s) {
    static WCHAR out[2048]; WCHAR w[2048]; int hi = 0; if (!s || !g_nut) return NULL;
    for (const unsigned char *c = (const unsigned char *)s; *c; c++) if (*c >= 0x80) { hi = 1; break; }
    if (!hi || MultiByteToWideChar(932, 0, s, -1, w, 2048) <= 0) return NULL;
    int changed = 0; size_t o = 0;
    for (const WCHAR *p = w; *p && o < 2040; ) {
        int hit = 0;
        for (size_t k = 0; k < sizeof FRAG / sizeof FRAG[0]; k++) {
            size_t n = wcslen(FRAG[k].ja);
            if (!wcsncmp(p, FRAG[k].ja, n)) { size_t m = wcslen(FRAG[k].es); if (o + m >= 2040) break; wcscpy(out + o, FRAG[k].es); o += m; p += n; hit = changed = 1; break; }
        }
        if (!hit) out[o++] = *p++;
    }
    out[o] = 0; return changed ? out : NULL;
}

// ---------- menus ----------
static void tr_menu(HMENU m, int depth) {
    if (!m || depth > 8) return;
    int n = GetMenuItemCount(m);
    for (int i = 0; i < n; i++) {
        WCHAR buf[512]; MENUITEMINFOW mi; memset(&mi, 0, sizeof mi); mi.cbSize = sizeof mi;
        mi.fMask = MIIM_FTYPE | MIIM_STRING | MIIM_SUBMENU; mi.dwTypeData = buf; mi.cch = 511; buf[0] = 0;
        if (!GetMenuItemInfoW(m, i, TRUE, &mi)) continue;
        if (!(mi.fType & MFT_SEPARATOR) && buf[0]) {
            const WCHAR *r = tr_w("menu", buf);
            if (r) { MENUITEMINFOW s; memset(&s, 0, sizeof s); s.cbSize = sizeof s; s.fMask = MIIM_STRING; s.dwTypeData = (LPWSTR)r; SetMenuItemInfoW(m, i, TRUE, &s); }
        }
        if (mi.hSubMenu) tr_menu(mi.hSubMenu, depth + 1);
    }
}
static HMENU (WINAPI *real_LoadMenuA)(HINSTANCE, LPCSTR);
static HMENU WINAPI h_LoadMenuA(HINSTANCE h, LPCSTR n) { HMENU m = real_LoadMenuA(h, n); if (m) { tr_menu(m, 0); ulog("ui: LoadMenuA %p -> menu traducido\n", (void *)n); } return m; }


// ---------- ajuste de tamano: el espanol es ~1.5-2x mas largo que el japones y los controles son de ancho fijo ----------
static int ctl_extra(HWND w) {   // anchura extra que ocupa el glifo del control; -1 = no ajustar
    WCHAR cls[32]; if (!GetClassNameW(w, cls, 32)) return -1;
    LONG st = GetWindowLongW(w, GWL_STYLE);
    if (!wcscmp(cls, L"Static")) { int t = st & SS_TYPEMASK; return (t == SS_LEFT || t == SS_CENTER || t == SS_RIGHT || t == SS_SIMPLE || t == SS_LEFTNOWORDWRAP) ? 4 : -1; }
    if (!wcscmp(cls, L"Button")) { int t = st & BS_TYPEMASK; if (t == BS_GROUPBOX) return -1; if (t == BS_PUSHBUTTON || t == BS_DEFPUSHBUTTON) return 14; return 22; }
    return -1;
}
static void fit_ctl(HWND w) {
    int extra = ctl_extra(w); HWND par = GetParent(w); if (extra < 0 || !par) return;
    WCHAR t[512], u[512]; if (!GetWindowTextW(w, t, 511) || !t[0]) return;
    int j = 0; for (int i = 0; t[i]; i++) { if (t[i] == L'&' && t[i + 1] && t[i + 1] != L'&') continue; u[j++] = t[i]; } u[j] = 0;
    HDC dc = GetDC(w); if (!dc) return;
    HFONT f = (HFONT)SendMessageW(w, WM_GETFONT, 0, 0), old = f ? (HFONT)SelectObject(dc, f) : NULL;
    SIZE sz; BOOL ok = GetTextExtentPoint32W(dc, u, j, &sz);
    if (old) SelectObject(dc, old);
    ReleaseDC(w, dc); if (!ok) return;
    RECT rc; GetWindowRect(w, &rc); int W = rc.right - rc.left, H = rc.bottom - rc.top;
    if (H > 2 * sz.cy + 4) return;                    // control de varias lineas: el texto envuelve solo
    int need = sz.cx * 112 / 100 + extra; if (g_trace) ulog("ui: fit? '%d' W=%d H=%d sz=%dx%d need=%d font=%p\n", (int)(wcslen(u)), W, H, (int)sz.cx, (int)sz.cy, need, (void *)f); if (need <= W) return;
    POINT p = { rc.left, rc.top }; ScreenToClient(par, &p);
    RECT pc; GetClientRect(par, &pc); int maxr = pc.right - 2;
    for (HWND s = GetWindow(par, GW_CHILD); s; s = GetWindow(s, GW_HWNDNEXT)) {   // vecino mas cercano a la derecha en la misma fila
        if (s == w || !(GetWindowLongW(s, GWL_STYLE) & WS_VISIBLE)) continue;
        RECT sr; GetWindowRect(s, &sr); POINT q = { sr.left, sr.top }; ScreenToClient(par, &q);
        int sb = q.y + (sr.bottom - sr.top);
        if (q.x > p.x + 8 && q.y < p.y + H - 2 && sb > p.y + 2 && q.x - 2 < maxr) maxr = q.x - 2;
    }
    int avail = maxr - p.x;                            // espacio realmente disponible
    int nw = need < avail ? need : avail; if (nw < W) nw = W;
    if (nw > W) SetWindowPos(w, NULL, 0, 0, nw, H, SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
    if (g_trace) ulog("ui: fit W=%d need=%d avail=%d nw=%d font=%p\n", W, need, avail, nw, (void *)f);
    if (need > avail) {                                // aun no cabe: fuente reducida (min 70 %)
        if (!f) f = (HFONT)GetStockObject(DEFAULT_GUI_FONT);
        LOGFONTW lf; if (GetObjectW(f, sizeof lf, &lf)) {
            int num = avail - extra; if (num < 8) num = 8; double k = (double)num / (sz.cx * 1.12); if (k < 0.70) k = 0.70;
            lf.lfHeight = (LONG)(lf.lfHeight * k); lf.lfWidth = 0; HFONT nf = CreateFontIndirectW(&lf);
            if (nf) SendMessageW(w, WM_SETFONT, (WPARAM)nf, TRUE);
        }
    }
}

// ---------- ventanas / dialogos ----------
static void tr_wnd(HWND w, const char *where) {
    WCHAR b[512]; b[0] = 0; if (!GetWindowTextW(w, b, 511) || !b[0]) return;
    const WCHAR *r = tr_w(where, b);
    if (r && wcscmp(r, b)) {
        SetWindowTextW(w, r); fit_ctl(w);
        WCHAR c[512]; c[0] = 0; GetWindowTextW(w, c, 511);
        if (g_trace) ulog("ui: %s hwnd=%p %s\n", where, (void *)w, wcscmp(c, r) ? "LOSSY(lectura distinta)" : "OK");
    }
}
static void tr_tabs(HWND tab) {
    int n = (int)SendMessageW(tab, TCM_GETITEMCOUNT, 0, 0);
    for (int i = 0; i < n; i++) {
        WCHAR b[256]; TCITEMW it; memset(&it, 0, sizeof it); it.mask = TCIF_TEXT; it.pszText = b; it.cchTextMax = 255; b[0] = 0;
        if (!SendMessageW(tab, TCM_GETITEMW, i, (LPARAM)&it)) continue;
        const WCHAR *r = tr_w("tab", b);
        if (r) { TCITEMW s; memset(&s, 0, sizeof s); s.mask = TCIF_TEXT; s.pszText = (LPWSTR)r; SendMessageW(tab, TCM_SETITEMW, i, (LPARAM)&s); }
    }
}
static BOOL CALLBACK enum_cb(HWND w, LPARAM l) {
    (void)l; tr_wnd(w, "ctl");
    WCHAR cls[64]; if (GetClassNameW(w, cls, 64) && !wcscmp(cls, L"SysTabControl32")) tr_tabs(w);
    return TRUE;
}
static void tr_dialog(HWND d) { tr_wnd(d, "dlg"); EnumChildWindows(d, enum_cb, 0); }
static LRESULT CALLBACK cwpret(int code, WPARAM wp, LPARAM lp) {
    if (code >= 0) { CWPRETSTRUCT *c = (CWPRETSTRUCT *)lp; if (c->message == WM_INITDIALOG) tr_dialog(c->hwnd); }
    return CallNextHookEx(NULL, code, wp, lp);
}
static DWORD g_hooked_tid[16];
static void ensure_thread_hook(void) {
    DWORD t = GetCurrentThreadId(); int i;
    for (i = 0; i < 16 && g_hooked_tid[i]; i++) if (g_hooked_tid[i] == t) return;
    if (i == 16) return;
    if (SetWindowsHookExW(WH_CALLWNDPROCRET, cwpret, NULL, t)) { g_hooked_tid[i] = t; ulog("ui: hilo %lu con WH_CALLWNDPROCRET\n", (unsigned long)t); }
}
static INT_PTR (WINAPI *real_DialogBoxParamA)(HINSTANCE, LPCSTR, HWND, DLGPROC, LPARAM);
static HWND (WINAPI *real_CreateDialogParamA)(HINSTANCE, LPCSTR, HWND, DLGPROC, LPARAM);
static INT_PTR WINAPI h_DialogBoxParamA(HINSTANCE h, LPCSTR n, HWND p, DLGPROC f, LPARAM l) { ensure_thread_hook(); return real_DialogBoxParamA(h, n, p, f, l); }
static HWND WINAPI h_CreateDialogParamA(HINSTANCE h, LPCSTR n, HWND p, DLGPROC f, LPARAM l) { ensure_thread_hook(); return real_CreateDialogParamA(h, n, p, f, l); }

// ---------- textos puestos en tiempo de ejecucion ----------
static BOOL (WINAPI *real_SetWindowTextA)(HWND, LPCSTR);
static BOOL (WINAPI *real_SetDlgItemTextA)(HWND, int, LPCSTR);
static int (WINAPI *real_MessageBoxA)(HWND, LPCSTR, LPCSTR, UINT);
static LRESULT (WINAPI *real_SendMessageA)(HWND, UINT, WPARAM, LPARAM);
static HWND (WINAPI *real_CreateWindowExA)(DWORD, LPCSTR, LPCSTR, DWORD, int, int, int, int, HWND, HMENU, HINSTANCE, LPVOID);
// Titulo de la ventana principal: se traduce tras crearla (la clase y el wndproc siguen siendo A).
static HWND WINAPI h_CreateWindowExA(DWORD ex, LPCSTR cls, LPCSTR name, DWORD st, int x, int y, int w, int h, HWND par, HMENU m, HINSTANCE i, LPVOID l) {
    HWND r = real_CreateWindowExA(ex, cls, name, st, x, y, w, h, par, m, i, l);
    if (r && name && !IS_INTRESOURCE(cls) && !(st & WS_CHILD)) {   // solo ventanas de nivel superior: los controles se traducen y ajustan en WM_INITDIALOG
         const WCHAR *t = tr_a("wintitle", name); if (t) SetWindowTextW(r, t); }
    return r;
}
static BOOL WINAPI h_SetWindowTextA(HWND w, LPCSTR s) { const WCHAR *r = tr_a("settext", s); if (!r) r = tr_frag(s); return r ? SetWindowTextW(w, r) : real_SetWindowTextA(w, s); }
static BOOL WINAPI h_SetDlgItemTextA(HWND d, int id, LPCSTR s) { const WCHAR *r = tr_a("setdlgtext", s); if (!r) r = tr_frag(s); return r ? SetDlgItemTextW(d, id, r) : real_SetDlgItemTextA(d, id, s); }
static int WINAPI h_MessageBoxA(HWND w, LPCSTR t, LPCSTR c, UINT f) {
    const WCHAR *rt = tr_a("msgbox", t), *rc = tr_a("msgcap", c);
    if (!rt && !rc) return real_MessageBoxA(w, t, c, f);
    WCHAR wt[1024], wc[256]; wt[0] = wc[0] = 0;
    if (!rt && t) MultiByteToWideChar(932, 0, t, -1, wt, 1024);
    if (!rc && c) MultiByteToWideChar(932, 0, c, -1, wc, 256);
    return MessageBoxW(w, rt ? rt : wt, rc ? rc : (c ? wc : NULL), f);
}
// Pestanas (TCM_INSERTITEMA/SETITEMA): se reenvian como W con el texto traducido.
static LRESULT WINAPI h_SendMessageA(HWND w, UINT m, WPARAM wp, LPARAM lp) {
    if ((m == TCM_INSERTITEMA || m == TCM_SETITEMA) && lp) {
        TCITEMA *a = (TCITEMA *)lp;
        if ((a->mask & TCIF_TEXT) && a->pszText) {
            const WCHAR *r = tr_a("tabitem", a->pszText);
            if (r) {
                TCITEMW b; memcpy(&b, a, sizeof b); b.pszText = (LPWSTR)r; b.cchTextMax = 0;
                return SendMessageW(w, m == TCM_INSERTITEMA ? TCM_INSERTITEMW : TCM_SETITEMW, wp, (LPARAM)&b);
            }
        }
    }
    return real_SendMessageA(w, m, wp, lp);
}

void ui_init(void) {
    const char *p = getenv("AAFIX_UI_TSV"); char def[MAX_PATH];
    if (p && !*p) p = NULL;
    if (!p) {   // por defecto: ui-es.tsv junto a la DLL
        HMODULE hm = NULL; if (!GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCSTR)ui_init, &hm)) return;
        DWORD n = GetModuleFileNameA(hm, def, MAX_PATH - 16); if (!n || n >= MAX_PATH - 16) return;
        char *sl = strrchr(def, '\\'); if (!sl) return; strcpy(sl + 1, "ui-es.tsv");
        if (GetFileAttributesA(def) == INVALID_FILE_ATTRIBUTES) return;
        p = def;
    }
    g_trace = getenv("AAFIX_UI_TRACE") != NULL;
    ui_load(p);
    MH_STATUS s[9];
    s[0] = MH_CreateHookApi(L"user32", "LoadMenuA", h_LoadMenuA, (void **)&real_LoadMenuA);
    s[1] = MH_CreateHookApi(L"user32", "DialogBoxParamA", h_DialogBoxParamA, (void **)&real_DialogBoxParamA);
    s[2] = MH_CreateHookApi(L"user32", "CreateDialogParamA", h_CreateDialogParamA, (void **)&real_CreateDialogParamA);
    s[3] = MH_CreateHookApi(L"user32", "SetWindowTextA", h_SetWindowTextA, (void **)&real_SetWindowTextA);
    s[4] = MH_CreateHookApi(L"user32", "SetDlgItemTextA", h_SetDlgItemTextA, (void **)&real_SetDlgItemTextA);
    s[5] = MH_CreateHookApi(L"user32", "MessageBoxA", h_MessageBoxA, (void **)&real_MessageBoxA);
    s[6] = MH_CreateHookApi(L"user32", "SendMessageA", h_SendMessageA, (void **)&real_SendMessageA);
    s[7] = MH_CreateHookApi(L"user32", "CreateWindowExA", h_CreateWindowExA, (void **)&real_CreateWindowExA);
    MH_EnableHook(MH_ALL_HOOKS);
    ulog("ui hooks: CreateWindowExA %s; ", MH_StatusToString(s[7]));
    ulog("ui hooks: %s %s %s %s %s %s %s\n", MH_StatusToString(s[0]), MH_StatusToString(s[1]), MH_StatusToString(s[2]), MH_StatusToString(s[3]), MH_StatusToString(s[4]), MH_StatusToString(s[5]), MH_StatusToString(s[6]));
}
