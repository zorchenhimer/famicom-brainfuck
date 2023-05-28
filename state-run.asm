Init_Run:
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

    lda #Text::Stop
    ldx #0
    ldy #$11
    jsr WriteBottom

    ; Clean the code and copy it to 'Compiled'
    lda #.lobyte(Code)
    sta AddressPointer1+0
    lda #.hibyte(Code)
    sta AddressPointer1+1

    lda #.lobyte(Compiled)
    sta AddressPointer2+0
    lda #.hibyte(Compiled)
    sta AddressPointer2+1

    ldy #0
@loop:
    lda (AddressPointer1), y
    beq @done

    cmp #'+'
    beq @doCopy

    cmp #'-'
    beq @doCopy

    cmp #'<'
    beq @doCopy

    cmp #'>'
    beq @doCopy

    cmp #'['
    beq @doCopy

    cmp #']'
    beq @doCopy

    cmp #'.'
    beq @doCopy

    cmp #','
    beq @doCopy

    jmp @next

@doCopy:
    sta (AddressPointer2), y
    inc AddressPointer2+0
    bne @next
    inc AddressPointer2+1

@next:
    inc AddressPointer1+0
    bne :+
    inc AddressPointer1+1
:
    jmp @loop
@done:
    lda #0
    sta (AddressPointer2), y

    lda #.lobyte(PostNMI_Run)
    sta PostNMI+0
    lda #.hibyte(PostNMI_Run)
    sta PostNMI+1

    lda #0
    sta EditorRow
    sta EditorCol

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

State_Run:
    rts

PostNMI_Run:
    jsr JustReadKeyboard

    ; check for F1 press
    lda KeyboardThisFrame+7
    and #%0001_0000
    beq :+

    ; clear status register
    lda #0
    pha
    plp

    lda #State::Input
    jmp ChangeState
:
    rts
