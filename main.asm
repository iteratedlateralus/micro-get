%include "args.asm"
%include "defines.asm"
%define MAX_EVENTS 64

SECTION .text
    global  main
    extern  epoll_ctl
    extern  epoll_create
    extern  epoll_wait
    extern  exit
    extern  fcntl
    extern  get_errno
    extern  gethostbyname
    extern  htons
    extern  inet_ntoa
    extern  printf
    extern  select
    extern  snprintf
    extern  strlen
main:
    mov     dword[init_ebp],ebp
    mov     dword[init_esp],esp
    push    ebp
    mov     ebp,esp
    ;Count the args
    ;==============
    mov     ecx,dword[ebp+8]
    cmp     ecx,2
    jl      .usage

    push    1
    push    ebp
    call    getopt
    mov     ebx,eax
    mov     dword[target_host],ebx

    push    2
    push    ebp
    call    getopt
    mov     ebx,eax
    mov     dword[target_uri],ebx

    ; TODO: break apart URL
    ;push    host_buffer
    ;push    uri_buffer
    ;push    target_host
    ;call    parseUrl
    
    ;Grab the IP address of the host
    ;===============================
    push    dword[target_host]
    call    gethostbyname
    cmp     eax,0
    je      .gethostbyname_error
    mov     ebx,eax
    
    push    dword[ebx]
    push    printf_format_string   
    call    printf

    cld     ;clear direction flag
    mov     esi,ebx
    mov     edi,h_ent
    mov     ecx,hostent.size / 4
    rep     movsd

    push    dword[h_ent + hostent.h_name]
    push    printf_format_string
    call    printf

    ;extract the encoded addresses
    ;=============================
    mov     ebx,dword[h_ent + hostent.h_addr_list]
    mov     ecx,dword[ebx]
    mov     ebx,dword[ecx]
    mov     dword[target_host_nbo],ebx

    push    ebx
    call    inet_ntoa

    mov     dword[target_host_ip],eax

    push    eax
    push    printf_format_string
    call    printf    

    ;create a socket descriptor
    ;==========================
    mov     eax,SOCKET_SYSCALL  ;socket syscall
    mov     ebx,SYS_SOCKET      ;socket()

    push    IPPROTO_IP          ;IPPROTO_IP
    push    SOCK_STREAM         ;SOCK_STREAM
    push    AF_INET             ;AF_INET
    mov     ecx,esp
    int     0x80
    
    ;save the socket descriptor
    ;===========================
    mov     dword[socket],eax
    cmp     eax,0
    jl      .socket_error

    
    ;Fill in the sockaddr_in structure
    ;=================================
    push    80
    call    htons
    mov     word[s_addr + sockaddr_in.sin_port],ax
    mov     word[s_addr + sockaddr_in.sin_family],2
    mov     esi,[target_host_nbo]
    mov     dword[s_addr + sockaddr_in.sin_addr],esi
    ;create the arguments on the stack
    ;=================================
    push    sockaddr_in.size
    push    s_addr
    push    dword[socket]
    mov     ecx,esp
    ;connect
    ;=======
    mov     eax,SOCKET_SYSCALL
    mov     ebx,SYS_CONNECT
    int     0x80
    cmp     eax,0
    jl      .connect_error
    
    ;=====================
    ;we are now connected. 
    ;=====================

    ;make the socket non-blocking
    ;============================
    push    0
    push    F_GETFL
    push    dword[socket]
    call    fcntl
    cmp     eax,-1
    je      .fcntl_error
    or      eax,O_NONBLOCK
    push    eax
    push    F_SETFL
    push    dword[socket]
    call    fcntl
    cmp     eax,-1
    je      .fcntl_error

    ;setup an epoll descriptor
    ;========================
    push    1
    call    epoll_create
    cmp     eax,-1
    je      .epoll_create_error 
    mov     dword[epoll_event_handle],eax
    mov     eax,dword[socket]
    mov     dword[e_event + epoll_event.fd],eax
    mov     ebx,EPOLLIN
    mov     ecx,EPOLLET
    or      ebx,ecx
    mov     dword[e_event + epoll_event.events],ebx


    ;add our socket to epolls watchlist
    ;==================================
    push    e_event
    push    dword[socket]
    push    EPOLL_CTL_ADD
    push    dword[epoll_event_handle]
    call    epoll_ctl
    cmp     eax,-1
    je      .epoll_ctl_error
    
    mov     dword[ctr],0
    

    ;create a buffer on the stack to store our send buffer
    ;=====================================================
    push    snprintf_get_string
    call    strlen
    push    eax                 ;save snprintf strlen
    push    dword[target_uri]
    call    strlen
    add     esp,4
    push    eax                 ;save target_uri strlen
    push    dword[target_host]
    call    strlen  
    add     esp,4
    mov     ebx,eax
    pop     ecx
    pop     edx
    add     eax,ecx
    add     eax,edx

    ;generate our send buffer
    ;========================
    sub     esp,eax
    push    dword[target_host]
    push    dword[target_uri]
    push    snprintf_get_string
    push    eax
    mov     ecx,esp
    add     ecx,16
    push    ecx
    call    snprintf
    add     esp,20
    
    push    esp
    call    strlen
    add     esp,4
    mov     edi,eax
    mov     edx,esp
    
    ;send our GET request
    ;====================
    mov     dword[target_send_buffer],esp
    mov     eax,SOCKET_SYSCALL
    mov     ebx,SYS_SEND
    push    0
    push    edi
    push    edx
    push    dword[socket]
    mov     ecx,esp
    int     0x80
    cmp     eax,0
    jl      .send_error

    ;receive the headers
    ;===================
    sub     esp,dword[readbuff_size]
    mov     dword[readbuff],esp
    

.epoll_wait_loop:
    push    -1
    push    MAX_EVENTS
    push    e_event_list
    push    dword[epoll_event_handle]
    call    epoll_wait
    cmp     eax,0
    jle      .end_epoll_wait_loop

.read_start:
    ;clear the buffer
    ;================
    mov     ecx,0
    mov     ebx,dword[readbuff]
    .clear_buffer_loop:
    mov     dword[ebx+ecx],0
    inc     ecx
    cmp     ecx,dword[readbuff_size]
    je      .end_clear_buffer_loop
    jmp     .clear_buffer_loop
    .end_clear_buffer_loop:

    mov     eax,SOCKET_SYSCALL
    mov     ebx,SYS_RECV
    push    0
    push    dword[readbuff_size]
    push    dword[readbuff]
    push    dword[socket]
    mov     ecx,esp
    int     0x80
    push    eax
    
    cmp     eax,0
    je      .end_epoll_wait_loop
    push    dword[readbuff]
    push    printf_format_raw_string
    call    printf
    add     esp,8

    pop     eax
    cmp     eax,0
    jl      .check_eagain
    jz      .end_epoll_wait_loop
    jmp     .read_start

.check_eagain:
    jmp     .epoll_wait_loop

.end_epoll_wait_loop:
    



.close:
    mov     eax,SOCKET_SYSCALL
    mov     ebx,SYS_SHUTDOWN
    push    dword[socket]
    push    dword[socket]
    mov     ecx,esp
    int     0x80
    jmp     .leaveMain
    
.usage:
    push    usage
    push    printf_format_string
    call    printf
    jmp     .leaveMain
.epoll_ctl_error:
    push    error_epoll_ctl
    push    printf_format_string
    call    printf
    jmp     .leaveMain
.epoll_create_error:
    push    error_epoll_create
    push    printf_format_string
    call    printf
    jmp     .leaveMain
.fcntl_error:
    push    error_fcntl
    push    printf_format_string
    call    printf
    jmp     .leaveMain
.socket_error:
    push    error_socket
    push    printf_format_string
    call    printf
    jmp     .leaveMain
.select_error:
    push    error_select
    push    printf_format_string
    call    printf
    jmp     .leaveMain
    
.recv_error:
    push    error_recv
    push    printf_format_string
    call    printf
    jmp     .leaveMain
.send_error:
    push    error_send
    push    printf_format_string
    call    printf
    jmp     .leaveMain

.connect_error:
    push    error_connect
    push    printf_format_string
    call    printf
    jmp     .leaveMain
.gethostbyname_error:
    push    error_gethostbyname
    push    printf_format_string
    call    printf
    jmp     .leaveMain
.leaveMain:
    mov     ebp,[init_ebp]
    mov     esp,[init_esp]
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
connect_format_string: db '%s:80',0
ctr: dd 0 
epoll_event_handle: dd 0 
error_connect: db 'error: connect()',0
error_epoll_create: db 'error: epoll_create()',0
error_epoll_ctl: db 'error: epoll_ctl()',0
error_fcntl: db 'error: fcntl()',0
error_gethostbyname: db 'error: gethostbyname()',0
error_recv: db 'error: recv()',0
error_select: db 'error: select()',0
error_send: db 'error: send()',0
error_socket: db 'error: socket()',0
hostent_ptr: dd 0
init_ebp: dd 0
init_esp: dd 0 
options: db 'h:p:',0
printf_format_char: db '%c',0xa,0xd,0
printf_format_int: db '%d',0xa,0xd,0
printf_format_raw_string: db '%s',0xa,0xd,0
printf_format_string: db '%s',0xa,0xd,0
readbuff: dd 0
readbuff_ctr: dd 0
readbuff_size: dd 2048
socket: dd 0
socket_ptr: dd 0
target_host: dd 0
target_host_ip: dd 0
target_host_nbo: dd 0
target_send_buffer: dd 0
target_uri: dd 0
snprintf_get_string: db 'GET %s HTTP/1.1',0xa,0xd,
                    db  'Host: %s',0xa,0xd,
                    db  'Connection: cose',0xa,0xd,
                    db 0xa,0xd,0
usage: db 'Usage: ./a.out <hostname> <uri>',0xa,0xd,
       db 'Example: ./a.out google.com /index.html',0

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
