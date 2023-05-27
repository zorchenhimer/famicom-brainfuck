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

    cmp #$11 ; help
    bne :+
    lda #1
    jmp ChangeState
:

    cmp #$0A ; return
    bne :+
    lda EditorRow
    cmp #EditorLineCount-1
    beq :+
    inc EditorRow
    lda #0
    sta EditorCol
:
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

@actionNext:
    inx
    ;cpx PressedIdx
    cpx #8
    bcc @actionLoop

    ldx #0
    ldy #0
@keyloop:
    lda KeyboardPressed, x
    beq @done

    cmp #$20
    bcc @nextkey

    inc BufferedLen
    stx TmpX

    ; Get PPU address of cursor
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
