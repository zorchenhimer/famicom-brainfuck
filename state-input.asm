Init_StateInput:
    lda #.lobyte(PaletteData)
    sta AddressPointer1+0
    lda #.hibyte(PaletteData)
    sta AddressPointer1+1
    ldx #32

    jsr WritePaletteData

    lda #.lobyte(BorderTileData)
    sta AddressPointer1+0
    lda #.hibyte(BorderTileData)
    sta AddressPointer1+1

    lda #$20
    sta AddressPointer2+1
    lda #$00
    sta AddressPointer2+0

    jsr DrawTiledData

    rts

State_Input:
    jsr JustReadKeyboard
    jsr JustDecodeKeyboard

    lda KeyboardThisFrame+7
    and #%0001_0000
    beq :+
:

    ; Handle actions (movement, etc) before characters.
    ldx #0
@actionLoop:
    lda KeyboardPressed, x
    beq @actionNext
    cmp #$20
    bcs @actionNext

    asl a
    tax
    lda KeyFunctions+0, x
    ora KeyFunctions+1, x
    beq @actionNext

    lda #.hibyte(@actionNext-1)
    pha
    lda #.lobyte(@actionNext-1)
    pha

    lda KeyFunctions+0, x
    sta AddressPointer1+0
    lda KeyFunctions+1, x
    sta AddressPointer1+1
    jmp (AddressPointer1)

@actionNext:
    inx
    ;cpx PressedIdx
    cpx #8
    bcc @actionLoop

    ldx #0
    ;ldy #0
@keyloop:
    lda KeyboardPressed, x
    beq @done

    cmp #$20
    bcc @nextkey

    stx TmpX

    ; Get PPU address of cursor

    ldx BufferedLen
    ldy Mult3, x
    inc BufferedLen

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

    ; When we hit the end, don't move the cursor
    ; but allow input.  This input will
    ; overwrite the last character.
    inc EditorCol
    lda EditorCol
    cmp #EditorLineLength
    bcc :+
    lda #0
    sta EditorCol

    inc EditorRow
    lda EditorRow
    cmp #EditorLineCount
    bcc :+

    dec EditorRow
    lda #EditorLineLength-1
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

    ; Put it behind the text
    lda #%0010_0000
    sta SpriteZero+2
    rts

KeyDelete:
    ldy EditorCol
    bne :+
    rts
:
    dey
    sty EditorCol
    lda EditorRow
    asl a

    ldx BufferedLen
    ldy Mult3, x
    inc BufferedLen

    tax
    clc
    lda EditorLinesStart+0, x
    adc EditorCol
    sta TmpY
    lda EditorLinesStart+1, x
    adc #0
    sta BufferedTiles, y
    iny
    lda TmpY
    sta BufferedTiles, y
    iny
    lda #' '
    sta BufferedTiles, y
    rts

KeyLeft:
    lda EditorCol
    beq :+
    dec EditorCol
:   rts

KeyRight:
    lda EditorCol
    cmp #EditorLineLength-1
    beq :+
    inc EditorCol
:   rts

KeyUp:
    lda EditorRow
    beq :+
    dec EditorRow
:   rts

KeyDown:
    lda EditorRow
    cmp #EditorLineCount-1
    beq :+
    inc EditorRow
:   rts

KeyReturn:
    lda EditorRow
    cmp #EditorLineCount-1
    beq :+
    inc EditorRow
    lda #0
    sta EditorCol
:   rts

KeyHelp:
    lda #1
    jmp ChangeState

KeyFunctions:
    .word $0000 ; null
    .word KeyLeft
    .word KeyRight
    .word KeyUp
    .word KeyDown
    .word $0000   ; $05
    .word $0000
    .word $0000
    .word KeyDelete
    .word $0000
    .word KeyReturn ; $0A
    .word KeyHelp

    ; $0C-$19
    .repeat 8
    .word $0000
    .endrepeat

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

Mult3:
    .repeat 8, i
    .byte 3*i
    .endrepeat
