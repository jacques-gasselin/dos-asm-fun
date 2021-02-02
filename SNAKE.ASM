org 100h

section .text

start:
    ; vga 320x200 @ 256 colors
    mov ax, 13h
    int 10h

    ; make es point to the framebuffer
    mov ax, 0a000h
    mov es, ax

.mainLoop:
    
    .handleKeyEvents:
    mov ax, 100h
    int 16h
    jz .afterKeyEventHandler

    mov ax, 0
    int 16h

    ; ah = scancode, al = char

    ; TODO handle player movement here

    cmp ah, 1 ; ESC
    je .endGame

    ; check if there are more keys to grab
    jmp .handleKeyEvents

    .afterKeyEventHandler:
    
    mov ax, 0           ; level number
    call DrawLevel
    call DrawSnake

    jmp .mainLoop


.endGame:
    
    ; back to text mode
    mov ax, 3
    int 10h

    ; exit to DOS
    mov ah, 4ch
    int 21h

; ax = level
DrawLevel:
    cmp ax, 0
    jne .next
    call DrawLevel0
.next:
    ret

DrawLevel0:
    mov di, 0
    mov al, 09h             ; level color
    mov ah, al
    push ax
    push ax
    pop eax                 ; replicate to 4 bytes
    mov cx, (320 / 4) * 4   ; 4 rows
    .topRow:
    rep stosd

    mov cx, 200 - 8         ; all rows but 8
    .leftAndRight:
    stosd
    add di, 320 - 8
    stosd
    loop .leftAndRight

    mov cx, (320 / 4) * 4   ; 4 rows
    .bottomRow:
    rep stosd

    ret


DrawSnake:
    ; TODO draw the actual snake as it moves
    mov di, 100 * 320 + 160
    mov eax, 0a0a0a0ah
    stosd
    add di, 320 - 4
    stosd
    add di, 320 - 4
    stosd
    add di, 320 - 4
    stosd

    ret

