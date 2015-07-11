
SECTION .text
    extern  snprintf
    extern  strlen
    extern  strpos
    extern  strstr
    
explode_url:
    mov     dword[url_init_ebp],ebp
    mov     dword[url_init_esp],esp
    push    ebp
    mov     ebp,esp
    mov     eax,dword[ebp+8]
    mov     dword[url_target_host],eax
    mov     ebx,dword[ebp+12]
    mov     dword[url_positions_ptr],ebx
    ;look for the scheme delimiter
    ;=============================
    push    url_scheme_delimiter
    push    dword[url_target_host]
    call    strstr
    cmp     eax,0
    je      .no_scheme_delimter
    add     eax,3               ;Point past the delimiter
    mov     dword[url_target_host_ptr],eax  ;save the pointer
    add     esp,8               ;restore the stack pointer
    ;check for www.
    ;==============
    push    url_dub_dot
    push    dword[url_target_host_ptr]
    call    strstr
    cmp     eax,0
    je      .no_dub_dot
    ;if(strstr(target_host_ptr,"www.") == target_host_ptr){
    cmp     eax,dword[url_target_host_ptr]      
    je      .dub_dot_found
    ;}else{
    jmp     .no_dub_dot

.no_scheme_delimter:
    mov     eax,-1
    jmp     .leaveMain
.dub_dot_found:
    add     dword[url_target_host_ptr],4    ;point past the www.
    add     esp,8

.no_dub_dot:
    ;save everything until / or end of string is reached
    ;===================================================
    push    dword[url_target_host]
    call    strlen
    add     esp,4
    mov     ecx,0
    mov     esi,dword[url_target_host_ptr]
    mov     dword[url_host_name],esi

.save_loop:
    cmp     byte[esi+ecx],0
    je      .stop_saving
    cmp     byte[esi+ecx],'/'
    je      .save_uri
    cmp     byte[esi+ecx],':'
    je      .save_port
.resume_port:
    inc     ecx
    jmp     .save_loop
.stop_saving:
    mov     dword[url_host_name_end],esi
    add     dword[url_host_name_end],ecx
    jmp     .leaveMain
.save_uri:
    cmp     dword[url_host_name_end_saved],1
    je      .save_skip_host_name
    mov     dword[url_host_name_end],esi
    add     dword[url_host_name_end],ecx
.save_skip_host_name:
    mov     dword[url_target_uri],esi
    add     dword[url_target_uri],ecx
    jmp     .leaveMain
.save_port:
    mov     dword[url_host_name_end],esi
    add     dword[url_host_name_end],ecx
    mov     dword[url_host_name_end_saved],1
    mov     dword[url_port_start],esi
    add     dword[url_port_start],ecx
    inc     dword[url_port_start]
.save_port_loop:
    inc     ecx
    cmp     byte[esi+ecx],0
    je      .end_save_port_loop
    cmp     byte[esi+ecx],'/'
    je      .end_save_port_loop
    jmp     .save_port_loop
.end_save_port_loop:
    mov     dword[url_port_end],esi
    add     dword[url_port_end],ecx
    cmp     byte[esi+ecx],0
    je      .stop_saving
    dec     ecx
    jmp     .resume_port
    jmp     .leaveMain


.leaveMain:
    mov     esi,dword[url_host_name]
    mov     dword[url_positions_struct + url_positions.host_name_start],esi
    mov     esi,dword[url_host_name_end]
    mov     dword[url_positions_struct + url_positions.host_name_end],esi
    mov     esi,dword[url_port_start]
    mov     dword[url_positions_struct + url_positions.port_start],esi
    mov     esi,dword[url_port_end]
    mov     dword[url_positions_struct + url_positions.port_end],esi
    mov     esi,dword[url_target_uri]
    mov     dword[url_positions_struct + url_positions.uri_start],esi

    mov     esi,url_positions_struct
    mov     edi,dword[url_positions_ptr]
    cld
    mov     ecx,url_positions.size / 4
    rep     movsd

    mov     ebp,[url_init_ebp]
    mov     esp,[url_init_esp]
    ret


STRUC url_positions
.host_name_start: resd 1
.host_name_end: resd 1
.port_start: resd 1
.port_end: resd 1
.uri_start: resd 1
.size:
ENDSTRUC



SECTION .data
url_dub_dot: dd 'www.',0
url_host_name: dd 0
url_host_name_end: dd 0
url_host_name_end_saved: dd 0
url_init_ebp: dd 0
url_init_esp: dd 0 
url_msg_dub_dot_found: dd "www. found",0
url_msg_no_dub_dot: dd "No www. found",0
url_msg_no_scheme: dd "No scheme delimiter found",0
url_port_found: dd 0
url_port_end: dd 0 
url_port_start: dd 0
url_positions_ptr: dd 0
url_scheme_delimiter: dd '://',0
url_target_host: dd 0
url_target_host_ptr: dd 0
url_target_host_ptr_end: dd 0
url_target_port: dw 80
url_target_uri: dd 0

SECTION .bss
url_positions_struct: resb url_positions.size
url_positions_struct_l: EQU ($ - url_positions_struct) / url_positions.size

main_url_positions: resb url_positions.size
