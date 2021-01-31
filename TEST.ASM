org 100h

section .data
msg db 'thx for playing', '$'

section .text
start:

	; vga 320x200 @ 256 colors
	mov	ax, 13h
	int	10h


	;mouse init
	xor	ax, ax
	int	33h

	;mouse show
	mov	ax, 1
	int 33h

loop:
	;get mouse state
	mov	ax, 3
	int	33h

isButton1Down:
	;paint if mouse left is down
	cmp bx, 1
	jne	isButton2Down

	;paint at x = cx, y = dx
	mov	ax, 320
	mul dx       ; ax is y * 320
	shr cx, 1    ; x is [0, 640] so divide by 2, shift right 1
	add ax, cx   ; ax = y * 200 + x
	mov di, ax   ; di is offset into video memory

	mov ax, 0a000h ; point to VGA buffer
	mov	es, ax
	mov	ax, 4dh  ; light cyan
	stosb

isButton2Down:
	;is right button down?
	cmp	bx, 2
	jne	loop


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


