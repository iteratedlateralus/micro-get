%include "args.asm"
%include "socket.asm"

SECTION .text
    global  main
    extern  exit
    extern  printf
    extern  snprintf
    extern  strlen
    extern  get_argv_opt
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

    mov     ebx,dword[ebp+12]
    mov     ecx,dword[ebx+4]
    mov     dword[target_host],ecx

    mov     ebx,dword[ebp+12]
    mov     ecx,dword[ebx+8]
    mov     dword[target_uri],ecx

    ;Grab the IP address of the host
    ;===============================
    push    dword[target_host]
    call    resolve_host
    cmp     eax,0
    jle     .gethostbyname_error
    mov     dword[target_host_nbo],eax

    push    dword[target_host_nbo]
    call    inet_ntoa

    mov     dword[target_host_ip],eax

    push    eax
    push    printf_format_string
    call    printf    

    call    create_socket

    ;save the socket descriptor
    ;===========================
    mov     dword[socket],eax
    cmp     eax,0
    jl      .socket_error
    
    ;connect
    ;=======
    push    dword[target_host_nbo]
    push    80
    push    dword[socket]
    call    connect_to_host
    cmp     eax,0
    jl      .connect_error
    
    ;=====================
    ;we are now connected. 
    ;=====================

    ;make socket non-blocking
    ;========================
    push    dword[socket]
    call    make_socket_nonblocking
    cmp     eax,0
    jl      .make_socket_nonblocking_error
    

    ;setup an epoll descriptor
    ;========================
    push    dword[socket]
    call    register_epoll
    cmp     eax,0
    jl      .register_epoll_error
    mov     dword[epoll_event_handle],eax

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
    push    edi                         ;length
    push    dword[target_send_buffer]   ;buffer
    push    dword[socket]               ;socket descriptor
    call    send_data
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

    push    dword[readbuff_size]
    push    dword[readbuff]
    push    dword[socket]
    call    recv_data
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
.make_socket_nonblocking_error:
    push    error_make_socket_nonblocking
    push    printf_format_string
    call    printf
    jmp     .leaveMain
.register_epoll_error:
    push    error_register_epoll
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







SECTION .data
connect_format_string: db '%s:80',0
ctr: dd 0 
epoll_event_handle: dd 0 
error_connect: db 'error: connect()',0
error_epoll_create: db 'error: epoll_create()',0
error_epoll_ctl: db 'error: epoll_ctl()',0
error_fcntl: db 'error: fcntl()',0
error_gethostbyname: db 'error: gethostbyname()',0
error_make_socket_nonblocking: db 'error: make_socket_nonblocking()',0
error_recv: db 'error: recv()',0
error_register_epoll: db 'error: register_epoll()',0
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
