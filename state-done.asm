Init_Done:
    lda #Text::Done
    jsr WriteTitle

    lda #Text::Stop
    ldx #0
    ldy #$11
    jsr WriteBottom

    lda #0
    sta SpriteZero+1

    rts

State_Done:
    jsr JustReadKeyboard
    jsr JustDecodeKeyboard

    lda PressedIdx
    bpl :+
    rts
:
    ldx #0
@loop:
    lda KeyboardPressed, x
    cmp #$11
    bne :+

    lda #0
    sta EditorRow
    sta EditorCol

    lda #State::Input
    jmp ChangeState
:
    inx
    cpx #8
    bne @loop
    rts
