Init_StateHelp:
    lda #.lobyte(PaletteData)
    sta AddressPointer1+0
    lda #.hibyte(PaletteData)
    sta AddressPointer1+1
    ldx #32

    jsr WritePaletteData

    lda #.lobyte(HelpScreenData)
    sta AddressPointer1+0
    lda #.hibyte(HelpScreenData)
    sta AddressPointer1+1

    lda #$20
    sta AddressPointer2+1
    lda #$00
    sta AddressPointer2+0

    jsr DrawTiledData

    lda #$FF
    sta SpriteZero+0
    sta SpriteZero+1
    sta SpriteZero+2
    sta SpriteZero+3
    rts

State_Help:
    jsr JustReadKeyboard
    jsr JustDecodeKeyboard

    ldx #0
@loop:
    lda KeyboardPressed, x
    beq @next

    cmp #$11
    bne @next
    lda PreviousState
    jmp ChangeState
@next:
    inx
    cpx #8
    bne @loop
    rts

HelpScreenData:
    .include "help.i"
    .byte $00
