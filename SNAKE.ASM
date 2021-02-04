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
TICKS_PER_SECOND    equ 10

SNAKE_COLOR         equ 0ah

%macro  moveDiToPixel 2 ; x, y
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

%macro  colorDuplicated4TimeInEAX 1 ; color as byte
    mov al, %1
    mov ah, al
    push ax
    push ax
    pop eax
%endmacro

section .bss
mainLoopTicks       resd 1

gameState           resb 1
gameStateTicks      resd 1

currentLevel        resb 1   

nextMoveDirection   resb 1      ; UP, DOWN, LEFT, RIGHT
snakeHeadPositionX  resb 1
snakeHeadPositionY  resb 1


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
    mov byte [snakeHeadPositionX], 160 / 4
    mov byte [snakeHeadPositionY], 100 / 4

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
    .checkUpArrow:
    cmp ah, 48h     ; up-arrow
    jne .checkLeftArrow
    mov byte [nextMoveDirection], MOVE_UP
    jmp .return

    .checkLeftArrow:
    cmp ah, 4bh     ; left-arrow
    jne .checkRightArrow
    mov byte [nextMoveDirection], MOVE_LEFT
    jmp .return

    .checkRightArrow:
    cmp ah, 4dh     ; right-arrow
    jne .checkDownArrow
    mov byte [nextMoveDirection], MOVE_RIGHT
    jmp .return

    .checkDownArrow:
    cmp ah, 50h     ; down-arrow
    jne .return
    mov byte [nextMoveDirection], MOVE_DOWN
    jmp .return

    .return:
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
    xor ax, ax
    mov al, [gameState]
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
        cmp eax, TICKS_PER_SECOND * 1
        jl  .endCase
        mov al, STATE_NEW_LEVEL
        call ChangeState
        jmp .endCase
    .caseNewLevel:
        mov eax, [gameStateTicks]
        cmp eax, TICKS_PER_SECOND * 1
        jl  .endCase
        mov al, STATE_IN_LEVEL
        call ChangeState
        jmp .endCase
    .caseInLevel:
        mov eax, [gameStateTicks]
        and eax, 0ffh               ; only move once 255 ticks have passed since last time
        jnz  .endCase
        call MoveSnake
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
    moveDiToPixel 0, 0
    colorDuplicated4TimeInEAX 09h      ; level 0 color
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

MoveSnake:
    push bx
    push cx
    xor ax, ax
    xor bx, bx
    xor cx, cx

    mov al, [snakeHeadPositionX]
    mov bl, [snakeHeadPositionY]

    ; check the direction
    mov cl, [nextMoveDirection]
    .startCase:
    cmp cl, MOVE_UP
    je .caseMoveUp
    cmp cl, MOVE_LEFT
    je .caseMoveLeft
    cmp cl, MOVE_RIGHT
    je .caseMoveRight
    cmp cl, MOVE_DOWN
    je .caseMoveDown
    jmp .endCase

    .caseMoveUp:
        dec bx
        jmp .endCase
    .caseMoveLeft:
        dec ax
        jmp .endCase
    .caseMoveRight:
        inc ax
        jmp .endCase
    .caseMoveDown:
        inc bx
        jmp .endCase
    .endCase:

    .checkWrapAroundRight:
    cmp ax, 320 / 4
    jle .noWrapRight
    sub ax, 320 / 4
    .noWrapRight:
    
    .checkWrapAroundLeft:
    cmp ax, 0
    jge .noWrapLeft
    add ax, 320 / 4
    .noWrapLeft:

    .checkWrapAroundUp:
    cmp bx, 0
    jge .noWrapUp
    add bx, 200 / 4
    .noWrapUp:
    
    .checkWrapAroundDown:
    cmp bx, 200 / 4
    jle .noWrapDown
    sub bx, 200 / 4
    .noWrapDown:

    mov [snakeHeadPositionX], al
    mov [snakeHeadPositionY], bl

    .return:
    pop cx
    pop bx
    ret

DrawSnake:
    ; TODO draw the actual snake as it moves
    push bx
    xor ax, ax
    xor bx, bx

    mov al, [snakeHeadPositionX]
    mov bl, [snakeHeadPositionY]
    ; make them into pixel -> cell coorinates * 4 = pixel coordinates
    shl ax, 2
    shl bx, 2
    moveDiToPixel ax, bx
    colorDuplicated4TimeInEAX SNAKE_COLOR
    stosd
    add di, 320 - 4
    stosd
    add di, 320 - 4
    stosd
    add di, 320 - 4
    stosd

    .return:
    pop bx
    ret

