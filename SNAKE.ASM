; Simple VGA 'snake' game
;
; TODO
; - Apples 
; - Eating Apple make you longer
; - Crashing into walls
; - Crashing into self
; - Movement speed should be variable
;

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

SNAKE_MAX_LENGTH    equ 512

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
lastMoveDirection   resb 1      ; UP, DOWN, LEFT, RIGHT

snakeBodyLength     resw 1
; snake head is first entry
; snake tail is last entry
snakeBodyPositions  resb SNAKE_MAX_LENGTH * 2 ;x,y for each body segment


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
    mov byte [nextMoveDirection], 0
    mov byte [lastMoveDirection], 0
    mov word [snakeBodyLength], 0

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
    push bx
    xor bx, bx
    mov bl, [lastMoveDirection]

    .checkUpArrow:
    cmp ah, 48h     ; up-arrow
    jne .checkLeftArrow
    cmp bl, MOVE_DOWN
    je .checkLeftArrow
    mov byte [nextMoveDirection], MOVE_UP
    jmp .return

    .checkLeftArrow:
    cmp ah, 4bh     ; left-arrow
    jne .checkRightArrow
    cmp bl, MOVE_RIGHT
    je .checkRightArrow
    mov byte [nextMoveDirection], MOVE_LEFT
    jmp .return

    .checkRightArrow:
    cmp ah, 4dh     ; right-arrow
    jne .checkDownArrow
    cmp bl, MOVE_LEFT
    je .checkDownArrow
    mov byte [nextMoveDirection], MOVE_RIGHT
    jmp .return

    .checkDownArrow:
    cmp ah, 50h     ; down-arrow
    jne .return
    cmp bl, MOVE_UP
    je .return
    mov byte [nextMoveDirection], MOVE_DOWN

    .return:
    pop bx
    ret

; al = new state
ChangeState:
    mov ah, [gameState]
    cmp ah, al
    je .return

    xor bx, bx
    mov bl, [gameState]
    shl bx, 1
    jmp [bx + .switchJumpTable]
    .switchJumpTable:
        dw .endCase
        dw .caseNewLevel
        dw .caseInLevel
        dw .caseAteApple
        dw .caseCrashed
        dw .caseGameOver
    .caseNewLevel:
        call SetupLevel
        jmp .endCase
    .caseInLevel:
        jmp .endCase
    .caseAteApple:
        ; TODO increment score and check for win condition
        mov al, STATE_IN_LEVEL
        jmp .endCase
    .caseCrashed:
        ; TODO show a restart or quit message
        mov al, STATE_GAMEOVER
        jmp .endCase
    .caseGameOver:
        jmp .endCase
    .endCase:

    mov [gameState], al
    mov dword [gameStateTicks], 0
    
    .return:
    ret

Update:
    xor bx, bx
    mov bl, [gameState]
    shl bx, 1
    jmp [bx + .switchJumpTable]
    .switchJumpTable:
        dw .caseIntro
        dw .caseNewLevel
        dw .caseInLevel
        dw .caseAteApple
        dw .caseCrashed
        dw .caseGameOver
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
        and eax, 07fh               ; only move once 127 ticks have passed since last time
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

SetupLevel:
    push ax
    push bx

    ; clear out the snake body
    mov bx, 10
    mov [snakeBodyLength], bx
    
    shl bx, 1
    mov ax, (160 / 4) - 10
    .loop:
        mov byte [bx + snakeBodyPositions], al
        mov byte [bx + snakeBodyPositions + 1], 100 / 4
        inc ax
        sub bx, 2
        jge .loop

    ; TODO clear out the board

    ; Start heading right
    mov byte [nextMoveDirection], MOVE_RIGHT

    .return:
    pop bx
    pop ax
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

    ; move all the snake segments down one step
    mov bx, [snakeBodyLength]
    shl bx, 1
    .loop:
        mov ax, [bx + snakeBodyPositions - 2]
        mov [bx + snakeBodyPositions], ax
        sub bx, 2
        jnz .loop
    
    .moveHead:
    xor ax, ax
    xor bx, bx

    mov al, [snakeBodyPositions + 0]
    mov bl, [snakeBodyPositions + 1]

    ; check the direction
    xor cx, cx
    mov cl, [nextMoveDirection]
    ; store it so that we can prevent going back over yourself
    mov [lastMoveDirection], cl
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
    jl .noWrapRight
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
    jl .noWrapDown
    sub bx, 200 / 4
    .noWrapDown:

    mov [snakeBodyPositions + 0], al
    mov [snakeBodyPositions + 1], bl

    .return:
    pop cx
    pop bx
    ret

DrawSnake:
    push bx

    mov cx, [snakeBodyLength]
    cmp cx, 1
    jl .return

    .eraseLastTail:
    colorDuplicated4TimeInEAX 0
    call localFuncDrawBodySegment
    dec cx

    .drawBody:
    colorDuplicated4TimeInEAX SNAKE_COLOR
    .loop:
        call localFuncDrawBodySegment
        dec cx
        jge .loop

    .return:
    pop bx
    ret

    ; eax = 4 x color, cx = segment index
    ; bx, dx, di clobbered
    localFuncDrawBodySegment:
        push cx
        mov bx, cx
        shl bx, 1
        add bx, snakeBodyPositions
        xor dx, dx
        xor cx, cx
        mov cl, [bx]
        mov dl, [bx + 1]
        ; make them into pixel -> cell coorinates * 4 = pixel coordinates
        shl cx, 2
        shl dx, 2
        moveDiToPixel cx, dx
        stosd
        add di, 320 - 4
        stosd
        add di, 320 - 4
        stosd
        add di, 320 - 4
        stosd
        pop cx
        ret
