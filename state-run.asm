Init_Run:
    lda #.lobyte(BorderTileData)
    sta AddressPointer1+0
    lda #.hibyte(BorderTileData)
    sta AddressPointer1+1

    lda #$20
    sta AddressPointer2+1
    lda #$00
    sta AddressPointer2+0

    jsr DrawTiledData

    lda #Text::Running
    jsr WriteTitle

    lda #Text::Stop
    ldx #0
    ldy #$11
    jsr WriteBottom

    jsr ClearCells

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

    ;lda #CusrorTile
    lda #0
    sta SpriteZero+1

    ; Put it behind the text
    lda #%0010_0000
    sta SpriteZero+2

    rts

State_Run:

    lda #.lobyte(Compiled)
    sta AddressPointer2+0
    lda #.hibyte(Compiled)
    sta AddressPointer2+1

    ldy #0
    ldx #0 ; cell index
@loop:
    lda (AddressPointer2), y
    beq RunDone

    cmp #'+'
    bne :+
    inc Cells, x
    jmp @next

:   cmp #'-'
    bne :+
    dec Cells, x
    jmp @next

:   cmp #'<'
    bne :+
    dex
    jmp @next

:   cmp #'>'
    bne :+
    inx
    jmp @next

:   cmp #'['
    bne :+
    jsr LoopStart
    jmp @next

:   cmp #']'
    bne :+
    jsr LoopEnd
    jmp @next

:   cmp #'.'
    bne :+
    jsr PrintChar
    jmp @next

:   cmp #','
    bne @next
    jsr GetChar
    jmp @next

@next:
    inc AddressPointer2+0
    bne :+
    inc AddressPointer2+1
:
    jmp @loop
    brk ; what?

RunDone:
    lda #State::Done
    jmp ChangeState

LoopStart:
    lda Cells, x
    beq @find
    rts

@find:   ; find closing bracket

    lda #1
    sta TmpX ; nesting
@loop:
    inc AddressPointer2+0
    bne :+
    inc AddressPointer2+1
:
    lda (AddressPointer2), y
    bne :+
    ;
    ; TODO: display error.  close bracket not found.
    ;
    brk
:

    cmp #']'
    bne :+
    dec TmpX
    bne :+
    rts

:   cmp #'['
    bne :+
    inc TmpX

:   jmp @loop
    rts

LoopEnd:
    lda Cells, x
    bne :+
    rts
:
    lda #1
    sta TmpX ; nesting
@loop:
    sec
    lda AddressPointer2+0
    sbc #1
    sta AddressPointer2+0
    lda AddressPointer2+1
    sbc #0
    sta AddressPointer2+1

    lda (AddressPointer2), y
    bne :+
    ;
    ; TODO: display error.  open bracket not found.
    ;
    brk
:
    cmp #']'
    bne :+
    inc TmpX

:   cmp #'['
    bne :+
    dec TmpX
    bne :+
    rts

:   jmp @loop

    lda #1
    rts

GetChar:
    txa
    pha

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
@loop:
    jsr JustDecodeKeyboard

    lda PressedIdx
    bmi :+
    pla
    tax
    lda KeyboardPressed+0
    sta Cells, x
    ldy #0
    sty SpriteZero+1
    rts
:
    ; don't return until we have something
    jsr WaitForNMI
    jmp @loop

PrintChar:
    jsr WaitForNMI
    stx TmpX

    ldx BufferedLen
    ldy Mult3, x
    inc BufferedLen

    lda EditorRow
    asl a
    tax

    clc
    lda EditorLinesPPU+0, x
    adc EditorCol
    sta BufferedTiles+1, y

    lda EditorLinesPPU+1, x
    adc #0
    sta BufferedTiles+0, y

    ldx TmpX
    lda Cells, x
    sta BufferedTiles+2, y

    ; inc column and wrap to new line if needed
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

    ldx TmpX
    ldy #0
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

    lda #0
    sta EditorRow
    sta EditorCol

    lda #State::Input
    jmp ChangeState
:
    rts

