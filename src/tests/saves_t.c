#include <windows.h>
#include <stdio.h>
int main(void){
 CreateDirectoryA("./data",NULL); CreateDirectoryA("./data/save",NULL);
 HANDLE h=CreateFileA("./data/save/s01.dat",GENERIC_WRITE,0,NULL,CREATE_ALWAYS,0,NULL);
 printf("create=%d\n",h!=INVALID_HANDLE_VALUE); DWORD w; WriteFile(h,"hola",4,&w,NULL); CloseHandle(h);
 printf("attr=%lx\n",GetFileAttributesA(".\\data\\save\\s01.dat"));
 h=CreateFileA("DATA/SAVE/s01.dat",GENERIC_READ,0,NULL,OPEN_EXISTING,0,NULL); char b[8]={0}; ReadFile(h,b,4,&w,NULL); printf("read=%s\n",b);
 h=CreateFileA("./data/other.txt",GENERIC_WRITE,0,NULL,CREATE_ALWAYS,0,NULL); printf("other=%d\n",h!=INVALID_HANDLE_VALUE);
 return 0;}
