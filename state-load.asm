Init_Load:
    lda #.lobyte(BorderTileData)
    sta AddressPointer1+0
    lda #.hibyte(BorderTileData)
    sta AddressPointer1+1

    lda #$20
    sta AddressPointer2+1
    lda #$00
    sta AddressPointer2+0

    jsr DrawTiledData
    jsr DrawLogo

    ; Draw the menu items
    lda #.lobyte(MenuStartAddress)
    sta AddressPointer1+0
    lda #.hibyte(MenuStartAddress)
    sta AddressPointer1+1

    ldx #0
@items:
    lda ExamplePrograms+0, x
    ora ExamplePrograms+1, x
    beq @done

    lda AddressPointer1+1
    sta $2006
    lda AddressPointer1+0
    sta $2006

    lda ExamplePrograms+0, x
    sta AddressPointer2+0
    lda ExamplePrograms+1, x
    sta AddressPointer2+1

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
    jmp @items

@done:

    lda #0
    sta MenuSelect

    lda MenuCursor+0
    sta SpriteZero+0
    lda #32
    sta SpriteZero+3

    lda #2
    sta SpriteZero+1
    lda #0
    sta SpriteZero+2

    lda #Text::Load
    jsr WriteTitle

    lda #Text::Menu
    ldx #0
    ldy #$12
    jsr WriteBottom
    rts

State_Load:
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
    ldy #ExampleProgramCount
    dey
    sty MenuSelect

:   ;lda KeyboardPressed, x
    cmp #$04 ; down
    bne :+

    inc MenuSelect
    ldy MenuSelect
    cpy #ExampleProgramCount
    bcc :+
    ldy #0
    sty MenuSelect

:   cmp #$12
    bne :+
    lda #State::Menu
    jmp ChangeState

:   cmp #$0A
    bne :+

    jmp LoadSelected

:   inx
    cpx BufferedLen
    bne @loop

@done:

    ldy MenuSelect
    lda MenuCursor, y
    sta SpriteZero+0
    rts

LoadSelected:
    jsr ClearCodeRam
    jsr ClearCells

    lda MenuSelect
    asl a
    tax

    lda ExamplePrograms+0, x
    sta AddressPointer1+0
    lda ExamplePrograms+1, x
    sta AddressPointer1+1

    ldy #0
@skip: ; look for end of text
    lda (AddressPointer1), y
    beq :+
    iny
    jmp @skip
:

    iny
    tya
    clc
    adc AddressPointer1+0
    sta AddressPointer1+0

    lda AddressPointer1+1
    adc #0
    sta AddressPointer1+1

    lda #.lobyte(Code)
    sta AddressPointer2+0
    lda #.hibyte(Code)
    sta AddressPointer2+1

    ; load program
    ldy #0
@load:
    lda (AddressPointer1), y
    beq @done
    sta (AddressPointer2), y

    inc AddressPointer1+0
    bne :+
    inc AddressPointer1+1
:

    inc AddressPointer2+0
    bne :+
    inc AddressPointer2+1
:
    jmp @load

@done:
    lda #0
    sta EditorRow
    sta EditorCol

    lda #State::Input
    jmp ChangeState

ExamplePrograms:
    .word Prg_Hello
    .word Prg_Echo
    .word Prg_Sanity
ExampleProgramCount = (* - ExamplePrograms) / 2
    .word $0000 ; null terminated

Prg_Hello:
    .asciiz "Hello.bf"
    .asciiz "++++++++++[>+++++++>++++++++++>+++>+<<<<-]>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>."

Prg_Echo:
    .asciiz "Echo.bf"
    .asciiz "+[>,.<]"

Prg_Sanity:
    .asciiz "sanity.bf"
    .asciiz "++[->+<]"
