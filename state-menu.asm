Init_Menu:
    lda #.lobyte(BorderTileData)
    sta AddressPointer1+0
    lda #.hibyte(BorderTileData)
    sta AddressPointer1+1

    lda #$20
    sta AddressPointer2+1
    lda #$00
    sta AddressPointer2+0

    jsr DrawTiledData

    ; Draw the menu items
    lda #$20
    sta AddressPointer1+1
    lda #$E6
    sta AddressPointer1+0

    ldx #0
@items:
    lda MenuItems+0, x
    ora MenuItems+1, x
    beq @done

    lda AddressPointer1+1
    sta $2006
    lda AddressPointer1+0
    sta $2006

    lda MenuItems+0, x
    sta AddressPointer2+0
    lda MenuItems+1, x
    sta AddressPointer2+1

    lda MenuItems+2, x
    ldy MenuLength
    sta MenuState, y
    inc MenuLength

    ldy #0
@text:
    lda (AddressPointer2), y
    beq @next
    sta $2007
    iny
    jmp @text

@next:
    clc
    lda AddressPointer1+0
    adc #64
    sta AddressPointer1+0

    lda AddressPointer1+1
    adc #0
    sta AddressPointer1+1

    inx
    inx
    inx
    jmp @items

@done:

    lda MenuCursor+0
    sta SpriteZero+0
    lda #32
    sta SpriteZero+3

    lda #2
    sta SpriteZero+1
    lda #0
    sta SpriteZero+2

    lda #Text::Menu
    jsr WriteTitle

    rts

State_Menu:
    jsr JustReadKeyboard
    jsr JustDecodeKeyboard

    ldx #0
@loop:
    lda KeyboardPressed, x
    beq @done
    cmp #$03 ; up
    bne :+

    dec MenuSelect
    bpl :+
    ldy #MenuLength
    dey
    sty MenuSelect

:   ;lda KeyboardPressed, x
    cmp #$04 ; down
    bne :+

    inc MenuSelect
    ldy MenuSelect
    cpy #MenuLength
    bcc :+
    ldy #0
    sty MenuSelect

:   cmp #$0A
    bne :+

    ldy MenuSelect
    lda MenuState, y

    ldy #0
    sty MenuSelect

    jmp ChangeState

:   inx
    cpx BufferedLen
    bne @loop

@done:

    ldy MenuSelect
    lda MenuCursor, y
    sta SpriteZero+0
    rts

MenuCursor:
    .repeat 10, i
    .byte 56 + (16 * i)
    .endrepeat

MenuItems:
    .word :+
    .byte State::Input

    .word :++
    .byte State::Help

    .word :+++
    .byte State::Load

    .word :++++
    .byte State::Clear

MenuLength = (* - MenuItems) / 3
    .word $0000 ; null terminated

:   .asciiz "Start programming"
:   .asciiz "View help"
:   .asciiz "Load example program"
:   .asciiz "Clear program"
