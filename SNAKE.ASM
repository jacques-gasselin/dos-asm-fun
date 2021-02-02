org 100h

STATE_INTRO         equ 0
STATE_NEW_LEVEL     equ 1
STATE_IN_LEVEL      equ 2
STATE_ATE_APPLE     equ 3
STATE_CRASHED       equ 4
STATE_GAMEOVER      equ 5

MOVE_UP             equ 1
MOVE_DOWN           equ 2
MOVE_LEFT           equ 3
MOVE_RIGHT          equ 4

section .bss
gameState           resb 1

currentLevel        resb 1   

nextMoveDirection   resb 1      ; UP, DOWN, LEFT, RIGHT
snakeHeadPosition   resb 2      ; x, y

section .text

start:
    ; vga 320x200 @ 256 colors
    mov ax, 13h
    int 10h

    ; make es point to the framebuffer
    mov ax, 0a000h
    mov es, ax

    mov byte [gameState], STATE_INTRO

.mainLoop:
    
    .keyEventLoop:
    mov ax, 100h
    int 16h
    jz .afterKeyEventHandler

    mov ax, 0
    int 16h

    ; ah = scancode, al = char
    call HandleKeyEvent

    cmp ah, 1 ; ESC
    je .endGame

    ; check if there are more keys to grab
    jmp .keyEventLoop

    .afterKeyEventHandler:

    call Update
    
    call Draw

    jmp .mainLoop


.endGame:
    
    ; back to text mode
    mov ax, 3
    int 10h

    ; exit to DOS
    mov ah, 4ch
    int 21h


; ah = scancode, al = character
HandleKeyEvent:
    ret

; al = new state
ChangeState:
    ret

Update:
    mov al, [gameState]
    mov ah, 0
    ; TODO make jump table work
    ; jmp .jumpTable[ax * 2]
    ; .jumpTable dw .caseIntro, .caseNewLevel, .caseInLevel, .caseAteApple, .caseCrashed, .caseGameOver, .endCase
    .startCase:
    cmp al, STATE_INTRO
    je .caseIntro
    cmp al, STATE_NEW_LEVEL
    je .caseNewLevel
    cmp al, STATE_IN_LEVEL
    je .caseInLevel
    cmp al, STATE_ATE_APPLE
    je .caseAteApple
    cmp al, STATE_CRASHED
    je .caseCrashed
    cmp al, STATE_GAMEOVER
    je .caseGameOver
    jmp .endCase
    .caseIntro:
        mov byte [currentLevel], 0
        call ChangeState
        jmp .endCase
    .caseNewLevel:
        jmp .endCase
    .caseInLevel:
        jmp .endCase
    .caseAteApple:
        jmp .endCase
    .caseCrashed:
        jmp .endCase
    .caseGameOver:
        jmp .endCase
    .endCase:

    ret

Draw:
    mov al, [currentLevel]    ; level number
    call DrawLevel
    call DrawSnake
    ret

; ax = level
SetupLevel:
    ret

; al = level
DrawLevel:
    cmp al, 0
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

