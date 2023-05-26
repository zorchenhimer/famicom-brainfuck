.enum KeyboardKeys
; Row 0
kbd_CloseBracket
kbd_OpenBracket
kbd_Return
kbd_F8
kbd_Stop
kbd_Yen
kbd_RightShift
kbd_Kana

; Row 1
kbd_SemiColon
kbd_Colon
kbd_At
kbd_F7
kbd_Caret
kbd_Dash
kbd_Slash
kbd_SpaceSymbol

; Row 2
kbd_K
kbd_L
kbd_O
kbd_F6
kbd_0
kbd_P
kbd_Comma
kbd_Period

; Row 3
kbd_J
kbd_U
kbd_I
kbd_F5
kbd_8
kbd_9
kbd_N
kbd_M

; Row 4
kbd_H
kbd_G
kbd_Y
kbd_F4
kbd_6
kbd_7
kbd_V
kbd_B

; Row 5
kbd_D
kbd_R
kbd_T
kbd_F3
kbd_4
kbd_5
kbd_C
kbd_F

; Row 6
kbd_A
kbd_S
kbd_W
kbd_F2
kbd_3
kbd_E
kbd_Z
kbd_X

; Row 7
kbd_Control
kbd_Q
kbd_Escape
kbd_F1
kbd_2
kbd_1
kbd_Graph
kbd_LeftShift

; Row 8
kbd_Left
kbd_Right
kbd_Up
kbd_Clear
kdb_Insert
kbd_Delete
kbd_Space
kbd_Down
.endenum

; Reads the keyboard into the
; KeyboardThisFrame array.
JustReadKeyboard:

    ; Save last frame's presses
    ldx #8
:   lda KeyboardThisFrame, x
    sta KeyboardLastFrame, x
    dex
    bpl :-

    lda #5
    sta $4016

    ldx #0
@readLoop:
    lda #4
    sta $4016
    jsr KeyboardWait

    lda $4017
    asl a
    asl a
    asl a
    and #$F0
    sta KeyboardThisFrame, x

    lda #6
    sta $4016
    lda $4017
    lsr a
    and #$0F
    ora KeyboardThisFrame, x
    sta KeyboardThisFrame, x

    inx
    cpx #9
    bne @readLoop
    rts

; Decodes the keys in the two keyboard
; arrays and sends pressed/held events.
JustDecodeKeyboard:
;    ldx #0 ; key id / "scancode"
;    ldy #0 ; byte in array
;    lda #%1000_0000
;    sta TmpA
;@rowLoop:
;@colLoop:
;    lda TmpA
;    and KeyboardThisFrame, y
;    sta TmpX
;    beq @nextcol
;    ; key pressed
;    and KeyboardLastFrame, y
;    bne :+ ; key is being held from last frame
;    ; no longer pressed.
;    jmp @nextcol
;:
;    lda TmpX
;    sty TmpY
;    inc HeldIdx
;    ldy HeldIdx
;    sta KeyboardHeld, y
;    ldy TmpY
;@nextcol:

    ; clear previous pressed/held values
    lda #$FF
    sta HeldIdx
    sta PressedIdx
    ldx #7
    lda #0
:   sta KeyboardHeld, x
    sta KeyboardPressed, x
    dex
    bpl :-


    ldx #0
    stx TmpZ
@loop:
    ; held keys
    lda KeyboardLastFrame, x
    and KeyboardThisFrame, x
    sta TmpX

    ; pressed tihs frame
    lda KeyboardLastFrame, x
    eor KeyboardThisFrame, x
    and KeyboardThisFrame, x
    sta TmpY

    ldy #0 ; bit in byte
    lda #%1000_0000
    sta TmpA
@keyloop:

    lda TmpA
    and TmpX
    beq @pressed
    ; held
    stx TmpZ
    ; X * 8
    txa
    lsr a
    lsr a
    lsr a
    sty TmpB
    clc ; (X * 8) + Y
    adc TmpB

    ; register event
    inc HeldIdx
    ldx HeldIdx
    cpx #8 ; too many keys pressed
    bcs @pressed
    sta KeyboardHeld, x

@pressed:

    lda TmpA
    and TmpY
    beq @nextkey

    ; X * 8
    txa
    lsr a
    lsr a
    lsr a
    sty TmpB
    clc ; (X * 8) + Y
    adc TmpB

    ; register event
    inc PressedIdx
    ldx PressedIdx
    cpx #8 ; too many keys pressed
    bcs @nextkey
    sta KeyboardPressed, x

@nextkey:
    iny
    lsr TmpA ; mask
    bne @keyloop

    inc TmpZ
    ldx TmpZ
    cpx #9
    bne @loop

    ; check for shift key
    stx Shifted
    lda #$10
    .repeat 8, i
    and KeyboardHeld+i
    .endrepeat
    beq :+
    sta Shifted
:

    lda #$10
    .repeat 8, i
    and KeyboardPressed+i
    .endrepeat
    beq :+
    sta Shifted
:

    ; Pick the correctly shifted table
    lda Shifted
    beq :+
    lda #.lobyte(KeyboardLayoutStd_Shifted)
    sta AddressPointer1+0
    lda #.hibyte(KeyboardLayoutStd_Shifted)
    sta AddressPointer1+1
    jmp :++
:
    lda #.lobyte(KeyboardLayoutStd)
    sta AddressPointer1+0
    lda #.hibyte(KeyboardLayoutStd)
    sta AddressPointer1+1
:

    ; translate "scan codes" to ASCII.
    ldx #0
:
    ldy KeyboardHeld, x
    lda (AddressPointer1), y
    sta KeyboardHeld, x

    ldy KeyboardPressed, x
    lda (AddressPointer1), y
    sta KeyboardPressed, x
    inx
    cpx #8
    bne :-
    rts

ReadKeyboard:

    ; Move last frame's status into bit 7
    ldy #$80
    ldx #0
@clearLoop:
    lda KeyboardStatus, x
    beq @nextClear
    and #$01
    beq :+
    ;sty KeyboardStatus, x ; this addr mode doesn't exist apparently
    ;jmp @nextClear
    tya
:
    sta KeyboardStatus, x
@nextClear:
    inx
    cpx #72
    bne @clearLoop

    ldx #0
    lda #0
:
    sta KeyboardPressed, x
    sta KeyboardHeld, x
    inx
    cpx #8
    bne :-

    lda #$FF
    sta PressedIdx
    sta HeldIdx

    lda #$05
    sta $4016

    ; Read row 0
    lda #$04
    sta $4016
    jsr KeyboardWait

    lda #9
    sta TmpX

    ldx #0
@ReadLoop:
    ; col 0
    lda $4017
    clc
    asl a
    asl a
    asl a
    and #$F0
    sta KeyboardRead

    ; col 1
    lda #$06
    sta $4016
    lda $4017
    lsr a
    and #$0F
    ora KeyboardRead
    sta KeyboardRead

    ; Prep read for next row
    lda #$04
    sta $4016

    ; Decode the row
    lda #%1000_0000
    sta TmpA
    ldy #1
@rowLoop:
    and KeyboardRead
    bne :+
    lda #1
    ora KeyboardStatus, x
    sta KeyboardStatus, x
:
    inx
    lda TmpA
    lsr a
    sta TmpA
    bne @rowLoop

    dec TmpX
    bne @ReadLoop

    ; find out what was pressed this frame.
    ; bits are
    ; 7: last frame's status
    ; 0: currently pressed

    ldx #0
@updateLoop:
    lda KeyboardStatus, x
    beq @next ; wasn't pressed last or this frame

    ;bpl :++  ; was held last frame
    and #$01
    bne :+ ; is pressed
    ; key is released
    sta KeyboardStatus, x ; no longer pressed. clear state
    jmp @next
:
    lda KeyboardStatus, x
    bpl :+ ; was pressed this frame
    ; still pressed
    inc HeldIdx
    ldy HeldIdx
    stx KeyboardHeld, y ; TODO: normalize to ASCII
    jmp @next
:
    ; pressed this frame
    inc PressedIdx
    ldy PressedIdx
    stx KeyboardPressed, y

@next:
    inx
    cpx #72
    bne @updateLoop

    lda #0
    sta Shifted

    lda KeyboardStatus+6 ; Right Shift
    beq :+
    inc Shifted
:
    lda KeyboardStatus+(7*8)+7 ; Left Shift
    beq :+
    inc Shifted
:

    ; Translate to ascii
    ldx #0
@loopAscii:
    ldy KeyboardPressed, x
    beq @nextAscii
    lda Shifted
    bne :+
    lda KeyboardLayoutStd, y
    jmp :++

: ; shift held
    lda KeyboardLayoutStd_Shifted, y
:
    sta KeyboardPressed, x

@nextAscii:
    inx
    cpx #8
    bne @loopAscii
    rts

KeyboardWait:
    ; jsr 6
    ldx #7 ; 2
:
    cpy $8000 ; 4
    dex ; 2
    bne :- ; 3 each loop; 2 on last = 20 total

    rts ; 6

KeyboardLayoutStd:
    .byte "]", "[", $0A, $18, $10, $7F, $0F, $1D
    .byte $3B, ":", "@", $17, "^", "-", "/", "_"
    .byte "k", "l", "o", $16, "0", "p", ",", "."
    .byte "j", "u", "i", $15, "8", "9", "n", "m"
    .byte "h", "g", "y", $14, "6", "7", "v", "b"
    .byte "d", "r", "t", $13, "4", "5", "c", "f"
    .byte "a", "s", "w", $12, "3", "e", "z", "x"
    .byte $05, "q", $1B, $11, "2", "1", $17, $0F
    .byte $01, $02, $03, $0D, $1A, $08, " ", $04

KeyboardLayoutStd_Shifted:
    .byte "]", "[", $0A, $18, $10, $7F, $0F, $1D
    .byte $3B, "*", "@", $17, "^", "=", "?", "_"
    .byte "K", "L", "O", $16, "0", "P", "<", ">"
    .byte "J", "U", "I", $15, "(", ")", "N", "M"
    .byte "H", "G", "Y", $14, "&", "'", "V", "B"
    .byte "D", "R", "T", $13, "$", "%", "C", "F"
    .byte "A", "S", "W", $12, $23, "E", "Z", "X"
    .byte $05, "Q", $1B, $11, $22, "!", $17, $0F
    .byte $01, $02, $03, $0D, $1A, $08, " ", $04
