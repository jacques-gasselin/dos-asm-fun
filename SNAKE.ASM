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

VGA_SEGMENT         equ 0a000h

%macro  moveToPixel 2 ; x, y
%ifnum %2
    mov di, %2 * 320
%else
    mov di, %2      ; di = y
    shl di, 2       ; di = y * 4
    add di, %2      ; di = y * 5
    shl di, 6       ; di = y * 5 * 64 = y * 320
%endif
%if %1 != 0
    add di, %1
%endif
%endmacro

section .bss
mainLoopTicks       resd 1

gameState           resb 1
gameStateTicks      resd 1

currentLevel        resb 1   

nextMoveDirection   resb 1      ; UP, DOWN, LEFT, RIGHT
snakeHeadPosition   resb 2      ; x, y

section .text

start:
    ; vga 320x200 @ 256 colors
    mov ax, 13h
    int 10h

    ; make es point to the framebuffer
    mov ax, VGA_SEGMENT
    mov es, ax

    ; init the global variables
    mov dword [mainLoopTicks], 0
    mov byte [gameState], STATE_INTRO
    mov dword [gameStateTicks], 0

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

    ; Update the number of game ticks
    mov eax, [mainLoopTicks]
    inc eax
    mov [mainLoopTicks], eax

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
    ;cmp ah, 48h     ; up-arrow
    ;cmp ah, 4bh     ; left-arrow
    ;cmp ah, 4dh     ; right-arrow
    ;cmp ah, 50h     ; down-arrow
    ret

; al = new state
ChangeState:
    mov ah, [gameState]
    cmp ah, al
    je .return

    mov [gameState], al
    mov dword [gameStateTicks], 0
    ; TODO use jump table
    
    .return:
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
        mov eax, [gameStateTicks]
        cmp eax, 1000
        jl  .endCase
        mov al, STATE_NEW_LEVEL
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
    
    .return:
    mov eax, [gameStateTicks]
    inc eax
    mov [gameStateTicks], eax
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
    jne .level1
    call DrawLevel0
    jmp .return
    .level1:
    cmp al, 1
    jne .level2
    call DrawLevel1
    jmp .return
    .level2:
    .return:
    ret

DrawLevel0:
    moveToPixel 0, 0
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

    .return:
    ret

DrawLevel1:
    .return:
    ret

DrawSnake:
    ; TODO draw the actual snake as it moves
    moveToPixel 160, 100
    mov eax, 0a0a0a0ah
    stosd
    add di, 320 - 4
    stosd
    add di, 320 - 4
    stosd
    add di, 320 - 4
    stosd

    .return:
    ret

