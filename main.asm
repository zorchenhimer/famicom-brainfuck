
.include "nes2header.inc"
nes2mapper 0
nes2prg 1 * 16 * 1024
nes2chr 1 * 8 * 1024
nes2wram 1 * 8 * 1024
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

.segment "ZEROPAGE"
Sleeping: .res 1
KeyboardRead: .res 1

PressedIdx: .res 1
HeldIdx: .res 1
KeyboardPressed: .res 8 ; keys pressed this frame
KeyboardHeld:    .res 8 ; keys being held this frame

AddressPointer1: .res 2
AddressPointer2: .res 2
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

.segment "OAM"
SpriteZero: .res 4
Sprites: .res (64*4)-4
.segment "BSS"

KeyboardStatus: .res 72

EditorRow: .res 1
EditorCol: .res 1

.segment "VECTORS"
    .word NMI
    .word RESET
    .word IRQ

.segment "CHR0"
    .incbin "font.chr"

.segment "CHR1"

.segment "PRGRAM"
Code: .res EditorLineLength*EditorLineCount
Compiled: .res EditorLineLength*EditorLineCount
.segment "CELRAM"
Cells: .res $100

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

    jsr WaitForNMI
    lda #%0000_0000
    sta $2001

    jmp (AddressPointer1)
StateReturnAddr = * - 1

    jsr WaitForNMI
    lda #%0001_1110
    sta $2001

    jmp Frame

WaitForNMI:
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

    .include "keyboard.asm"

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
    rts

ClearCells:
    ldx #0
    lda #0
:
    sta Cells, x
    dex
    bne :-
    rts

.enum State
    Input
    Help
.endenum

    .include "state-input.asm"
    .include "state-help.asm"

; Frame code for each state
EngineStates:
    .word State_Input
    .word State_Help
    ;.word State_Complie
    ;.word State_Run
    ;.word State_Debug
EngineStateCount = (* - EngineStates) / 2

EngineStateInits:
    .word Init_StateInput
    .word Init_StateHelp
    ;.word Init_StateComplie
    ;.word Init_StateRun
    ;.word Init_StateDebug
EngineStateInitCount = (* - EngineStateInits) / 2
.if EngineStateInitCount <> EngineStateCount
    .error "EngineStateInitCount and EngineStateCount mismatch"
.endif

PaletteData:
    .repeat 4
    .byte $0F, $20, $10, $2D
    .endrepeat

SpritePaletteData:
    .repeat 4
    .byte $0F, $27, $17, $07
    .endrepeat

BorderTileData:
    .include "border.i"
    .byte $00
