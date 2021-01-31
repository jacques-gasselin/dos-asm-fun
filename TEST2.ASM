; vim:set ft=nasm
org 100h

section .data
msg db 'thx for playing', '$'
section .text

start:

	; vga 320x240 @ 256 colors
	mov	ax, 13h
	int	10h

	; mouse init (soft)
	mov	ax, 21h
	int	33h

	; mouse show
	mov	ax, 1
	int 33h

    ; make es point to the framebuffer
    mov ax, 0a000h
    mov es, ax

    ; Draw Menu
    mov di, 0
    mov cx, 160
    mov ax, 1f1fh
    rep stosw
    mov cx, 1280
    mov ax, 1e1eh
    rep stosw
    mov cx, 160
    mov ax, 1d1dh
    rep stosw

    ; FIXME: use int 10h, ax=1130h to get the character bitmaps
    mov ax, 0e46h ; F
    mov bx, 1fh
    int 10h
    mov ax, 0e49h ; I
    mov bx, 1fh
    int 10h


loop:
	; get mouse state
	mov	ax, 3
	int	33h

isButton1Down:
	; paint if mouse left is down
	cmp bx, 1
	jne	isKeyEscPressed

    ; mouse hide
    mov ax, 2
    int 33h

	; paint at x = cx, y = dx
	mov	ax, 320
	mul dx       ; ax is y * 320
	shr cx, 1    ; x is [0, 640] so divide by 2, shift right 1
	add ax, cx   ; ax = y * 200 + x
	mov di, ax   ; di is offset into video memory

	mov	ax, 4dh  ; light cyan
	stosb

    ; mouse show
    mov ax, 1
    int 33h

isKeyEscPressed:
	; is a key pressed? 
    mov ax, 100h
    int 16h
	jz	loop
    ; yes a key is pressed, is it ESC?
    mov ax, 0
    int 16h
    cmp ah, 1   ; scancode == ESC
    jne loop
    ; ESC was pressed, time to show down

	; mouse reset
	mov	ax, 21h
	int 33h

	; back to text mode
	mov	ax, 3
	int	10h

	; print msg
	mov	dx, msg
	mov	ah, 9
	int	21h

	; exit to DOS
	mov	ah, 4ch
	int	21h

hline: ; ax=x, bx=y, cx=width, dx=color 
    push ax
    push dx
    mov dx, ax
    mov ax, 320
    mul bx
    add ax, dx
    mov di, ax

    pop dx
    mov ax, dx
    push cx
    rep stosb
    pop cx
    pop ax
    ret 

