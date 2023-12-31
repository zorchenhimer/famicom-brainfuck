
.include "nes2header.inc"
nes2mapper 0
nes2prg 1 * 16 * 1024
nes2chr 1 * 8 * 1024
nes2bram 1 * 8 * 1024
nes2mirror 'V'
nes2tv 'N'
nes2end

.feature leading_dot_in_identifiers
.feature underline_in_numbers
.feature addrsize

EditorLineLength = 28
EditorLineCount = 24
EditorAbsStart = $2062

CusrorTile = $84
CenterDotTile = $86

TitleAddress = $2042
BorderStop = $A5
BorderStart = $B6
BottomTextAddr = $2362

MenuStartAddress = $2126
; This is bound to MenuStartAddress.  The menu selections
; should move in-step with changes to menu location
; changse (only vertically).
MenuCursorStart = (((MenuStartAddress-$2000) / 32)*8) - 1

.enum TilesFunc
F1 = $11
F2
F3
F4
F5
F6
F7
F8
.endenum

.enum Text
Close
Code
Compiling
Done
Help
Load
Menu
Pause
Run
Running
Step
Stop
.endenum

.segment "ZEROPAGE"
Sleeping: .res 1
KeyboardRead: .res 1

PressedIdx: .res 1
HeldIdx: .res 1
KeyboardPressed: .res 8 ; keys pressed this frame
KeyboardHeld:    .res 8 ; keys being held this frame

AddressPointer1: .res 2
AddressPointer2: .res 2
AddressPointer3: .res 2
TmpA: .res 1
TmpB: .res 1
TmpX: .res 1
TmpY: .res 1
TmpZ: .res 1

CursorAddr: .res 2
Shifted: .res 1

BufferedTiles: .res 8*3
BufferedLen: .res 1 ; sets of three bytes (addr & data)

KeyboardLastFrame: .res 9
KeyboardThisFrame: .res 9

EngineState: .res 1
PreviousState: .res 1

MenuState: .res 10 ; states of items
MenuSelect: .res 1 ; current selection

; Pointer to code for after NMI, but separate from frame
PostNMI: .res 2

; Set to non-zero to skip the fade in scene change
SkipFade: .res 1

.segment "OAM"
SpriteZero: .res 4
Sprites: .res (64*4)-4
.segment "BSS"

EditorRow: .res 1
EditorCol: .res 1

LoopStackIdx: .res 1
LoopStackLo: .res 256
LoopStackHi: .res 256

.segment "VECTORS"
    .word NMI
    .word RESET
    .word IRQ

.segment "CHR0"
    .incbin "font.chr"
    .incbin "brain.chr"
    .incbin "eggplant.chr"

.segment "CHR1"

.segment "PRGRAMBOT"
; stuff unaligned to pages
Code: .res EditorLineLength*EditorLineCount+1
Compiled: .res EditorLineLength*EditorLineCount+1

.segment "PRGRAMTOP"
; stuff aligned to pages
Cells:          .res 256    ; runtime memory

.segment "PAGE0"
IRQ:
    rti

NMI:
    pha
    txa
    pha
    tya
    pha

    lda #$FF
    sta Sleeping

    lda #$00
    sta $2003
    lda #$02
    sta $4014

    ; NMI stuff here
    ldx BufferedLen
    beq @bufferDone
    ldy #0

@bufferLoop:
    lda BufferedTiles, y
    sta $2006
    iny
    lda BufferedTiles, y
    sta $2006
    iny
    lda BufferedTiles, y
    sta $2007
    iny
    dex
    bne @bufferLoop

@bufferDone:

    lda #0
    sta $2005
    sta $2005
    sta BufferedLen

    lda #%1000_0000
    sta $2000

    lda PostNMI+0
    ora PostNMI+1
    beq @nmiDone

    lda #.hibyte(@nmiDone-1)
    pha
    lda #.lobyte(@nmiDone-1)
    pha

    jmp (PostNMI)

@nmiDone:
    pla
    tay
    pla
    tax
    pla
    rti

RESET:
    sei         ; Disable IRQs
    cld         ; Disable decimal mode

    ldx #$40
    stx $4017   ; Disable APU frame IRQ

    ldx #$FF
    txs         ; Setup new stack

    inx         ; Now X = 0

    stx $2000   ; disable NMI
    stx $2001   ; disable rendering
    stx $4010   ; disable DMC IRQs

:   ; First wait for VBlank to make sure PPU is ready.
    bit $2002   ; test this bit with ACC
    bpl :- ; Branch on result plus

:   ; Clear RAM
    lda #$00
    sta $0000, x
    sta $0100, x
    sta $0200, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x

    inx
    bne :-  ; loop if != 0

:   ; Second wait for vblank.  PPU is ready after this
    bit $2002
    bpl :-

    lda #$FF
    sta SkipFade
    lda #$00
    jsr ClearAttrTable

    lda #$3F
    sta $2006
    lda #$00
    sta $2006

    ldx #0
:
    lda BGPaletteData, x
    sta $2007
    inx
    cpx #16
    bne :-

    lda #$3F
    sta $2006
    lda #$10
    sta $2006

    ldx #0
:
    lda SPPaletteData, x
    sta $2007
    inx
    cpx #4
    bne :-

    ;lda #.lobyte(PaletteData)
    ;sta AddressPointer1+0
    ;lda #.hibyte(PaletteData)
    ;sta AddressPointer1+1
    ;ldx #32
    ;jsr WritePaletteData

    ; Clear sprites
    ldx #0
    lda #$FF
:
    sta $200, x
    inx
    bne :-

    lda #$00
    sta $2003
    lda #$02
    sta $4014

    jsr ClearCodeRam
    jsr ClearCells

    lda #%1000_0000
    sta $2000

    lda #0
    jmp ChangeState

Frame:
    lda EngineState
    cmp #EngineStateCount
    beq :+
    bcc :+
    lda #0 ; default to input state
:
    asl a
    tax
    lda EngineStates+0, x
    sta AddressPointer1+0
    lda EngineStates+1, x
    sta AddressPointer1+1

    lda #.hibyte(FrameReturnAddr)
    pha
    lda #.lobyte(FrameReturnAddr)
    pha

    jmp (AddressPointer1)
FrameReturnAddr = * - 1

    jsr WaitForNMI
    jmp Frame

; Target state in A
; SkipFade is used here
ChangeState:
    cmp #EngineStateCount
    bcc :+
    ;
    ; invalid state
    ;
    brk
:

    ; reset the stack
    ldx #$FF
    txs

    ldx EngineState
    stx PreviousState

    sta EngineState
    asl a
    tax
    lda EngineStateInits+0, x
    sta AddressPointer1+0
    lda EngineStateInits+1, x
    sta AddressPointer1+1

    lda #.hibyte(StateReturnAddr)
    pha
    lda #.lobyte(StateReturnAddr)
    pha

    lda #0
    sta PostNMI+0
    sta PostNMI+1

    lda SkipFade
    bne :+

    jsr WaitForNMI
    ldx #1
    jsr FadePalette

    jsr WaitForNMI
    ldx #2
    jsr FadePalette

    jsr WaitForNMI
    ldx #3
    jsr FadePalette
: ; fade skip

    lda #%0000_0000
    sta $2001

    ; Clear nametable
    lda #$23
    sta $2006
    lda #$C0
    sta $2006

    lda #$00
    ldx #16
:
    sta $2007
    sta $2007
    sta $2007
    sta $2007
    dex
    bne :-

    jmp (AddressPointer1)
StateReturnAddr = * - 1

    jsr WaitForNMI
    lda #%0001_1110
    sta $2001

    lda SkipFade
    bne :+

    jsr WaitForNMI
    ldx #2
    jsr FadePalette

    jsr WaitForNMI
    ldx #1
    jsr FadePalette

    jsr WaitForNMI
    ldx #0
    jsr FadePalette

: ; fade skip

    lda #%1000_0000
    sta $2000

    lda #0
    sta SkipFade

    jmp Frame

WaitForNMI:
    lda #0
    sta Sleeping

:   bit Sleeping
    bpl :-
    lda #0
    sta Sleeping
    rts

; Data start in AddressPointer1
; PPU address in AddressPointer2
; data is null terminated
DrawTiledData:
    lda AddressPointer2+1
    sta $2006
    lda AddressPointer2+0
    sta $2006

    ldy #0
@loop:
    lda (AddressPointer1), y
    beq @done
    tax

    iny
    bne :+
    inc AddressPointer1+1
:
    lda (AddressPointer1), y
    iny
    bne :+
    inc AddressPointer1+1
:

@writeLoop:
    sta $2007
    dex
    bne @writeLoop
    jmp @loop

@done:
    rts

; Data is at AddressPointer1
; Length in X
WritePaletteData:
    lda #$3F
    sta $2006
    lda #$00
    sta $2006

    ldy #0
@loop:
    lda (AddressPointer1), Y
    sta $2007
    iny
    dex
    bne @loop
    rts

ClearCodeRam:
    ldx #0
@row:
    txa
    asl a
    tay
    lda EditorLinesRam+0, y
    sta AddressPointer1+0
    lda EditorLinesRam+1, y
    sta AddressPointer1+1

    ldy #0
    lda #' '
@col:
    sta (AddressPointer1), y
    iny
    cpy #EditorLineLength
    bcc @col

    inx
    cpx #EditorLineCount
    bcc @row

    lda #0
    sta (AddressPointer1), y

    rts

; Clears a full page (256 bytes)
; Start address in AddressPointer1
ClearPage:
    lda #0
    ldy #0
:
    sta (AddressPointer1), y
    iny
    bne :-

    rts

ClearCells:
    ldx #0
    lda #0
:
    sta Cells, x
    dex
    bne :-
    rts

; Text index in A
WriteTitle:
    asl a
    tax
    lda BorderText+0, x
    sta AddressPointer1+0
    lda BorderText+1, x
    sta AddressPointer1+1

    lda #.hibyte(TitleAddress)
    sta $2006
    lda #.lobyte(TitleAddress)
    sta $2006

    lda #BorderStop
    sta $2007
    ldy #0

:
    lda (AddressPointer1), y
    beq :+
    iny
    sta $2007
    jmp :-

:
    lda #BorderStart
    sta $2007

    lda #$BD
    .repeat 7
    sta $2007
    .endrepeat

    rts

; Text index in A
; Column in X
; Func key in Y
WriteBottom:
    stx TmpX

    asl a
    tax
    lda BorderText+0, x
    sta AddressPointer1+0
    lda BorderText+1, x
    sta AddressPointer1+1

    clc
    lda #.lobyte(BottomTextAddr)
    adc TmpX
    tax
    lda #.hibyte(BottomTextAddr)
    adc #0
    sta $2006
    stx $2006

    lda #BorderStop
    sta $2007

    sty $2007
    lda #CenterDotTile
    sta $2007

    ldy #0
:
    lda (AddressPointer1), y
    beq :+
    iny
    sta $2007
    jmp :-

:
    lda #BorderStart
    sta $2007

    rts

; A holds fill value
ClearAttrTable:
    ldy #$23
    sty $2006
    ldy #$C0
    sty $2006

    ldx #32

:
    sta $2007
    sta $2007
    dex
    bne :-

    rts

; step in X
FadePalette:
    lda #$3F
    sta $2006
    lda #$01
    sta $2006
    lda BGPaletteFade, x
    sta $2007

    lda #$3F
    sta $2006
    lda #$11
    sta $2006
    lda SPPaletteFade, x
    sta $2007

    lda #0
    sta $2005
    sta $2005
    lda #%1000_0000
    sta $2000

    rts

DrawLogo:
    lda #.hibyte(LogoBrainAddr)
    sta $2006
    lda #.lobyte(LogoBrainAddr)
    sta $2006
    .repeat 3, i
    lda #$D0 + i
    sta $2007
    .endrepeat

    lda #.hibyte(LogoBrainAddr+32)
    sta $2006
    lda #.lobyte(LogoBrainAddr+32)
    sta $2006
    .repeat 4, i
    lda #$D3 + i
    sta $2007
    .endrepeat

    lda #.hibyte(LogoBrainAddr+(32*2))
    sta $2006
    lda #.lobyte(LogoBrainAddr+(32*2))
    sta $2006
    .repeat 4, i
    lda #$D7 + i
    sta $2007
    .endrepeat

    lda #.hibyte(LogoEggplantAddr)
    sta $2006
    lda #.lobyte(LogoEggplantAddr)
    sta $2006
    .repeat 2, i
    lda #$DB + i
    sta $2007
    .endrepeat

    lda #.hibyte(LogoEggplantAddr+32)
    sta $2006
    lda #.lobyte(LogoEggplantAddr+32)
    sta $2006
    .repeat 3, i
    lda #$DD + i
    sta $2007
    .endrepeat

    lda #.hibyte(LogoEggplantAddr+(32*2))
    sta $2006
    lda #.lobyte(LogoEggplantAddr+(32*2))
    sta $2006
    .repeat 4, i
    lda #$E0 + i
    sta $2007
    .endrepeat

    lda #.hibyte(LogoEggplantAddr+(32*3)+1)
    sta $2006
    lda #.lobyte(LogoEggplantAddr+(32*3)+1)
    sta $2006
    .repeat 2, i
    lda #$E4 + i
    sta $2007
    .endrepeat

    lda #$23
    sta $2006
    lda #$CB
    sta $2006
    lda #$55
    sta $2007

    lda #$AA
    sta $2007
    rts

.enum State
    Menu
    Input
    Help
    Load
    Clear
    Run
    Done
    Compile
.endenum

    .include "keyboard.asm"
    .include "state-input.asm"
    .include "state-help.asm"
    .include "state-menu.asm"
    .include "state-clear.asm"
    .include "state-load.asm"
    .include "state-run.asm"
    .include "state-done.asm"
    .include "state-compile.asm"

; Frame code for each state
EngineStates:
    .word State_Menu
    .word State_Input
    .word State_Help
    .word State_Load
    .word State_Clear
    .word State_Run
    .word State_Done
    .word State_Compile
    ;.word State_Run
    ;.word State_Debug
EngineStateCount = (* - EngineStates) / 2

EngineStateInits:
    .word Init_Menu
    .word Init_StateInput
    .word Init_StateHelp
    .word Init_Load
    .word Init_Clear
    .word Init_Run
    .word Init_Done
    .word Init_Compile
    ;.word Init_StateRun
    ;.word Init_StateDebug
EngineStateInitCount = (* - EngineStateInits) / 2
.if EngineStateInitCount <> EngineStateCount
    .error "EngineStateInitCount and EngineStateCount mismatch"
.endif

BGPaletteData:
    .byte $0F, $20, $10, $2D
    .byte $0F, $16, $15, $26
    .byte $0F, $23, $13, $2A
BGPaletteFade:
    .byte $20, $10, $2D, $0F

SPPaletteData:
    .byte $0F, $27, $17, $07
SPPaletteFade:
    .byte $27, $17, $07, $0F

BorderTileData:
    .include "border.i"
    .byte $00

BorderText:
    .word :+
    .word :++
    .word :+++
    .word :++++
    .word :+++++
    .word :++++++
    .word :+++++++
    .word :++++++++
    .word :+++++++++
    .word :++++++++++
    .word :+++++++++++
    .word :++++++++++++

:   .asciiz "Close"
:   .asciiz "Code"
:   .asciiz "Compiling"
:   .asciiz "Done"
:   .asciiz "Help"
:   .asciiz "Load Example"
:   .asciiz "Menu"
:   .asciiz "Pause"
:   .asciiz "Run"
:   .asciiz "Running"
:   .asciiz "Step"
:   .asciiz "Stop"
