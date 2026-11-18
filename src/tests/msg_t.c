#include <windows.h>
#include <stdio.h>
#include <string.h>
// Imita FUN_0042c7d0 de nps.exe: cdecl, param_1 = cadena. Devuelve la cadena recibida (para ver la sustitucion).
__attribute__((noinline, cdecl)) const char *msg(const char *s, int a, int b, int c, int d, int e) { volatile int x = a + b + c + d + e; (void)x; return s; }
int main(int argc, char **argv) {
    (void)argv;
    if (argc > 1) { printf("addr=%p\n", (void *)msg); return 0; }
    const char *a = msg("\x82\xA0\x82\xA2", 1, 2, 3, 4, 5);   /* SJIS de "あい" */
    const char *b = msg("sin traduccion", 1, 2, 3, 4, 5);
    printf("a=");  for (const char *p = a; *p; p++) printf("%02X", (unsigned char)*p);
    printf("\nb=%s\n", b); return 0; }
