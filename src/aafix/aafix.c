// SPDX-License-Identifier: MIT
// aafix.dll: esqueleto con MinHook. Por ahora solo un hook de prueba de GetSystemMetrics (F17).
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdint.h>
#include <string.h>
#include "MinHook.h"

void ui_init(void);   // ui.c
static int (WINAPI *real_GetSystemMetrics)(int);
static void logf_(const char *fmt, ...) {
    const char *p = getenv("AAFIX_LOG");
    if (!p) return;
    FILE *f = fopen(p, "a"); if (!f) return;
    va_list ap; va_start(ap, fmt); vfprintf(f, fmt, ap); va_end(ap); fclose(f);
}

// F17: FUN_004212e0 de nps.exe calcula el raton en cliente como cursor - rect - SM_CXSIZEFRAME (x) y
// cursor - rect - CYCAPTION - CYMENU - CYSIZEFRAME (y), suponiendo un area cliente que no coincide con la real.
// Se corrige GetCursorPos solo para ese llamador: devolvemos un cursor tal que la formula del juego da el valor cliente real.
#define F17_LO ((UINT_PTR)0x004212e0)
#define F17_HI ((UINT_PTR)0x00421340)
static BOOL (WINAPI *real_GetCursorPos)(LPPOINT);
static BOOL (WINAPI *real_GetWindowRect)(HWND, LPRECT);
static HWND g_f17_wnd;
static int g_f17_dy = 34; // medido: con coordenadas cliente reales la zona de START queda ~34 px sobre el boton visual

static int in_f17(void *ret) { UINT_PTR r = (UINT_PTR)ret; return r >= F17_LO && r < F17_HI; }

static BOOL WINAPI hook_GetWindowRect(HWND h, LPRECT r) {
    if (in_f17(__builtin_return_address(0))) g_f17_wnd = h;
    return real_GetWindowRect(h, r);
}

// Solo pruebas: AAFIX_FAKE="x,y,seg" fija el cursor cliente (x,y) y tras seg segundos envia WM_LBUTTONDOWN/UP a la ventana.
static int g_fake_on, g_fake_x, g_fake_y, g_fake_delay, g_fake_hold = 100, g_fake_n = 1;

static DWORD WINAPI fake_click_thread(LPVOID a) {
    (void)a; Sleep(g_fake_delay * 1000);
    for (int n = 0; n < g_fake_n && g_f17_wnd; n++) { LPARAM lp = MAKELPARAM(g_fake_x, g_fake_y);
        SendMessageA(g_f17_wnd, WM_MOUSEMOVE, 0, lp); Sleep(300);
        SendMessageA(g_f17_wnd, WM_LBUTTONDOWN, MK_LBUTTON, lp); Sleep(g_fake_hold);
        SendMessageA(g_f17_wnd, WM_LBUTTONUP, 0, lp); logf_("fake: clic %d (SendMessage) a %p\n", n, (void *)g_f17_wnd); Sleep(1500); }
    return 0;
}

static BOOL WINAPI hook_GetCursorPos(LPPOINT p) {
    BOOL ok = real_GetCursorPos(p);
    if (g_fake_on && g_f17_wnd) { POINT c = {g_fake_x, g_fake_y}; ClientToScreen(g_f17_wnd, &c); p->x = c.x; p->y = c.y; ok = TRUE; }
    { static UINT_PTR seen[16]; static int n; UINT_PTR r = (UINT_PTR)__builtin_return_address(0); int k;
      for (k = 0; k < n; k++) if (seen[k] == r) break;
      if (k == n && n < 16) { seen[n++] = r; logf_("GetCursorPos desde %p\n", (void *)r); } }
    if (ok && g_f17_wnd && in_f17(__builtin_return_address(0))) {
        RECT wr; POINT c = {0, 0};
        if (real_GetWindowRect(g_f17_wnd, &wr) && ClientToScreen(g_f17_wnd, &c)) {
            LONG ox = p->x, oy = p->y;
            p->x = ox - c.x + wr.left + real_GetSystemMetrics(32);
            p->y = oy - c.y + wr.top + real_GetSystemMetrics(4) + real_GetSystemMetrics(15) + real_GetSystemMetrics(33) - g_f17_dy;
            logf_("F17: cursor (%ld,%ld) -> (%ld,%ld); cliente (%ld,%ld)\n", ox, oy, p->x, p->y, ox - c.x, oy - c.y);
        }
    }
    return ok;
}


// Solo pruebas: AAFIX_TRACE=1 cuenta llamadas/s a relojes y bucle de mensajes y registra el valor de timeGetTime (atasco del fundido, intento 38).
static volatile LONG c_tgt, c_gtc, c_qpc, c_sleep, c_peek, c_get; static volatile DWORD last_tgt, last_gtc;
static DWORD (WINAPI *real_tgt)(void); static DWORD (WINAPI *real_gtc)(void); static BOOL (WINAPI *real_qpc)(LARGE_INTEGER *);
static void (WINAPI *real_sleep)(DWORD); static BOOL (WINAPI *real_peek)(LPMSG, HWND, UINT, UINT, UINT); static BOOL (WINAPI *real_getmsg)(LPMSG, HWND, UINT, UINT);
static DWORD WINAPI h_tgt(void) { DWORD v = real_tgt(); InterlockedIncrement(&c_tgt); last_tgt = v; return v; }
static DWORD WINAPI h_gtc(void) { DWORD v = real_gtc(); InterlockedIncrement(&c_gtc); last_gtc = v; return v; }
static BOOL WINAPI h_qpc(LARGE_INTEGER *q) { InterlockedIncrement(&c_qpc); return real_qpc(q); }
static void WINAPI h_sleep(DWORD ms) { InterlockedIncrement(&c_sleep); real_sleep(ms); }
static volatile LONG c_lb, c_lu, c_mm, c_key;
static DWORD g_slow;
static BOOL WINAPI h_peek(LPMSG m, HWND w, UINT a, UINT b, UINT r) { InterlockedIncrement(&c_peek); if (g_slow) real_sleep(g_slow); BOOL ok = real_peek(m, w, a, b, r);
    if (ok && m) { if (m->message == 0x201) InterlockedIncrement(&c_lb); else if (m->message == 0x202) InterlockedIncrement(&c_lu); else if (m->message == 0x200) InterlockedIncrement(&c_mm); else if (m->message == 0x100 || m->message == 0x101) InterlockedIncrement(&c_key); }
    return ok; }
static BOOL WINAPI h_getmsg(LPMSG m, HWND w, UINT a, UINT b) { InterlockedIncrement(&c_get); return real_getmsg(m, w, a, b); }
static DWORD WINAPI trace_thread(LPVOID a) {
    (void)a; for (int t = 0;; t++) { Sleep(1000);
        { static const unsigned A[] = {0x01a9d010, 0x01a9d004, 0x01a9d000, 0x01a9b8d4, 0x01a9d008, 0x014820e8}; unsigned v[6]; int ok = 1;
          for (int k = 0; k < 6; k++) { MEMORY_BASIC_INFORMATION mi; if (VirtualQuery((void *)(uintptr_t)A[k], &mi, sizeof mi) && mi.State == MEM_COMMIT) v[k] = *(volatile unsigned *)(uintptr_t)A[k]; else { v[k] = 0xdead; ok = 0; } }
          logf_("FLAGS(ok=%d) d010=%x d004=%x d000=%x b8d4=%x d008=%x head=%x\n", ok, v[0], v[1], v[2], v[3], v[4], v[5]); }
        logf_("T%d tgt=%ld gtc=%ld qpc=%ld sleep=%ld peek=%ld getmsg=%ld last_tgt=%lu last_gtc=%lu lbd=%ld lbu=%ld mm=%ld key=%ld\n", t,
            InterlockedExchange(&c_tgt, 0), InterlockedExchange(&c_gtc, 0), InterlockedExchange(&c_qpc, 0), InterlockedExchange(&c_sleep, 0),
            InterlockedExchange(&c_peek, 0), InterlockedExchange(&c_get, 0), (unsigned long)last_tgt, (unsigned long)last_gtc, InterlockedExchange(&c_lb, 0), InterlockedExchange(&c_lu, 0), InterlockedExchange(&c_mm, 0), InterlockedExchange(&c_key, 0)); }
    return 0;
}

// Redireccion de saves: lo que el juego abre bajo <cwd>\data\save\ va a AAFIX_SAVE_DIR (por defecto %APPDATA%\AngelosArmas\save),
// asi INSTALL_DIR puede ser de solo lectura. Solo se redirige esa subruta; el resto pasa intacto.
static char g_savesrc[MAX_PATH], g_savedst[MAX_PATH]; static int g_savesrc_len;
static HANDLE (WINAPI *real_CreateFileA)(LPCSTR, DWORD, DWORD, LPSECURITY_ATTRIBUTES, DWORD, DWORD, HANDLE);
static DWORD (WINAPI *real_GetFileAttributesA)(LPCSTR);
static BOOL (WINAPI *real_CreateDirectoryA)(LPCSTR, LPSECURITY_ATTRIBUTES);

static void mkdirs(char *p) { for (char *c = p + 3; *c; c++) if (*c == '\\') { *c = 0; CreateDirectoryA(p, NULL); *c = '\\'; } }

// Devuelve 1 si 'in' cae bajo data\save (o es esa carpeta) y rellena 'out' con la ruta destino.
static int save_map(const char *in, char *out, int make) {
    if (!g_savesrc_len || !in || !*in) return 0;
    char full[MAX_PATH]; DWORD n = GetFullPathNameA(in, MAX_PATH, full, NULL);
    if (!n || n >= MAX_PATH) return 0;
    for (char *c = full; *c; c++) if (*c == '/') *c = '\\';
    if (_strnicmp(full, g_savesrc, g_savesrc_len) != 0) return 0;
    if (full[g_savesrc_len] != 0 && full[g_savesrc_len] != '\\') return 0;
    if (g_savesrc_len + strlen(full + g_savesrc_len) + strlen(g_savedst) >= MAX_PATH) return 0;
    strcpy(out, g_savedst); strcat(out, full + g_savesrc_len);
    if (make) mkdirs(out);
    return 1;
}
static HANDLE WINAPI h_CreateFileA(LPCSTR f, DWORD a, DWORD sh, LPSECURITY_ATTRIBUTES sa, DWORD cd, DWORD fl, HANDLE t) {
    char o[MAX_PATH]; if (save_map(f, o, cd != OPEN_EXISTING && cd != TRUNCATE_EXISTING)) { logf_("SAVE %s -> %s\n", f, o); f = o; }
    return real_CreateFileA(f, a, sh, sa, cd, fl, t);
}
static DWORD WINAPI h_GetFileAttributesA(LPCSTR f) { char o[MAX_PATH]; if (save_map(f, o, 0)) f = o; return real_GetFileAttributesA(f); }
static BOOL WINAPI h_CreateDirectoryA(LPCSTR f, LPSECURITY_ATTRIBUTES sa) { char o[MAX_PATH]; if (save_map(f, o, 1)) f = o; return real_CreateDirectoryA(f, sa); }

static void save_init(void) {
    char cwd[MAX_PATH]; if (!GetCurrentDirectoryA(MAX_PATH, cwd)) return;
    const char *d = getenv("AAFIX_SAVE_DIR"); char def[MAX_PATH];
    if (!d) { const char *ap = getenv("APPDATA"); if (!ap) return; snprintf(def, sizeof def, "%s\\AngelosArmas\\save", ap); d = def; }
    GetFullPathNameA(d, MAX_PATH, g_savedst, NULL);
    snprintf(g_savesrc, sizeof g_savesrc, "%s%sdata\\save", cwd, cwd[strlen(cwd) - 1] == '\\' ? "" : "\\");
    g_savesrc_len = (int)strlen(g_savesrc);
    CreateDirectoryA(g_savedst, NULL); { char t[MAX_PATH]; snprintf(t, sizeof t, "%s\\x", g_savedst); mkdirs(t); }
    MH_STATUS a = MH_CreateHookApi(L"kernel32", "CreateFileA", h_CreateFileA, (void **)&real_CreateFileA);
    MH_STATUS b = MH_CreateHookApi(L"kernel32", "GetFileAttributesA", h_GetFileAttributesA, (void **)&real_GetFileAttributesA);
    MH_STATUS c = MH_CreateHookApi(L"kernel32", "CreateDirectoryA", h_CreateDirectoryA, (void **)&real_CreateDirectoryA);
    MH_EnableHook(MH_ALL_HOOKS);
    logf_("saves: %s -> %s (%s %s %s)\n", g_savesrc, g_savedst, MH_StatusToString(a), MH_StatusToString(b), MH_StatusToString(c));
}

// Locale 932 sin cambiar el del sistema: GetACP/GetOEMCP devuelven 932 y las conversiones CP_ACP/CP_OEMCP/CP_THREAD_ACP usan 932.
static UINT (WINAPI *real_GetACP)(void); static UINT (WINAPI *real_GetOEMCP)(void);
static int (WINAPI *real_MB2WC)(UINT, DWORD, LPCCH, int, LPWSTR, int);
static int (WINAPI *real_WC2MB)(UINT, DWORD, LPCWCH, int, LPSTR, int, LPCCH, LPBOOL);
static UINT cp932(UINT cp) { return (cp == CP_ACP || cp == CP_OEMCP || cp == CP_THREAD_ACP) ? 932 : cp; }
static UINT WINAPI h_GetACP(void) { return 932; }
static UINT WINAPI h_GetOEMCP(void) { return 932; }
static int WINAPI h_MB2WC(UINT cp, DWORD f, LPCCH s, int n, LPWSTR w, int m) { return real_MB2WC(cp932(cp), f, s, n, w, m); }
static int WINAPI h_WC2MB(UINT cp, DWORD f, LPCWCH w, int n, LPSTR s, int m, LPCCH d, LPBOOL u) { return real_WC2MB(cp932(cp), f, w, n, s, m, d, u); }
static void cp_init(void) {
    MH_STATUS a = MH_CreateHookApi(L"kernel32", "GetACP", h_GetACP, (void **)&real_GetACP);
    MH_STATUS b = MH_CreateHookApi(L"kernel32", "GetOEMCP", h_GetOEMCP, (void **)&real_GetOEMCP);
    MH_STATUS c = MH_CreateHookApi(L"kernel32", "MultiByteToWideChar", h_MB2WC, (void **)&real_MB2WC);
    MH_STATUS d = MH_CreateHookApi(L"kernel32", "WideCharToMultiByte", h_WC2MB, (void **)&real_WC2MB);
    MH_EnableHook(MH_ALL_HOOKS);
    logf_("codepage 932: %s %s %s %s\n", MH_StatusToString(a), MH_StatusToString(b), MH_StatusToString(c), MH_StatusToString(d));
}

// Registro virtual: las aperturas de ...\Software\[Wow6432Node\]NitroPlus\... (HKLM/HKCU) van a HKCU\Software\AngelosArmasRebirth\<subclave>,
// asi el juego no necesita el registro del instalador. Al crear la clave se siembra "execute" con <cwd>\nps.exe si falta.
static LONG (WINAPI *real_RegOpenKeyExA)(HKEY, LPCSTR, DWORD, REGSAM, PHKEY);
static LONG (WINAPI *real_RegCreateKeyExA)(HKEY, LPCSTR, DWORD, LPSTR, DWORD, REGSAM, LPSECURITY_ATTRIBUTES, PHKEY, LPDWORD);
static int reg_map(HKEY k, LPCSTR sub, char *out, size_t n) {
    if (!sub || (k != HKEY_LOCAL_MACHINE && k != HKEY_CURRENT_USER)) return 0;
    const char *p = sub; if (_strnicmp(p, "software\\", 9) != 0) return 0; p += 9;
    if (_strnicmp(p, "wow6432node\\", 12) == 0) p += 12;
    if (_strnicmp(p, "nitroplus", 9) != 0 || (p[9] != 0 && p[9] != '\\')) return 0;
    snprintf(out, n, "Software\\AngelosArmasRebirth\\%s", p); return 1;
}
static void reg_seed(HKEY h) {
    if (real_RegOpenKeyExA == NULL || RegQueryValueExA(h, "execute", NULL, NULL, NULL, NULL) == ERROR_SUCCESS) return;
    char cwd[MAX_PATH], v[MAX_PATH + 16]; if (!GetCurrentDirectoryA(MAX_PATH, cwd)) return;
    snprintf(v, sizeof v, "%s%snps.exe", cwd, cwd[strlen(cwd) - 1] == '\\' ? "" : "\\");
    RegSetValueExA(h, "execute", 0, REG_SZ, (const BYTE *)v, (DWORD)strlen(v) + 1);
}
static LONG WINAPI h_RegOpenKeyExA(HKEY k, LPCSTR sub, DWORD o, REGSAM a, PHKEY r) {
    char m[512]; if (!reg_map(k, sub, m, sizeof m)) return real_RegOpenKeyExA(k, sub, o, a, r);
    HKEY h; DWORD d; LONG e = real_RegCreateKeyExA(HKEY_CURRENT_USER, m, 0, NULL, 0, KEY_ALL_ACCESS, NULL, &h, &d);
    if (e != ERROR_SUCCESS) return e;
    reg_seed(h); RegCloseKey(h); logf_("REG open %s -> HKCU\\%s\n", sub, m);
    return real_RegOpenKeyExA(HKEY_CURRENT_USER, m, o, a, r);
}
static LONG WINAPI h_RegCreateKeyExA(HKEY k, LPCSTR sub, DWORD rs, LPSTR cl, DWORD o, REGSAM a, LPSECURITY_ATTRIBUTES sa, PHKEY r, LPDWORD d) {
    char m[512]; if (!reg_map(k, sub, m, sizeof m)) return real_RegCreateKeyExA(k, sub, rs, cl, o, a, sa, r, d);
    LONG e = real_RegCreateKeyExA(HKEY_CURRENT_USER, m, rs, cl, o, a, sa, r, d);
    if (e == ERROR_SUCCESS && r) reg_seed(*r);
    logf_("REG create %s -> HKCU\\%s\n", sub, m); return e;
}
static void reg_init(void) {
    MH_STATUS a = MH_CreateHookApi(L"advapi32", "RegOpenKeyExA", h_RegOpenKeyExA, (void **)&real_RegOpenKeyExA);
    MH_STATUS b = MH_CreateHookApi(L"advapi32", "RegCreateKeyExA", h_RegCreateKeyExA, (void **)&real_RegCreateKeyExA);
    MH_EnableHook(MH_ALL_HOOKS);
    logf_("registro virtual: %s %s\n", MH_StatusToString(a), MH_StatusToString(b));
}

// Texto (D3/D10): hook en nps.exe 0x42c7d0 (maquetador de mensajes, cdecl, param_1 = cadena SJIS completa).
// AAFIX_TRACE_TEXT=1 registra longitud y FNV-1a64 (como tools/extract-text.py); nunca el texto.
// AAFIX_TEXT_TSV=ruta[;ruta2...]: (si un hash esta en varias, gana la primera ruta) tabla "hash(16 hex)<TAB>texto UTF-8"; si el hash esta y el texto no esta vacio, se sustituye
// (convertido a cp932, max 511 B; si no cabe o no es convertible, se deja el original). AAFIX_MSG_ADDR=hex cambia la direccion (pruebas).
typedef struct { unsigned long long h; char *t; int p; } TEnt; // p = prioridad (0 = primera ruta de AAFIX_TEXT_TSV)
static int g_prio;
static TEnt *g_tab; static size_t g_ntab;
static void *(*real_msg)(const char *, int, int, int, int, int);
static int g_msg_n;
static unsigned long long fnv(const char *s) { unsigned long long h = 14695981039346656037ULL; for (; *s; s++) { h ^= (unsigned char)*s; h *= 1099511628211ULL; } return h; }
static int tcmp(const void *a, const void *b) { unsigned long long x = ((const TEnt *)a)->h, y = ((const TEnt *)b)->h; if (x != y) return x < y ? -1 : 1; return ((const TEnt *)a)->p - ((const TEnt *)b)->p; }
// D11: letras latinas que cp932 no tiene -> PUA U+E000+i, que cp932 codifica como 0xF040+ (zona de usuario SJIS).
// El orden de esta cadena fija el codigo (indice i: lead 0xF0+i/188, trail 0x40..0x7E,0x80..0xFC); la fuente debe usar el mismo.
static const WCHAR LATIN[] = L"\u00c1\u00c9\u00cd\u00d3\u00da\u00dc\u00d1\u00e1\u00e9\u00ed\u00f3\u00fa\u00fc\u00f1\u00bf\u00a1\u00ab\u00bb"
    L"\u00c0\u00c8\u00cc\u00d2\u00d9\u00e0\u00e8\u00ec\u00f2\u00f9\u00c2\u00ca\u00ce\u00d4\u00db\u00e2\u00ea\u00ee\u00f4\u00fb"
    L"\u00c7\u00e7\u00c4\u00cb\u00cf\u00d6\u00e4\u00eb\u00ef\u00f6\u00df,.";  // ',' y '.' ASCII: el motor los descarta (s727); se pintan por glifo, solo fuera de <tags>
static void latin_pua(WCHAR *w) {
    int tag = 0;
    for (; *w; w++) {
        if (*w == L'<') tag = 1; else if (*w == L'>') tag = 0;
        if (tag) continue;
        for (int i = 0; LATIN[i]; i++) if (*w == LATIN[i]) { *w = (WCHAR)(0xE000 + i); break; }
    }
}
static void tab_load(const char *path) {
    FILE *f = fopen(path, "rb"); if (!f) { logf_("tabla: no abre %s\n", path); return; }
    static char line[4096]; size_t cap = 0; unsigned dbad = 0, dlong = 0;
    while (fgets(line, sizeof line, f)) {
        char *e = line + strlen(line); while (e > line && (e[-1] == '\n' || e[-1] == '\r')) *--e = 0;
        char *tab = strchr(line, '\t'); if (!tab || tab - line != 16 || !tab[1]) continue;
        WCHAR w[2048]; int n = MultiByteToWideChar(65001, 0, tab + 1, -1, w, 2048); if (n <= 0) continue;
        char o[600]; BOOL bad = FALSE; latin_pua(w);
        int m = WideCharToMultiByte(932, 0, w, -1, o, sizeof o, NULL, &bad); if (m <= 0 || bad || m > 512) { if (m > 512) dlong++; else dbad++; continue; }
        if (g_ntab == cap) { cap = cap ? cap * 2 : 256; g_tab = realloc(g_tab, cap * sizeof *g_tab); }
        g_tab[g_ntab].h = strtoull(line, NULL, 16); g_tab[g_ntab].t = _strdup(o); g_tab[g_ntab].p = g_prio; g_ntab++;
    }
    fclose(f); qsort(g_tab, g_ntab, sizeof *g_tab, tcmp); logf_("tabla: %u textos (descartados: %u no-cp932, %u >512 B)\n", (unsigned)g_ntab, dbad, dlong);
}
static const char *tab_find(unsigned long long h) {
    size_t lo = 0, hi = g_ntab;
    while (lo < hi) { size_t m = (lo + hi) / 2; if (g_tab[m].h < h) lo = m + 1; else hi = m; }
    return lo < g_ntab && g_tab[lo].h == h ? g_tab[lo].t : NULL;
}
static void *h_msg(const char *s, int a2, int a3, int a4, int a5, int a6) {
    if (s && *s) {
        unsigned long long h = fnv(s);
        if (getenv("AAFIX_TRACE_TEXT") && g_msg_n < 400) { g_msg_n++; logf_("MSG len=%u hash=%016llx\n", (unsigned)strlen(s), h);
            if (!strcmp(getenv("AAFIX_TRACE_TEXT"), "hex")) { char hx[1100]; size_t n = strlen(s); if (n > 500) n = 500; for (size_t i = 0; i < n; i++) sprintf(hx + 2 * i, "%02x", (unsigned char)s[i]); logf_("MSGHEX %s\n", hx); } } // "hex": solo para depurar en local (cache/), nunca al repo
        const char *r = g_ntab ? tab_find(h) : NULL;
        if (!r && g_ntab && strchr(s, '\n')) { // respaldo: si el juego ya convirtio <BR> en \n, rehacer el hash de SRC
            char nb[1200]; size_t j = 0; for (const char *c = s; *c && j < sizeof nb - 5; c++) { if (*c == '\n') { memcpy(nb + j, "<BR>", 4); j += 4; } else if (*c != '\r') nb[j++] = *c; }
            nb[j] = 0; unsigned long long h2 = fnv(nb); r = tab_find(h2); if (r) h = h2; }
        if (r) { s = r; if (g_msg_n < 400) { g_msg_n++; logf_("SUBST hash=%016llx\n", h); } }
    }
    return real_msg(s, a2, a3, a4, a5, a6);
}
// Hook de glifo: codigos SJIS de zona de usuario 0xF040+ (D11) -> glifo del caracter latino de LATIN, via GetGlyphOutlineW.
static DWORD (WINAPI *real_ggoA)(HDC, UINT, UINT, LPGLYPHMETRICS, DWORD, LPVOID, const MAT2 *);
static DWORD WINAPI h_ggoA(HDC dc, UINT ch, UINT fmt, LPGLYPHMETRICS gm, DWORD n, LPVOID buf, const MAT2 *m) {
    UINT lead = (ch >> 8) & 0xFF, tr = ch & 0xFF;
    if (ch <= 0xFFFF && lead >= 0xF0 && lead <= 0xF9 && tr >= 0x40 && tr <= 0xFC && tr != 0x7F) {
        UINT i = (lead - 0xF0) * 188 + (tr < 0x7F ? tr - 0x40 : tr - 0x41);
        if (i < sizeof LATIN / sizeof LATIN[0] - 1) return GetGlyphOutlineW(dc, LATIN[i], fmt, gm, n, buf, m);
    }
    return real_ggoA(dc, ch, fmt, gm, n, buf, m);
}
static void glyph_init(void) {
    MH_STATUS a = MH_CreateHookApi(L"gdi32", "GetGlyphOutlineA", h_ggoA, (void **)&real_ggoA);
    if (a == MH_OK) a = MH_EnableHook(MH_ALL_HOOKS);
    logf_("hook glifo latino: %s\n", MH_StatusToString(a));
}
static void msg_init(void) {
    uintptr_t ad = 0x42c7d0; if (getenv("AAFIX_MSG_ADDR")) ad = (uintptr_t)strtoul(getenv("AAFIX_MSG_ADDR"), NULL, 16);
    if (getenv("AAFIX_TEXT_TSV")) {  // varias rutas separadas por ';': la primera gana (manual > automatica)
        char *l = _strdup(getenv("AAFIX_TEXT_TSV")), *sv = NULL;
        for (char *t = strtok_s(l, ";", &sv); t; t = strtok_s(NULL, ";", &sv), g_prio++) tab_load(t);
        free(l);
    }
    MH_STATUS a = MH_CreateHook((LPVOID)ad, h_msg, (void **)&real_msg);
    if (a == MH_OK) a = MH_EnableHook((LPVOID)ad);
    logf_("hook texto %p: %s\n", (void *)ad, MH_StatusToString(a));
}

static int g_override_idx = -1, g_override_val = 0;


static int WINAPI hook_GetSystemMetrics(int idx) {
    int v = real_GetSystemMetrics(idx);
    if (idx == g_override_idx) { logf_("GetSystemMetrics(%d): %d -> %d\n", idx, v, g_override_val); return g_override_val; }
    return v;
}

BOOL WINAPI DllMain(HINSTANCE h, DWORD why, LPVOID r) {
    (void)r;
    if (why == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(h);
        const char *i = getenv("AAFIX_SM_IDX"), *v = getenv("AAFIX_SM_VAL");
        if (i && v) { g_override_idx = atoi(i); g_override_val = atoi(v); }
        if (MH_Initialize() != MH_OK) return FALSE;
        MH_STATUS s = MH_CreateHookApi(L"user32", "GetSystemMetrics", hook_GetSystemMetrics, (void **)&real_GetSystemMetrics);
        if (s == MH_OK) s = MH_EnableHook(MH_ALL_HOOKS);
        if (getenv("AAFIX_F17_DY")) g_f17_dy = atoi(getenv("AAFIX_F17_DY"));
        if (s == MH_OK && !getenv("AAFIX_NO_F17")) {
            MH_STATUS a = MH_CreateHookApi(L"user32", "GetCursorPos", hook_GetCursorPos, (void **)&real_GetCursorPos);
            MH_STATUS b = MH_CreateHookApi(L"user32", "GetWindowRect", hook_GetWindowRect, (void **)&real_GetWindowRect);
            if (a == MH_OK && b == MH_OK) MH_EnableHook(MH_ALL_HOOKS);
            logf_("hook F17 (GetCursorPos/GetWindowRect): %s/%s\n", MH_StatusToString(a), MH_StatusToString(b));
        }
        if (!getenv("AAFIX_NO_SAVES")) save_init();
        if (!getenv("AAFIX_NO_CP932")) cp_init();
        if (!getenv("AAFIX_NO_REG")) reg_init();
        if (!getenv("AAFIX_NO_UI")) ui_init();
        if (getenv("AAFIX_TRACE_TEXT") || getenv("AAFIX_TEXT_TSV")) msg_init();
        if (getenv("AAFIX_TEXT_TSV") && !getenv("AAFIX_NO_GLYPH")) glyph_init();
        if (getenv("AAFIX_FAKE") && sscanf(getenv("AAFIX_FAKE"), "%d,%d,%d", &g_fake_x, &g_fake_y, &g_fake_delay) == 3) {
            if (getenv("AAFIX_FAKE_HOLD")) g_fake_hold = atoi(getenv("AAFIX_FAKE_HOLD"));
            if (getenv("AAFIX_FAKE_N")) g_fake_n = atoi(getenv("AAFIX_FAKE_N"));
            g_fake_on = 1; CreateThread(NULL, 0, fake_click_thread, NULL, 0, NULL); }
        if (getenv("AAFIX_TRACE")) {
            MH_STATUS q[6]; if (getenv("AAFIX_SLOW")) g_slow = (DWORD)atoi(getenv("AAFIX_SLOW")); /* B.6b: frena el bucle de mensajes */
            q[0] = MH_CreateHookApi(L"winmm", "timeGetTime", h_tgt, (void **)&real_tgt);
            q[1] = MH_CreateHookApi(L"kernel32", "GetTickCount", h_gtc, (void **)&real_gtc);
            q[2] = MH_CreateHookApi(L"kernel32", "QueryPerformanceCounter", h_qpc, (void **)&real_qpc);
            q[3] = MH_CreateHookApi(L"kernel32", "Sleep", h_sleep, (void **)&real_sleep);
            q[4] = MH_CreateHookApi(L"user32", "PeekMessageA", h_peek, (void **)&real_peek);
            q[5] = MH_CreateHookApi(L"user32", "GetMessageA", h_getmsg, (void **)&real_getmsg);
            MH_EnableHook(MH_ALL_HOOKS);
            logf_("TRACE hooks: %s %s %s %s %s %s\n", MH_StatusToString(q[0]), MH_StatusToString(q[1]), MH_StatusToString(q[2]), MH_StatusToString(q[3]), MH_StatusToString(q[4]), MH_StatusToString(q[5]));
            CreateThread(NULL, 0, trace_thread, NULL, 0, NULL);
        }
        logf_("aafix cargada, hook GetSystemMetrics: %s\n", MH_StatusToString(s));
    }
    return TRUE;
}
