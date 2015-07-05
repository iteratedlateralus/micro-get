%include "defines.asm"
%define MAX_EVENTS 64

SECTION .text
    extern  epoll_ctl
    extern  epoll_create
    extern  epoll_wait
    extern  fcntl
    extern  gethostbyname
    extern  htons
    extern  inet_ntoa
    extern  printf
    extern  snprintf
    extern  strlen
;
; int resolve_host(char* host) 
; returns the network byte ordered ip address
;============================================
resolve_host:
    push    ebp
    mov     ebp,esp
    ;Grab the IP address of the host
    ;===============================
    push    dword[ebp+8]
    call    gethostbyname
    add     esp,4
    cmp     eax,0
    je      .gethostbyname_error
    mov     ebx,eax
    
    cld     ;clear direction flag
    mov     esi,ebx
    mov     edi,h_ent
    mov     ecx,hostent.size / 4
    rep     movsd

    ;extract the encoded addresses
    ;=============================
    mov     ebx,dword[h_ent + hostent.h_addr_list]
    mov     ecx,dword[ebx]
    mov     eax,dword[ecx]
    jmp     .exit_okay
.gethostbyname_error:
    mov     eax,0
.exit_okay:
    
    leave   
    ret


;
; int create_socket(void)
; returns a socket descriptor
;============================
create_socket:
    push    ebp
    mov     ebp,esp
    ;create a socket descriptor
    ;==========================
    mov     eax,SOCKET_SYSCALL  ;socket syscall
    mov     ebx,SYS_SOCKET      ;socket()

    push    IPPROTO_IP          ;IPPROTO_IP
    push    SOCK_STREAM         ;SOCK_STREAM
    push    AF_INET             ;AF_INET
    mov     ecx,esp
    int     0x80
    add     esp,12
    leave
    ret
    
;
; int connect_to_host(int socket,short port,int nbo)
;===================================================
connect_to_host:
    push    ebp
    mov     ebp,esp
    ;Fill in the sockaddr_in structure
    ;=================================
    push    dword[ebp+12]
    call    htons
    add     esp,4

    mov     word[s_addr + sockaddr_in.sin_port],ax
    mov     word[s_addr + sockaddr_in.sin_family],2
    mov     esi,dword[ebp+16]
    mov     dword[s_addr + sockaddr_in.sin_addr],esi
    ;create the arguments on the stack
    ;=================================
    push    sockaddr_in.size
    push    s_addr
    push    dword[ebp+8]
    mov     ecx,esp
    ;connect
    ;=======
    mov     eax,SOCKET_SYSCALL
    mov     ebx,SYS_CONNECT
    int     0x80
    add     esp,12
    leave
    ret
    
;
; int make_socket_nonblocking(int socket)
;========================================
make_socket_nonblocking:
    push    ebp
    mov     ebp,esp
    push    0
    push    F_GETFL
    push    dword[ebp+8]
    call    fcntl
    add     esp,12
    cmp     eax,-1
    je      .ret
    or      eax,O_NONBLOCK
    push    eax
    push    F_SETFL
    push    dword[ebp+8]
    call    fcntl
    add     esp,12
.ret:
    leave
    ret

;
; int register_epoll(int socket)
;===============================
register_epoll:
    push    ebp
    mov     ebp,esp
    ;setup an epoll descriptor
    ;========================
    push    1
    call    epoll_create
    add     esp,4
    cmp     eax,-1
    je      .ret
    mov     dword[esp-4],eax
    mov     eax,dword[ebp+8]
    mov     dword[e_event + epoll_event.fd],eax
    mov     ebx,EPOLLIN
    mov     ecx,EPOLLET
    or      ebx,ecx
    mov     dword[e_event + epoll_event.events],ebx

    mov     eax,dword[esp-4]
    ;add our socket to epolls watchlist
    ;==================================
    push    e_event
    push    dword[ebp+8]
    push    EPOLL_CTL_ADD
    push    eax
    call    epoll_ctl
    pop     eax
    add     esp,12
.ret:
    leave
    ret 

;
; int send_data(int socket,char* buffer,int len)
;===============================================
send_data:
    push    ebp
    mov     ebp,esp
    ;send our GET request
    ;====================
    ;mov     dword[target_send_buffer],esp
    mov     eax,SOCKET_SYSCALL
    mov     ebx,SYS_SEND
    push    0
    push    dword[ebp+16]
    push    dword[ebp+12]
    push    dword[ebp+8]
    mov     ecx,esp
    int     0x80
    add     esp,16
    leave
    ret

;
; int recv_data(int socket,char* buffer,int len)
;===============================================
recv_data:
    push    ebp
    mov     ebp,esp
    mov     eax,SOCKET_SYSCALL
    mov     ebx,SYS_RECV
    push    0
    push    dword[ebp+16]
    push    dword[ebp+12]
    push    dword[ebp+8]
    mov     ecx,esp
    add     esp,16
    int     0x80
    leave
    ret
    

;struct timeval {
;    long    tv_sec;         /* seconds */
;    long    tv_usec;        /* microseconds */
;};
STRUC timeval
.tv_sec: RESD 1
.tv_usec RESD 1
.size:
ENDSTRUC

STRUC epoll_event
.events: RESD 1
.fd: RESD 1
.u32: RESD 1
.u64: RESQ 1
.size:
ENDSTRUC

STRUC fd_set
.fd_count: RESD 1
.fd_array: RESB 64
.size:
ENDSTRUC


STRUC hostent
.h_name: RESD 1
.h_aliases: RESD 1
.h_addrtype: RESD 1
.h_length: RESD 1
.h_addr_list: RESD 1
.size:

;struct sockaddr_in {
;    short            sin_family;   // e.g. AF_INET, AF_INET6
;    unsigned short   sin_port;     // e.g. htons(3490)
;    struct in_addr   sin_addr;     // see struct in_addr, below
;    char             sin_zero[8];  // zero this if you want to
;};

STRUC sockaddr_in
.sin_family: RESB 2
.sin_port: RESB 2
.sin_addr: RESD 1
.sin_zero: RESB 8
.size:
ENDSTRUC

SECTION .data

SECTION .bss
e_event: resb epoll_event.size
e_event_l: EQU ($ - e_event) / epoll_event.size

e_event_list: resb epoll_event.size * MAX_EVENTS

f_set: resb fd_set.size
f_set_l: EQU ($ - f_set) / fd_set.size

h_ent: resb hostent.size
h_ent_l: EQU ($ - h_ent) / hostent.size

s_addr: resb sockaddr_in.size
s_addr_l: EQU ($ - s_addr) / sockaddr_in.size

t_val: resb timeval.size
t_val_l: EQU ($ - t_val) / timeval.size
