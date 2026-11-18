#include <windows.h>
#include <stdio.h>
int main(void){
 wchar_t w[8]={0}; int n=MultiByteToWideChar(CP_ACP,0,"\x82\xA0",2,w,8);
 char b[8]={0}; int m=WideCharToMultiByte(CP_ACP,0,L"\x3042",1,b,8,NULL,NULL);
 printf("acp=%u oem=%u mb2wc=%d U+%04X wc2mb=%d %02X%02X\n",GetACP(),GetOEMCP(),n,w[0],m,(unsigned char)b[0],(unsigned char)b[1]);
 return 0;}
