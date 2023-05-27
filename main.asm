
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
    ldx #32

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
    ;jsr ReadKeyboard
    jsr JustReadKeyboard
    jsr JustDecodeKeyboard

    ldx #0
@cursorLoop:
    lda KeyboardPressed, x
    beq @cursorNext

    cmp #$03 ; up
    bne :+
    lda EditorRow
    beq :+
    dec EditorRow
:

    lda KeyboardPressed, x
    cmp #$02 ; right
    bne :+
    lda EditorCol
    cmp #EditorLineLength-1
    beq :+
    inc EditorCol
:

    lda KeyboardPressed, x
    cmp #$04 ; down
    bne :+
    lda EditorRow
    cmp #EditorLineCount-1
    beq :+
    inc EditorRow
:

    lda KeyboardPressed, x
    cmp #$01 ; left
    bne :+
    lda EditorCol
    beq :+
    dec EditorCol
:

@cursorNext:
    inx
    ;cpx PressedIdx
    cpx #8
    bcc @cursorLoop

    ldx #0
    ldy #0
@keyloop:
    lda KeyboardPressed, x
    beq @done

    cmp #$20
    bcc @nextkey

    lda EditorRow
    cmp #EditorLineCount
    bne :+
    lda EditorCol
    cmp #EditorLineLength
    bne :+
    jmp @done   ; too much crap on screen
:

    inc BufferedLen
    stx TmpX

    lda EditorRow
    asl a
    tax
    lda EditorLinesStart+0, x
    clc
    adc EditorCol
    sta TmpY
    lda EditorLinesStart+1, x
    adc #0
    sta BufferedTiles, y
    iny

    lda TmpY
    sta BufferedTiles, y
    iny

    ldx TmpX

    lda KeyboardPressed, x
    sta BufferedTiles, y
    iny

    inc EditorCol
    lda EditorCol
    cmp #EditorLineLength
    bcc :+
    inc EditorRow
    lda #0
    sta EditorCol
:

@nextkey:
    inx
    cpx #8
    bne @keyloop
@done:

    ; position cursor sprite
    ldx EditorRow
    lda EditorCursorRows, x
    sta SpriteZero+0

    ldx EditorCol
    lda EditorCursorCols, x
    sta SpriteZero+3

    lda #CusrorTile
    sta SpriteZero+1

    lda #%0010_0000
    sta SpriteZero+2

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

    ldy #0
@loop:
    lda (AddressPointer1), Y
    sta $2007
    iny
    dex
    bne @loop
    rts

EditorLinesStart:
    .repeat EditorLineCount, i
    .word EditorAbsStart+(i*32)
    .endrepeat

EditorCursorRows:
    .repeat EditorLineCount, i
    .byte (8*3)+(i*8)-1
    .endrepeat
EditorCursorCols:
    .repeat EditorLineLength, i
    .byte (8*2)+(i*8)
    .endrepeat

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
