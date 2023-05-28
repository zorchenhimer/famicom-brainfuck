Init_Clear:

    jsr ClearCodeRam
    jsr ClearCells

    lda #0
    sta EditorRow
    sta EditorCol

    lda #State::Input
    jmp ChangeState

State_Clear:
    rts
