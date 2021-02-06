; Simple VGA 'snake' game
;
; TODO
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

REDRAW_WALLS            equ 1h
REDRAW_SNAKE            equ 2h
REDRAW_HEAD_AND_TAIL    equ 4h
REDRAW_APPLES           equ 8h
REDRAW_ALL              equ REDRAW_WALLS + REDRAW_SNAKE + REDRAW_HEAD_AND_TAIL + REDRAW_APPLES

EMPTY_COLOR         equ 0h
WALL_COLOR          equ 1ch
SNAKE_COLOR         equ 0ah
APPLE_COLOR         equ 0ch

APPLES_TO_EAT       equ 10

SNAKE_MAX_LENGTH    equ 512

CELL_ROWS           equ 50
CELL_COLS           equ 80
CELLS_COUNT         equ CELL_ROWS * CELL_COLS

%macro  moveRegToCell 3 ; reg, x, y
%ifnum %3
    mov %1, %3 * 80
%else
    mov %1, %3      ; reg = y
    shl %1, 2       ; reg = y * 4
    add %1, %3      ; reg = y * 5
    shl %1, 4       ; reg = y * 5 * 16 = y * 80
%endif
%if %2 != 0
    add %1, %2
%endif
    add %1, cells
%endmacro

%macro  moveRegToPixel 3 ; reg, x, y
%ifnum %3
    mov %1, %3 * 320
%else
    mov %1, %3      ; reg = y
    shl %1, 2       ; reg = y * 4
    add %1, %3      ; reg = y * 5
    shl %1, 6       ; reg = y * 5 * 64 = y * 320
%endif
%if %2 != 0
    add di, %2
%endif
%endmacro

%macro  colorDuplicated4TimeInEAX 1 ; color as byte
%ifidn %1, al
%else
    mov al, %1
%endif
    mov ah, al
    push ax
    push ax
    pop eax
%endmacro

section .bss
mainLoopTicks       resd 1

redrawFlags         resb 1

gameState           resb 1
gameStateTicks      resd 1

currentLevel        resb 1   
applesEaten         resb 1

nextMoveDirection   resb 1      ; UP, DOWN, LEFT, RIGHT
lastMoveDirection   resb 1      ; UP, DOWN, LEFT, RIGHT

snakeBodyLength     resw 1
; snake head is first entry
; snake tail is last entry
snakeBodyPositions  resb (SNAKE_MAX_LENGTH * 2) + 1;x,y for each body segment

cells               resb CELLS_COUNT


section .text

start:
    ; vga 320x200 @ 256 colors
    mov ax, 13h
    int 10h


    ; init the global variables
    mov dword [mainLoopTicks], 0
    mov byte [redrawFlags], REDRAW_ALL
    mov byte [gameState], STATE_INTRO
    mov dword [gameStateTicks], 0
    mov byte [currentLevel], 0
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

    add dword [mainLoopTicks], 1

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
    movzx bx, byte [lastMoveDirection]

    cmp ah, 48h     ; up-arrow
    je .upArrow
    cmp ah, 4bh     ; left-arrow
    je .leftArrow
    cmp ah, 4dh     ; right-arrow
    je .rightArrow
    cmp ah, 50h     ; down-arrow
    je .downArrow
    jmp .return

    .upArrow:
    cmp bl, MOVE_DOWN       ; would this be going back ? 
    je  .return
    mov byte [nextMoveDirection], MOVE_UP
    jmp .return

    .leftArrow:
    cmp bl, MOVE_RIGHT      ; would this be going back ?
    je  .return
    mov byte [nextMoveDirection], MOVE_LEFT
    jmp .return

    .rightArrow:            
    cmp bl, MOVE_LEFT       ; would this be going back ?  
    je  .return
    mov byte [nextMoveDirection], MOVE_RIGHT
    jmp .return

    .downArrow:
    cmp bl, MOVE_UP         ; would this be going back ?
    je  .return
    mov byte [nextMoveDirection], MOVE_DOWN

    .return:
    pop bx
    ret

; al = new state
ChangeState:
    mov ah, [gameState]
    cmp ah, al
    je .return

    mov [gameState], al

    movzx bx, al
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
        ; increment score
        mov al, [applesEaten]
        inc al
        mov [applesEaten], al
        .continueLevel:
        movzx ax, [snakeBodyPositions + 0]
        movzx bx, [snakeBodyPositions + 1]
        ; clear the apple away
        moveRegToCell di, ax, bx
        mov al, EMPTY_COLOR
        stosb
        ; elongate snake
        mov ax, 10
        call LengthenSnake
        ; TODO generate new apple
        call PlaceNewApple
        jmp .endCase
    .caseCrashed:
        ; TODO show a restart or quit message
        jmp .endCase
    .caseGameOver:
        jmp .endCase
    .endCase:

    mov dword [gameStateTicks], 0
    
    .return:
    ret

; ---- Update Routines -----
; Update
;   +-- UpdateStateIntro
;   +--    ...StateNewLevel
;   |           +-- ChangeState ( STATE_IN_LEVEL )
;   +--    ...StateInLevel
;   |           +-- MoveSnake
;   |                   +-- ChangeState ( STATE_ATE_APPLE | STATE_CRASHED )
;   +--    ...StateAteApple
;   |           +-- ChangeState ( STATE_IN_LEVEL )
;   +--    ...StateCrashed
;   |           +-- ChangeState ( STATE_GAMEOVER )
;   +--    ...StateGameOver
;
;   These call other helpers:
;   
;       ChangeState
;       MoveSnake
;       SetupLevel
;

Update:
    ; prepare so we can write to the game cells with [es:di]
    mov ax, ds
    mov es, ax

    movzx bx, byte [gameState]
    shl bx, 1
    call [bx + .switchCallTable]
    jmp .return
    .switchCallTable:
        dw UpdateStateIntro
        dw UpdateStateNewLevel
        dw UpdateStateInLevel
        dw UpdateStateAteApple
        dw UpdateStateCrashed
        dw UpdateStateGameOver
    .return:
    add dword [gameStateTicks], 1
    ret

UpdateStateIntro:
    mov eax, [gameStateTicks]
    cmp eax, TICKS_PER_SECOND * 1
    jl  .return
    mov al, STATE_NEW_LEVEL
    call ChangeState
    .return:
    ret

UpdateStateNewLevel:
    mov eax, [gameStateTicks]
    cmp eax, TICKS_PER_SECOND * 1
    jl  .return
    mov al, STATE_IN_LEVEL
    call ChangeState
    .return:
    ret

UpdateStateInLevel:
    mov eax, [gameStateTicks]
    and eax, 0fffh  ; only move once (1 << 12) ticks have passed since last time
    jnz .return
    call MoveSnake
    call CheckCollisions
    call UpdateCells
    .return:
    ret

UpdateStateAteApple:
    mov al, [applesEaten]
    cmp al, APPLES_TO_EAT
    jl .continueLevel
    
    ; go to next level
    mov al, [currentLevel]
    inc al
    mov [currentLevel], al
    mov al, STATE_NEW_LEVEL
    call ChangeState
    jmp .return

    .continueLevel:
    mov al, STATE_IN_LEVEL
    call ChangeState
    .return:
    ret

UpdateStateCrashed:
    .return:
    ret

UpdateStateGameOver:
    .return:
    ret

PlaceNewApple:
    mov eax, [mainLoopTicks]
    .whilePlaceNotFound:
        ; generate a random value off the main timer
        mov ebx, eax
        add eax, 113        ; a low prime
        xor ebx, 23456789h
        add ebx, 87654321h
        ror ebx, 11
        and bx, 0fffh       ; % 4096
        cmp bx, CELLS_COUNT ; < 4000?
        jge .whilePlaceNotFound
        mov di, cells
        add di, bx
        ; what's in the cell now
        mov bl, [di]
        cmp bl, EMPTY_COLOR ; empty?
        jne .whilePlaceNotFound
    
    mov al, APPLE_COLOR
    stosb
    mov al, [redrawFlags]
    or  al, REDRAW_APPLES
    mov [redrawFlags], al

    ret

; ax = +length 
LengthenSnake:
    mov bx, [snakeBodyLength]
    
    ; copy the body down
    mov di, bx
    shl di, 1
    add di, snakeBodyPositions 
    mov si, di
    sub si, 2
    mov cx, ax
    rep movsw

    add bx, ax
    mov [snakeBodyLength], bx
    
    mov al, [redrawFlags]
    or  al, REDRAW_SNAKE
    mov [redrawFlags], al

    ret

SetupLevel:
    push ax
    push bx

    ; clear out the number of apples eaten
    mov byte [applesEaten], 0

    ; clear out the snake body
    mov bx, 10
    mov [snakeBodyLength], bx
    
    shl bx, 1
    mov ax, (160 / 4) - 10
    .loopSetupSnake:
        mov byte [bx + snakeBodyPositions], al
        mov byte [bx + snakeBodyPositions + 1], 100 / 4
        inc ax
        sub bx, 2
        jge .loopSetupSnake

    ; clear out the board
    mov bx, cells
    mov cx, CELLS_COUNT / 4
    .loopClearBoard:
        mov dword [bx], 0
        add bx, 4
        loop .loopClearBoard


    ; Start heading right
    mov byte [nextMoveDirection], MOVE_RIGHT

    call UpdateCells

    ; Setup the new level walls
    mov al, [currentLevel]
    and al, 03h     ; limit to 4 levels now

    cmp al, 0
    jne .level1
    call SetupLevel0
    jmp .return

    .level1:
    cmp al, 1
    jne .level2
    call SetupLevel1
    
    .level2:
    cmp al, 2
    jne .level3
    call SetupLevel2

    .level3:
    cmp al, 2
    jne .return
    call SetupLevel3

    .return:
    call PlaceNewApple
    mov byte [redrawFlags], REDRAW_ALL

    pop bx
    pop ax
    ret

SetupLevel0:
    mov al, WALL_COLOR
    ; top wall
    moveRegToCell di, 0, 0
    mov cx, CELL_COLS
    rep stosb

    ; left wall
    moveRegToCell di, 0, 1
    mov cx, CELL_ROWS - 2
    .left:
        stosb
        add di, CELL_COLS - 1
        loop .left
    
    ; right wall
    moveRegToCell di, CELL_COLS - 1, 1
    mov cx, CELL_ROWS - 2
    .right:
        stosb
        add di, CELL_COLS - 1
        loop .right

    ; bottom wall
    moveRegToCell di, 0, (CELL_ROWS - 1)
    mov cx, CELL_COLS
    rep stosb


    .return:
    ret

SetupLevel1:
    ; no walls
    .return:
    ret

SetupLevel2:
    mov al, WALL_COLOR
    ; 1 wall across the middle 
    moveRegToCell di, 0, 20
    mov cx, CELL_COLS
    rep stosb

    .return:
    ret

SetupLevel3:
    mov al, WALL_COLOR
    ; 1 stipple wall across the middle 
    moveRegToCell di, 0, 20
    mov cx, CELL_COLS / 2
    .loop:
        stosb
        inc di
        loop .loop

    .return:
    ret



MoveSnake:
    push bx
    push cx

    ;jmp .moveHead
    ; move all the snake segments down one step
    mov cx, [snakeBodyLength]
    mov si, cx
    shl si, 1
    sub si, 2
    add si, snakeBodyPositions 
    mov di, si
    add di, 2                   
    ; si = (word *)&snakeBodyPositions[snakeBodyLength - 1]
    ; di = (word *)&snakeBodyPositions[snakeBodyLength]
    std
    rep movsw                   ; *(di--) = (*si--)
    cld
    
    .moveHead:
    movzx ax, byte [snakeBodyPositions + 0]
    movzx bx, byte [snakeBodyPositions + 1]

    ; check the direction
    movzx cx, byte [nextMoveDirection]
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

    ; Tell Draw we need to update the tail and head pixels
    mov al, [redrawFlags]
    or al, REDRAW_HEAD_AND_TAIL
    mov [redrawFlags], al

    .return:
    pop cx
    pop bx
    ret

CheckCollisions:
    movzx ax, byte [snakeBodyPositions + 0]
    movzx bx, byte [snakeBodyPositions + 1]

    ; check what is there already
    moveRegToCell si, ax, bx
    lodsb
    cmp al, APPLE_COLOR
    je .caseApple
    cmp al, WALL_COLOR
    je .caseWall
    cmp al, SNAKE_COLOR
    je .caseSnake
    jmp .endCase

    .caseApple:
        mov al, STATE_ATE_APPLE
        call ChangeState
        jmp .endCase
    .caseWall:
        mov al, STATE_CRASHED
        call ChangeState
        jmp .endCase
    .caseSnake:
        mov al, STATE_CRASHED
        call ChangeState
        jmp .endCase
    .endCase:

    .return:
    ret

UpdateCells:
    ; clear the existing snake cells then write the snake to the cells again
    push bx
    push cx

    moveRegToCell si, 0, 0
    mov cx, CELLS_COUNT
    .clearLoop:
        lodsb
        cmp al, SNAKE_COLOR
        jne .clearLoopEnd
        mov byte [si - 1], EMPTY_COLOR
        .clearLoopEnd:
        loop .clearLoop

    mov si, snakeBodyPositions
    mov cx, [snakeBodyLength]
    .snakeLoop:
        lodsw ;x=al, y=ah
        movzx bx, ah
        xor ah, ah
        moveRegToCell di, ax, bx
        mov al, SNAKE_COLOR
        stosb
        loop .snakeLoop

    .return:
    pop cx
    pop bx
    ret

; ---- Draw Routines -----
; Draw
;   Just loop through the cells and draw them as their type

Draw:
    ; make es point to the framebuffer
    mov ax, VGA_SEGMENT
    mov es, ax

    movzx ax, byte [redrawFlags]
    cmp ax, REDRAW_ALL
    jne .drawSubset
    call DrawFullRedraw
    jmp .return

    .drawSubset:
    mov bx, ax
    and bx, REDRAW_SNAKE
    jz  .testDrawHeadAndTail
    call DrawSnake
    jmp .testDrawApples

    .testDrawHeadAndTail:
    mov bx, ax
    and bx, REDRAW_HEAD_AND_TAIL
    jz  .return
    call DrawSnakeHeadAndTail

    .testDrawApples:
    mov bx, ax
    and bx, REDRAW_APPLES
    jz  .return
    ;call DrawApples
    call DrawFullRedraw

    .return:
    mov byte [redrawFlags], 0
    ret

; Draws a 4x4 cell and advances `di` by 4
_Draw4x4CellAtDiWithColorInEAX:
    stosd
    add di, 320 - 4
    stosd
    add di, 320 - 4
    stosd
    add di, 320 - 4
    stosd
    sub di, 320 * 3
    ret

DrawFullRedraw:
    moveRegToPixel di, 0, 0
    mov si, cells
    mov cx, CELL_ROWS
    .rowLoop:
        mov dx, CELL_COLS
        .colLoop:
            lodsb ; cell color in al
            colorDuplicated4TimeInEAX al
            call _Draw4x4CellAtDiWithColorInEAX
            dec dx
            jnz .colLoop
        add di, 320 * 3
        loop .rowLoop
    .return:
    ret

DrawSnake:
    push ax
    mov si, snakeBodyPositions
    mov cx, [snakeBodyLength]
    .clearTail:
        mov bx, cx
        shl bx, 1
        mov ax, [si + bx]
        movzx bx, ah
        xor ah, ah
        shl ax, 2
        shl bx, 2
        moveRegToPixel di, ax, bx
        colorDuplicated4TimeInEAX EMPTY_COLOR
        call _Draw4x4CellAtDiWithColorInEAX

    .loop:
        lodsw
        movzx bx, ah
        xor ah, ah
        shl ax, 2
        shl bx, 2
        moveRegToPixel di, ax, bx
        colorDuplicated4TimeInEAX SNAKE_COLOR
        call _Draw4x4CellAtDiWithColorInEAX
        loop .loop

    .return:
    pop ax
    ret

DrawSnakeHeadAndTail:
    push ax
    mov si, snakeBodyPositions
    mov cx, [snakeBodyLength]
    .clearTail:
        mov bx, cx
        shl bx, 1
        mov ax, [si + bx]
        movzx bx, ah
        xor ah, ah
        shl ax, 2
        shl bx, 2
        moveRegToPixel di, ax, bx
        colorDuplicated4TimeInEAX EMPTY_COLOR
        call _Draw4x4CellAtDiWithColorInEAX

    .drawHead:
        lodsw
        movzx bx, ah
        xor ah, ah
        shl ax, 2
        shl bx, 2
        moveRegToPixel di, ax, bx
        colorDuplicated4TimeInEAX SNAKE_COLOR
        call _Draw4x4CellAtDiWithColorInEAX

    .return:
    pop ax
    ret


DrawApples:
    ret
