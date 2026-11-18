#include <windows.h>
#include <stdio.h>
// Mide el glifo de 0xF04E (indice 14 de LATIN = U+00BF) con GetGlyphOutlineA y el de U+00BF con GetGlyphOutlineW (sin hook).
int main(void) {
    HDC dc = CreateCompatibleDC(NULL);
    HFONT f = CreateFontW(32, 0, 0, 0, 400, 0, 0, 0, DEFAULT_CHARSET, 0, 0, 0, 0, L"Arial");
    SelectObject(dc, f);
    GLYPHMETRICS a, b, c; MAT2 m = {{0, 1}, {0, 0}, {0, 0}, {0, 1}};
    DWORD ra = GetGlyphOutlineA(dc, 0xF04E, GGO_METRICS, &a, 0, NULL, &m);
    DWORD rb = GetGlyphOutlineW(dc, 0xBF, GGO_METRICS, &b, 0, NULL, &m);
    DWORD rc = GetGlyphOutlineA(dc, 'A', GGO_METRICS, &c, 0, NULL, &m);
    printf("f04e: r=%ld incx=%d bw=%u bh=%u\nbf: r=%ld incx=%d bw=%u bh=%u\nA: r=%ld incx=%d\n",
        (long)ra, a.gmCellIncX, a.gmBlackBoxX, a.gmBlackBoxY, (long)rb, b.gmCellIncX, b.gmBlackBoxX, b.gmBlackBoxY, (long)rc, c.gmCellIncX);
    printf("same=%d\n", ra != GDI_ERROR && a.gmBlackBoxX == b.gmBlackBoxX && a.gmBlackBoxY == b.gmBlackBoxY && a.gmCellIncX == b.gmCellIncX);
    return 0; }
