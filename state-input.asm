Init_StateInput:
    lda #.lobyte(BorderTileData)
    sta AddressPointer1+0
    lda #.hibyte(BorderTileData)
    sta AddressPointer1+1

    lda #$20
    sta AddressPointer2+1
    lda #$00
    sta AddressPointer2+0

    jsr DrawTiledData

    ; repopulate the screen
    ldx #0 ;row
@row:
    txa
    asl a
    tay

    lda EditorLinesRam+0, y
    sta AddressPointer1+0
    lda EditorLinesRam+1, y
    sta AddressPointer1+1

    lda EditorLinesPPU+1, y
    sta $2006
    lda EditorLinesPPU+0, y
    sta $2006

    ldy #0 ;column
@col:
    lda (AddressPointer1), y
    sta $2007
    iny
    cpy #EditorLineLength
    bne @col

    inx
    cpx #EditorLineCount
    bne @row

    lda #Text::Code
    jsr WriteTitle

    lda #Text::Help
    ldx #0
    ldy #$11
    jsr WriteBottom

    lda #Text::Menu
    ldx #9
    ldy #$12
    jsr WriteBottom

    lda #Text::Run
    ldx #18
    ldy #$13
    jsr WriteBottom

    ; Position sprite
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

State_Input:
    jsr JustReadKeyboard
    jsr JustDecodeKeyboard

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
    sta BufferedTiles, y
    iny
    lda EditorCol
    sta BufferedTiles, y
    iny
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

    lda BufferedLen
    beq @skipTranslate

    ; Translate buffer changes to PPU addresses
    ; and apply to code in ram.
    ; Buffer should countain sets of (Row, Col, Data)
    ldx #0
    stx TmpX
@translateLoop:

    ; find code pointer
    lda BufferedTiles+0, x
    asl a
    tay

    lda EditorLinesRam+0, y
    clc
    adc BufferedTiles+1, x
    sta AddressPointer1+0

    lda EditorLinesRam+1, y
    adc #0
    sta AddressPointer1+1

    lda BufferedTiles+2, x

    ; Update code
    ldy #0
    sta (AddressPointer1), y

    ; Find PPU addr
    lda BufferedTiles+0, x ; row
    asl a
    tay

    lda EditorLinesPPU+0, y
    clc
    adc BufferedTiles+1, x ; col
    sta BufferedTiles+1, x

    lda EditorLinesPPU+1, y
    adc #0
    sta BufferedTiles+0, x

    inx
    inx
    inx

    inc TmpX
    lda TmpX
    cmp BufferedLen
    bcc @translateLoop

@skipTranslate:
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

    ldx BufferedLen
    ldy Mult3, x
    inc BufferedLen

    lda EditorRow
    sta BufferedTiles+0, x
    lda EditorCol
    sta BufferedTiles+1, x
    lda #' '
    sta BufferedTiles+2, x

    rts

KeyLeft:
    lda EditorCol
    beq :+
    dec EditorCol
:   rts

KeyRight:
    lda EditorCol
    cmp #EditorLineLength-1
    bcs :+
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
    lda #State::Help
    jmp ChangeState

KeyMenu:
    lda #State::Menu
    jmp ChangeState

KeyRun:
    lda #State::Run
    jmp ChangeState

KeyCompile:
    lda #State::Compile
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
    .word $0000 ; kana key
    .word KeyReturn ; $0A
    .word $0000
    .word $0000
    .word $0000
    .word $0000
    .word $0000
    .word $0000
    .word KeyHelp
    .word KeyMenu
    .word KeyRun
    .word KeyCompile

    ; $0C-$19
    .repeat 8
    .word $0000
    .endrepeat

EditorLinesPPU:
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

; Like EditorLinesPPU, but for
; the code in ram instead of the PPU
EditorLinesRam:
    .repeat EditorLineCount, i
    .word Code+(i*EditorLineLength)
    .endrepeat

Mult3:
    .repeat 8, i
    .byte 3*i
    .endrepeat
