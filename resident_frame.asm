.model tiny
.286
.code
org 100h

window_width equ 35
window_height equ 5
box_width equ window_width - 2
box_height equ window_height - 2
window_x equ 22
window_y equ 10
window_text_width equ 33
window_row_bytes equ window_width * 2
window_text_bytes equ window_text_width * 2
window_skip equ 160 - window_row_bytes
VRAM equ 0B800h

start:
    jmp init

old_int09 dd 0
old_int1c dd 0

pos_x db 0
pos_y db 0
color db 0Fh
show_flag db 0
saved_flag db 0

line1  db " AX="
str_ax db "0000 BX="
str_bx db "0000 CX="
str_cx db "0000 DX="
str_dx db "0000 "

line2  db " SP="
str_sp db "0000 BP="
str_bp db "0000 SI="
str_si db "0000 DI="
str_di db "0000 "

line3  db " DS="
str_ds db "0000 ES="
str_es db "0000 SS="
str_ss db "0000 CS="
str_cs db "0000 "

border_str db 'T', 4eh, '7', 4eh, 'd', 4eh, 'L', 4eh, '-', 4eh, '|', 4eh
saved_screen dw 175 dup(?)

new_int09 proc
    push ax

    in al, 60h
    
    cmp al, 01h
    je esc_pressed

    cmp al, 3Fh
    je f5_pressed
    
    cmp al, 81h
    je esc_released
    
    pop ax
    jmp dword ptr cs:[old_int09]

esc_pressed:
    xor cs:show_flag, 1

    cmp cs:show_flag, 0
    je esc_hide
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es
    call draw_window
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    jmp esc_released

esc_hide:
    cmp cs:saved_flag, 1
    jne esc_released
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es
    call restore_window
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    mov cs:saved_flag, 0

    jmp esc_released

f5_pressed:
    cmp cs:saved_flag, 1
    jne @@unload
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es
    call restore_window
    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
@@unload:
    mov cs:saved_flag, 0
    mov cs:show_flag, 0
    call uninstall_tsr

esc_released:
    in al, 61h
    mov ah, al
    or al, 80h
    out 61h, al         
    mov al, ah
    out 61h, al
    
    mov al, 20h
    out 20h, al
    
    pop ax
    iret
new_int09 endp

;; uninstall_tsr - restore old vectors
; in:
; out:
; destr: AX, ES
uninstall_tsr proc
    xor ax, ax
    mov es, ax

    mov ax, word ptr cs:[old_int09]
    mov word ptr es:[9h*4], ax
    mov ax, word ptr cs:[old_int09+2]
    mov word ptr es:[9h*4+2], ax

    mov ax, word ptr cs:[old_int1c]
    mov word ptr es:[1Ch*4], ax
    mov ax, word ptr cs:[old_int1c+2]
    mov word ptr es:[1Ch*4+2], ax
    ret
uninstall_tsr endp

;; window_offset - get top-left offset of frame
; in:
; out: DI=offset
; destr: AX, BX, CX, DX
window_offset proc
    mov dx, 2000-2

    mov cx, ax

    sub dx, ax
    and dx, 0FFFEh

    mov al, 160
    shr bl, 1
    mul bl

    sub dx, ax
    and dx, 0FFFEh

    mov di, dx
    ret
window_offset endp

;; save_window - save screen area under frame
; in:
; out:
; destr: AX, BX, CX, SI, DI, DS, ES
save_window proc
    cld

    mov ax, VRAM
    mov ds, ax
    push cs
    pop es

    mov ax, box_width
    mov bx, box_height
    call window_offset
    mov si, di
    mov di, offset saved_screen
    mov bx, window_height
@@save_row:
    mov cx, window_width
    rep movsw
    add si, window_skip
    dec bx
    jnz @@save_row
    ret
save_window endp

;; restore_window - restore screen area under frame
; in:
; out:
; destr: AX, BX, CX, SI, DI, DS, ES
restore_window proc
    cld

    push cs
    pop ds
    mov ax, VRAM
    mov es, ax

    mov ax, box_width
    mov bx, box_height
    call window_offset
    mov si, offset saved_screen
    mov bx, window_height
@@restore_row:
    mov cx, window_width
    rep movsw
    add di, window_skip
    dec bx
    jnz @@restore_row

    ret
restore_window endp

new_int1c proc
    pushf
    call dword ptr cs:[old_int1c]

    cmp cs:show_flag, 1
    je do_render
    iret
do_render:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es

    push cs
    pop ds
    push cs
    pop es

    mov bp, sp

    mov ax, [bp+16]
    mov di, offset str_ax
    call word_to_hex

    mov ax, [bp+14]
    mov di, offset str_bx
    call word_to_hex

    mov ax, [bp+12]
    mov di, offset str_cx
    call word_to_hex

    mov ax, [bp+10]
    mov di, offset str_dx
    call word_to_hex

    mov ax, [bp+8]
    mov di, offset str_si
    call word_to_hex

    mov ax, [bp+6]
    mov di, offset str_di
    call word_to_hex

    mov ax, [bp+4]
    mov di, offset str_bp
    call word_to_hex

    mov ax, [bp+2]
    mov di, offset str_ds
    call word_to_hex

    mov ax, [bp+0]
    mov di, offset str_es
    call word_to_hex

    mov ax, [bp+22]
    mov di, offset str_cs
    call word_to_hex

    mov ax, ss
    mov di, offset str_ss
    call word_to_hex

    mov ax, bp
    add ax, 26
    mov di, offset str_sp
    call word_to_hex

    call draw_window

    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    iret
new_int1c endp

;; word_to_hex - convert ax to hex string
; in: AX=word, DI->str
; out:
; destr: AX, CX, DI
word_to_hex proc
    push cx
    mov cx, 4
hex_loop:
    rol ax, 4
    push ax
    and al, 0Fh
    cmp al, 9
    jbe is_digit
    add al, 7
is_digit:
    add al, '0'
    mov [di], al
    inc di
    pop ax
    loop hex_loop
    pop cx
    ret
word_to_hex endp

;; draw_window - draw frame and text
; in:
; out:
; destr: AX, BX, CX, DX, SI, DI, DS, ES
draw_window proc
    push cs
    pop ds

    cmp saved_flag, 1
    jne @@save
    call restore_window
@@save:
    call save_window
    push cs
    pop ds
    mov saved_flag, 1
@@draw:
    mov ax, box_width
    mov bx, box_height
    mov si, offset border_str
    call draw_box

    mov ax, VRAM
    mov es, ax
    mov ax, box_width
    mov bx, box_height
    call window_offset
    add di, 160 + 2
    mov ah, cs:color

    mov si, offset line1
    mov cx, window_text_width
    call print_line
    add di, 160 - window_text_bytes

    mov si, offset line2
    mov cx, window_text_width
    call print_line
    add di, 160 - window_text_bytes

    mov si, offset line3
    mov cx, window_text_width
    call print_line
    ret
draw_window endp

;; draw_box - draw box on the screen in colored text mode
; in: AX=width, BX=height, SI->border_str (6 word-chars: lt,rt,rb,lb,hor,ver)
; out: []
; destr: AX, BX, CX, DX, DI, BP, ES
draw_box proc
    cld
    mov dx, VRAM
    mov es, dx

    mov dx, 2000-2

    mov cx, ax

    sub dx, ax
    and dx, 0FFFEh

    mov al, 160
    mov bp, bx
    shr bl, 1
    mul bl
    mov bx, bp

    sub dx, ax
    and dx, 0FFFEh

    mov di, dx

    mov dx, cx

    lodsw
    stosw

    add si, 6
    lodsw
    sub si, 8

    rep stosw

    lodsw 
    stosw

    shl dx, 1
    sub di, dx
    shr dx, 1
    sub di, 4

    add si, 6
    lodsw
    mov cx, bx
@@drw_l:
    add di, 160
    stosw
    dec di
    dec di
    loop @@drw_l	

    add di, 160
    sub si, 6

    lodsw
    stosw

    lodsw

    mov cx, dx
    rep stosw

    sub si, 6

    lodsw
    stosw


    add si, 4
    lodsw

    mov cx, bx	

    dec di
    dec di

@@drw_r:
    sub di, 160
    stosw
    dec di
    dec di
    loop @@drw_r

    ret
draw_box endp

print_line proc
print_loop:
    lodsb
    stosw
    loop print_loop
    ret
print_line endp

init_end label byte

init proc	
;; install_tsr
    mov ax, 3509h
    int 21h
    mov word ptr old_int09, bx
    mov word ptr old_int09+2, es

    mov ax, 2509h
    mov dx, offset new_int09
    int 21h

    mov ax, 351Ch
    int 21h
    mov word ptr old_int1c, bx
    mov word ptr old_int1c+2, es

    mov ax, 251Ch
    mov dx, offset new_int1c
    int 21h

    mov dx, offset init_end
    int 27h
init endp
end start
