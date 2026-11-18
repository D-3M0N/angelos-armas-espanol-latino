#include <windows.h>
#include <stdio.h>
int main(void){
 HKEY k; char v[300]={0}; DWORD n=sizeof v, t;
 LONG e=RegOpenKeyExA(HKEY_LOCAL_MACHINE,"Software\\NitroPlus\\AngelosArmas",0,KEY_READ,&k);
 printf("open=%ld ",e);
 if(!e){ e=RegQueryValueExA(k,"execute",NULL,&t,(BYTE*)v,&n); printf("query=%ld execute=%s ",e,v); RegCloseKey(k);}
 DWORD d; e=RegCreateKeyExA(HKEY_CURRENT_USER,"Software\\NitroPlus\\AngelosArmas",0,NULL,0,KEY_ALL_ACCESS,NULL,&k,&d);
 if(!e){ RegSetValueExA(k,"vol",0,REG_SZ,(BYTE*)"7",2); RegCloseKey(k);} printf("create=%ld\n",e); return 0;}
