
.include "nes2header.inc"
nes2mapper 0
nes2prg 1 * 16 * 1024
nes2chr 1 * 8 * 1024
;nes2wram 1 * 8 * 1024
nes2mirror 'V'
nes2tv 'N'
nes2end

.feature leading_dot_in_identifiers
.feature underline_in_numbers
.feature addrsize

EditorLineLength = 28
EditorLineCount = 24
EditorAbsStart = $2062

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
Code: .res $1F00
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

    ;clc
    ;lda CursorAddr+0
    ;adc BufferedLen
    ;sta CursorAddr+0
    ;lda CursorAddr+1
    ;adc #0
    ;sta CursorAddr+1

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

    lda #.lobyte(BorderTileData)
    sta AddressPointer1+0
    lda #.hibyte(BorderTileData)
    sta AddressPointer1+1

    lda #$20
    sta AddressPointer2+1
    lda #$00
    sta AddressPointer2+0

    jsr DrawTiledData

    lda #.lobyte(PaletteData)
    sta AddressPointer1+0
    lda #.hibyte(PaletteData)
    sta AddressPointer1+1
    ldx #16

    jsr WritePaletteData

    lda #%0001_1110
    sta $2001
    lda #%1000_0000
    sta $2000

    jsr WaitForNMI

    lda #0
    ldx #0
:
    sta KeyboardStatus, x
    inx
    cpx #72
    bne :-

    lda #.lobyte(EditorAbsStart)
    sta CursorAddr+0
    lda #.hibyte(EditorAbsStart)
    sta CursorAddr+1

Frame:
    jsr ReadKeyboard
    ;jsr JustReadKeyboard
    ;jsr JustDecodeKeyboard

    ldx #0
    ldy #0
@keyloop:
    lda KeyboardPressed, x
    beq @done

    cmp #$20
    bcc @nextkey

    inc BufferedLen

    lda CursorAddr+1
    sta BufferedTiles, y
    iny
    lda CursorAddr+0
    sta BufferedTiles, y
    iny
    lda KeyboardPressed, x
    sta BufferedTiles, y
    iny

    clc
    lda CursorAddr+0
    adc #1
    sta CursorAddr+0
    lda CursorAddr+1
    adc #0
    sta CursorAddr+1

;    inc EditorCol
;    lda EditorCol
;    cmp #EditorLineLength
;    bcc :+
;    ; wrap around
;    inc EditorRow
;    lda EditorRow
;    asl a
;    tax
;
;    lda EditorLinesStart+0, x
;    sta BufferedTiles, y
;    iny
;    lda EditorLinesStart+1, x
;    sta BufferedTiles, y
;    jmp :++
;:
;    lda CursorAddr+0
;    sta BufferedTiles, y
;    iny
;    lda CursorAddr+1
;    sta BufferedTiles, y
;:
;    sta BufferedTiles, y
;    iny
;    inx

@nextkey:
    inx
    cpx #8
    bne @keyloop
@done:

    jsr WaitForNMI
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

@loop:
    lda (AddressPointer1), Y
    sta $2007
    iny
    dex
    bne @loop
    rts

EditorLinesStart:
    .repeat 24, i
    .word EditorAbsStart+(i*32)
    .endrepeat

EditorCursorRows:
    .repeat EditorLineLength, i
    .byte 16+(i*8)
    .endrepeat
EditorCursorCols:
    .repeat EditorLineCount, i
    .byte 24+(i*8)
    .endrepeat



;EditorLinesEnd:
;    .repeat 24, i
;    .word EditorAbsStart+28+(i*32)
;    .endrepeat

PaletteData:
    .repeat 8
    .byte $0F, $20, $10, $2D
    .endrepeat

BorderTileData:
    .include "border.i"
    .byte $00
