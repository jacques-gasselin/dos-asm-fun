; Simple program image editing program using mode 13h
; 
; vim:set ft=nasm
org 100h

section .data
msg     db 'thx for playing', '$'
menuStr db '@', 0
fileStr db 'File', 0
editStr db 'Edit', 0

fontSeg dw 0
fontOffset dw 0

section .text

start:

    ; vga 320x200 @ 256 colors
    mov ax, 13h
    int 10h

    ; mouse init (soft)
    mov ax, 21h
    int 33h

    ; mouse show
    mov ax, 1
    int 33h
    
    push bp     ; push bp as int 10h [1130h] clobbers it

    ; get ROM 8x8 font adress
    mov ax, 1130h
    mov bh, 03h     ; request 8x8 font addr
    int 10h

    ; es:bp is font addr, move it to globals
    mov ax, es
    mov [fontSeg], ax
    mov [fontOffset], bp

    pop bp

    ; make es point to the framebuffer
    mov ax, 0a000h
    mov es, ax

    ; Draw Menu
    mov di, 0
    mov cx, 160         ; one row
    mov ax, 1f1fh
    rep stosw
    mov cx, 160 * 9
    mov ax, 1e1eh
    rep stosw
    mov cx, 160
    mov ax, 1d1dh
    rep stosw
    mov di, 0

    mov bx, 2
    mov dx, 001eh   ; (bg = 1eh & transparent, fg = black)
    
    mov ax, 1
    mov cx, menuStr
    call drawString8x8Embossed

    add ax, 20
    mov cx, fileStr
    call drawString8x8Embossed

    add ax, 40
    mov cx, editStr
    call drawString8x8Embossed


.loop:
        ; get mouse state
        mov ax, 3
        int 33h

    .isButton1Down:
        ; paint if mouse left is down
        cmp bx, 1
        jne .isKeyEscPressed

        ; mouse hide
        mov ax, 2
        int 33h

        ; interact at x = cx, y = dx
        shr cx, 1    ; x is [0, 640] so divide by 2, shift right 1

        ; mouse show
        mov ax, 1
        int 33h

    .isKeyEscPressed:
        ; is a key pressed? 
        mov ax, 100h
        int 16h
        jz  .loop
        ; yes a key is pressed, is it ESC?
        mov ax, 0
        int 16h
        cmp ah, 1   ; scancode == ESC
        jne .loop
        ; ESC was pressed, time to shut down

    ; mouse reset
    mov ax, 21h
    int 33h

    ; back to text mode
    mov ax, 3
    int 10h

    ; print msg
    mov dx, msg
    mov ah, 9
    int 21h

    ; exit to DOS
    mov ah, 4ch
    int 21h


; ---- Helper functions -----

_offsetDI_XY: ;ax=x, bx=y
    push ax
    push dx
    mov dx, bx
    shl dx, 2
    add dx, bx
    shl dx, 6
    add ax, dx
    mov di, ax
    pop dx
    pop ax
    ret

hline: ; ax=x, bx=y, cx=width, dx=color 
    call _offsetDI_XY
    mov ax, dx
    push cx
    rep stosb
    pop cx
    pop ax
    ret 

drawChar8x8:
    ; ax = char (clobbered)
    ; fontSeg:fontOffset points to the char definitions
    ; es:di points to upperleft pixel in destination
    ; dx=color (bg = dl, fg = dh)
    push ax
    push ds
    push si
    mov si, [fontOffset]
    shl ax, 3
    add si, ax
    mov ax, [fontSeg]
    mov ds, ax

    mov cx, 8
.eachRow:
        push cx
        lodsb
        mov ah, al
        mov cx, 8
    .eachColumn:
            shl ah, 1
            jnc .pickBgColor
            mov al, dh ; left most bit was 1 so we paint with foreground
            jmp .drawPixel
        .pickBgColor:
            mov al, dl ; left most bit was 0 so we paint with background
        .drawPixel:
            cmp al, 0ffh    ; is it transparent?
            jne  .opaquePixel
            inc di
            jmp .drawPixelDone
        .opaquePixel:
            stosb
        .drawPixelDone:
            loop .eachColumn

        ; go to next row, pitch of 320 - 8 pixels we just drew 
        add di, 320 - 8
        pop cx
        loop .eachRow

    pop si
    pop ds
    pop ax
    ret

    ;ax=x, bx=y, cx=str, dh=fg-color, dl=bg-color
drawString8x8Embossed:
    push dx
    inc bx
    mov dh, dl
    mov dl, 0ffh        ; transparent
    inc dh              ; bg highlight below
    call drawString8x8
    sub bx, 2
    sub dh, 2           ; bg shadow above
    call drawString8x8
    inc bx
    pop dx
    push dx
    mov dl, 0ffh        ; keep dh=fg color for actual text
    call drawString8x8
    pop dx
    ret

    ;ax=x, bx=y, cx=str, dx=color
drawString8x8:
    ; assumes 8x8 font definition is in globals 
    push ax
    push bx
    push cx

    call _offsetDI_XY
    

    mov bx, cx      ; bx can be used as a pointer while cx can't
.eachChar:
    xor ax, ax
    mov al, [bx]    ; al = *(str++)
    inc bx
    cmp al, 0
    je  .finished

    push di
    call drawChar8x8
    pop di

    ; use an advance of 8 unless we have a tiny char like 'i', then use 7
    cmp al, 'i'
    je .tightAdvance
    cmp al, 'l'
    je .tightAdvance
    add di, 1
.tightAdvance:
    add di, 7
    jmp .eachChar
    
.finished:

    pop cx
    pop bx
    pop ax
    ret

