SECTION .text
    global  getopt
    extern  printf
; getopt should be called ASAP when entering the main
; function so that the ebp register can be searched
; 
; 1st argument: ebp
; 2nd argument: index to retrieve
getopt:
    push    ebp
    mov     ebp,esp
    mov     eax,dword[ebp+8]    ; first argument (ebp)
    mov     ebx,dword[ebp+12]   ; second argument (index)
    ; dword[ebp+12] argv
    ; dword[ebp+8] argc
    ; dword[ebp+4] eip as implicitly pushed by main()
    ; dword[ebp] ebp as it was just pushed
    ; ====================================
    mov     esi,dword[eax+12]
    mov     dword[argv],esi     
    mov     edi,dword[argv]
    mov     esi,[edi+ebx*4]
    mov     eax,esi
    leave
    ret

SECTION .data
    printf_int:     db "%d",0xa,0xd,0
    printf_string:  db "%s",0xa,0xd,0
    argv:           dd 0
