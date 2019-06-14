.386
.model flat, stdcall, c
;.stack 4096 
option casemap: none

include include\windows.inc

include include\msvcrt.inc
include include\kernel32.inc
include include\user32.inc
include include\gdi32.inc

includelib lib\msvcrt.lib
includelib lib\kernel32.lib
includelib lib\user32.lib
includelib lib\gdi32.lib

WinMain proto :DWORD,:DWORD,:DWORD,:DWORD

.data
strClass  db "SimpleWinClass",0
strTitle  db "Minesweep32",0
strNew    db "[N]ew",0
strReset  db "[R]eset",0
strFlag   db "[F]lag",0
strIdk    db "123456789*F",0
nMines    DWORD 10

.data?
hInstance      HINSTANCE ?
lpCommandLine  LPSTR ? 
hpenRed        HPEN ?

rectDraw     RECT <>
ptSelection  POINT <>
tiles        BYTE 100 dup (0)
hbrWhite     HBRUSH ?
bHasWon      BOOLEAN ?
bIsGameOver  BOOLEAN ?
nSeed        DWORD ?

.const
DARK_BLUE     equ 800000h
RED           equ 000000FFh
WHITE         equ 00FFFFFFh
TSIZE         equ 16 * 4
TILES_WIDTH   equ 9
TILES_HEIGHT  equ 9
; a tile is a DWORD, the first 3 bits are flags, and the high word is adjacent mines
BIT_FLIPPED   equ 0
BIT_MINE      equ 1
BIT_FLAGGED   equ 2

MASK_FLIPPED        equ 1
MASK_MINE           equ 2
MASK_FLAGGED        equ 4
MASK_ADJACENTMINES  equ F0h

.code
start:

; weird offsets because pen is an even width
invoke SetRect, ADDR rectDraw, 4, 4, TSIZE, TSIZE
invoke CreatePen, PS_SOLID, 4, RED
mov hpenRed, eax
invoke CreateSolidBrush, WHITE
mov hbrWhite, eax
invoke GetModuleHandle, NULL 
mov hInstance, eax 
invoke WinMain, hInstance, NULL, NULL, SW_SHOWDEFAULT
invoke ExitProcess, eax

GenerateTiles proc
    local x, y:DWORD
    local index:DWORD
    local nPlaced:DWORD
    mov nPlaced, 0

    .repeat
        invoke crt_rand
        mov ecx, TILES_WIDTH
        xor edx, edx
        div ecx
        mov x, edx ; esi == x

        invoke crt_rand
        mov ecx, TILES_HEIGHT
        xor edx, edx
        div ecx
        mov y, edx ; eax == y

        ;pop edx
        ; eax = y * width + x
        mov eax, y
        mov ecx, TILES_WIDTH 
        mul ecx 
        add eax, x

        mov ecx, eax ; ecx = index

        mov eax, [OFFSET tiles + ecx] ; ecx = tile
        ;mov eax, 255
        ;and ecx, eax
        bt eax, BIT_MINE
        jc setMine 
            or BYTE PTR [OFFSET tiles + ecx], MASK_MINE ; _tiles[y][x].IsMine = true;
            inc nPlaced ; placed++
        setMine:
        mov eax, nPlaced
    .until (eax == nMines)

    mov edi, 0 ; x
    mov esi, 0 ; y
    .while (esi < 9)
        .while (edi < 9)
            ;mov eax, 0

            inc edi
        .endw
        mov edi, 0
        inc esi
    .endw
    ret
GenerateTiles endp

Reset proc keepSeed:BOOL
    mov nMines, 10
    mov bHasWon, FALSE
    mov bIsGameOver, FALSE
    .if (keepSeed == FALSE)
        invoke crt_time, 0
        mov nSeed, eax
        
        ;sAppName = "Minesweep - Seed: " + std::to_string(_seed);
    .endif
    invoke crt_srand, nSeed
    invoke GenerateTiles
    ret
Reset endp

WinMain proc hInst:HINSTANCE, hPrevInst:HINSTANCE, lpCmdLine:LPSTR, nCmdShow:DWORD 
    local wc:WNDCLASSEX      ; create local variables on stack 
    local msg:MSG 
    local hWnd:HWND

    mov   wc.cbSize, SIZEOF WNDCLASSEX
    mov   wc.style, CS_HREDRAW or CS_VREDRAW 
    mov   wc.lpfnWndProc, OFFSET WndProc 
    mov   wc.cbClsExtra, NULL 
    mov   wc.cbWndExtra, NULL 
    push  hInst
    pop   wc.hInstance 
    invoke CreateSolidBrush, DARK_BLUE ; do i free this?
    mov   wc.hbrBackground, eax
    mov   wc.lpszMenuName, NULL 
    mov   wc.lpszClassName, OFFSET strClass 
    invoke LoadIcon, NULL, IDI_APPLICATION 
    mov   wc.hIcon, eax 
    mov   wc.hIconSm, eax 
    invoke LoadCursor, NULL, IDC_ARROW 
    mov   wc.hCursor, eax 
    invoke RegisterClassEx, ADDR wc ; register our window class 
    invoke CreateWindowEx, \
        NULL, ADDR strClass, ADDR strTitle, WS_OVERLAPPEDWINDOW, \
        CW_USEDEFAULT, CW_USEDEFAULT, 960+16, 720+39, NULL, \
        NULL, hInst, NULL 
    mov   hWnd, eax 
    invoke ShowWindow, hWnd, nCmdShow
    invoke UpdateWindow, hWnd

    invoke Reset, FALSE

    .while (TRUE)
        invoke GetMessage, ADDR msg, NULL, 0, 0 
        .break .if (!eax) 
        invoke TranslateMessage, ADDR msg
        invoke DispatchMessage, ADDR msg 
    .endw 
    mov     eax, msg.wParam         ; return exit code in eax 
    ret 
WinMain endp

FlipTile proc
    mov eax, 9
    mul ptSelection.y
    add eax, ptSelection.x
    or BYTE PTR [OFFSET tiles + eax], MASK_FLIPPED
    ret
FlipTile endp

FlagTile proc
    mov ecx, 9
    mul ptSelection.y
    add ecx, ptSelection.x

    mov eax, [OFFSET tiles + ecx]
    bt eax, BIT_FLAGGED
    jc alreadyFlipped

    or BYTE PTR [OFFSET tiles + ecx], MASK_FLAGGED
alreadyFlipped:
    ret
FlagTile endp

HandleInput proc wParam:WPARAM
    .if (wParam == VK_UP)
        .if (ptSelection.y == 0)
            mov ptSelection.y, 8
        .else
            dec ptSelection.y
        .endif
    .endif
    .if (wParam == VK_DOWN)
        .if (ptSelection.y == 8)
            mov ptSelection.y, 0
        .else
            inc ptSelection.y
        .endif
    .endif
    .if (wParam == VK_LEFT)
        .if (ptSelection.x == 0)
            mov ptSelection.x, 8
        .else
            dec ptSelection.x
        .endif
    .endif
    .if (wParam == VK_RIGHT)
        .if (ptSelection.x == 8)
            mov ptSelection.x, 0
        .else
            inc ptSelection.x
        .endif
    .endif
    .if (wParam == VK_SPACE)
        call FlipTile 
    .endif
    .if (wParam == VK_F)
        call FlagTile 
    .endif
    .if (wParam == VK_R)
        invoke Reset, TRUE 
    .endif
    .if (wParam == VK_N)
        invoke Reset, FALSE
    .endif
    ret
HandleInput endp

DrawSelector proc hdc:HDC
    local x1, y1, x2, y2:DWORD

    invoke GetStockObject, NULL_BRUSH
    invoke SelectObject, hdc, eax
    invoke SelectObject, hdc, hpenRed
        
    mov eax, TSIZE
    mul ptSelection.y
    add eax, 2 ; offset
    mov y1, eax

    mov ecx, TSIZE
    add ecx, eax
    add ecx, 1 ; offset
    mov y2, ecx

    mov eax, TSIZE
    mul ptSelection.x
    add eax, 2 ; offset
    mov x1, eax

    mov ecx, TSIZE
    add ecx, eax
    add ecx, 1 ; offset
    mov x2, ecx

    invoke Rectangle, hdc, x1, y1, x2, y2
    ret
DrawSelector endp

DrawTiles proc hdc:HDC
    local lef:DWORD
    local top:DWORD
    local rig:DWORD
    local bot:DWORD

    mov edi, 0 ; x
    mov esi, 0 ; y
    .while (esi < 9)
        .while (edi < 9)
            mov eax, TSIZE
            mul esi
            add eax, 4
            mov top, eax
                
            sub eax, 4
            mov bot, eax
            add bot, TSIZE

            mov eax, TSIZE
            mul edi
            add eax, 4
            mov lef, eax

            sub eax, 4
            mov rig, eax
            add rig, TSIZE

            ; put index in eax
            mov eax, 9
            mul esi
            add eax, edi

            mov ecx, eax

            mov eax, [OFFSET tiles + ecx]
            bt  eax, BIT_FLIPPED
            jnc drawFlipped
            ;invoke TextOut, hdc, x, y, ADDR str, SIZEOF str-1
            jp endOfDraw
        drawFlipped:
            push ecx
            invoke SetRect, ADDR rectDraw, lef, top, rig, bot
            invoke FillRect, hdc, ADDR rectDraw, hbrWhite
            pop ecx
            mov eax, [OFFSET tiles + ecx]
            bt  eax, BIT_FLAGGED
            jnc drawFlagged
            ;invoke TextOut, hdc, lef, top, ADDR strIdk+10, 1
            invoke SetTextColor, hdc, DARK_BLUE
            invoke SetBkColor, hdc, WHITE
            invoke TextOut, hdc, lef, top, ADDR strIdk+10, 1
        drawFlagged:
        endOfDraw:
            inc edi
        .endw
        mov edi, 0
        inc esi
    .endw
    ret
DrawTiles endp

WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM 
    local hdc:HDC
    local ps:PAINTSTRUCT

    local tilePos:DWORD
   

    local rect:RECT

    invoke SetRect, ADDR rect, 4, 4, 100, 100

    .if (uMsg == WM_KEYDOWN)
        invoke HandleInput, wParam
        invoke InvalidateRect, hWnd, NULL, TRUE
    .elseif (uMsg == WM_PAINT)
        invoke BeginPaint, hWnd, ADDR ps
	    mov hdc, eax
        
        invoke DrawTiles, hdc
        ; draw unfilled rectangle with red border :D
        invoke DrawSelector, hdc
        ;invoke Rectangle, hdc, rectSelection.top, rectSelection.left, rectSelection.right, rectSelection.bottom

        invoke SetTextColor, hdc, WHITE
        invoke SetBkColor, hdc, DARK_BLUE
	    invoke TextOut, hdc, 190, 0, ADDR strNew, SIZEOF strNew-1
	    invoke TextOut, hdc, 190, 20, ADDR strReset, SIZEOF strReset-1
	    invoke TextOut, hdc, 190, 40, ADDR strFlag, SIZEOF strFlag-1
	
	    invoke EndPaint, hWnd, ADDR ps
    .elseif (uMsg == WM_DESTROY)
        invoke DeleteObject, hbrWhite
        invoke DeleteObject, hpenRed
        invoke PostQuitMessage, NULL
    .else 
        invoke DefWindowProc, hWnd, uMsg, wParam, lParam
        ret 
    .endif 
    xor eax, eax 
    ret 
WndProc endp
end start