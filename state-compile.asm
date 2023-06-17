;
; things needed:
;   LT & GT on 16-bit values
;       needed for calculating branches & long branches
;   op code cache/lookup
;   references to start & end loops

.enum Instr
Inc
Dec
Next
Prev
Out
In
LoopStart
LoopEnd
.endenum

;    ldx #0
;
;ShortExample:
;    ; program start
;    inc Cells, x
;    inc Cells, x
;    inc Cells, x
;    inc Cells, x
;    inc Cells, x
;
;    inx
;    beq @loopend
;@loop:
;    inc Cells, x
;    inc Cells, x
;    inc Cells, x
;    inc Cells, x
;    inc Cells, x
;    dex
;    dec Cells, x
;    bne @loop
;@loopend:
;
;LongExample:
;    ; program start
;    inc Cells, x
;    inc Cells, x
;    inc Cells, x
;    inc Cells, x
;    inc Cells, x
;
;    inx
;    bne @loop
;    jmp @loopend
;@loop:
;    inc Cells, x
;    inc Cells, x
;    inc Cells, x
;    inc Cells, x
;    inc Cells, x
;    dex
;    dec Cells, x
;    beq @loopend
;    jmp @loop
;@loopend:

Init_Compile:
    lda #.lobyte(BorderTileData)
    sta AddressPointer1+0
    lda #.hibyte(BorderTileData)
    sta AddressPointer1+1

    lda #$20
    sta AddressPointer2+1
    lda #$00
    sta AddressPointer2+0

    jsr DrawTiledData

    ;lda #Text::Compiling
    lda #Text::Running
    jsr WriteTitle

    lda #Text::Stop
    ldx #0
    ldy #$11
    jsr WriteBottom

    jsr ClearCells

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

    ldx #0
    cmp #'+'
    beq @doCopy

    inx
    cmp #'-'
    beq @doCopy

    inx
    cmp #'<'
    beq @doCopy

    inx
    cmp #'>'
    beq @doCopy

    inx
    cmp #'['
    beq @doCopy

    inx
    cmp #']'
    beq @doCopy

    inx
    cmp #'.'
    beq @doCopy

    inx
    cmp #','
    beq @doCopy

    jmp @next

@doCopy:
    jsr CompileInstr

    ;inc AddressPointer2+0
    ;bne @next
    ;inc AddressPointer2+1

@next:
    inc AddressPointer1+0
    bne :+
    inc AddressPointer1+1
:
    jmp @loop

@done:

    ; Write change state code to end of program
    ldx #8
    jsr CompileInstr

    lda #.lobyte(PostNMI_Compile)
    sta PostNMI+0
    lda #.hibyte(PostNMI_Compile)
    sta PostNMI+1

    rts

State_Compile:

    ; Reset engine state
    jsr ClearCells
    ldx #0

    ; Run code
    jsr Compiled

    ; We done
    lda #State::Done
    jmp ChangeState

PostNMI_Compile:
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

CompileInstr:
    txa
    pha
    tay
    asl a
    tax

    lda Instr_Lookup+0, x
    sta AddressPointer3+0
    lda Instr_Lookup+1, x
    sta AddressPointer3+1

    cpy #4 ; start loop
    bne :+

    ; Get address for after check
    ldx LoopStackIdx
    lda AddressPointer2+0
    clc
    adc #8
    sta LoopStackLo
    lda AddressPointer2+1
    adc #0
    sta LoopStackHi
    inx
    stx LoopStackIdx
:

    ldy #0
    lda (AddressPointer3), y
    tax
    inc AddressPointer3+0
    bne :+
    inc AddressPointer3+1
:

@loop:
    lda (AddressPointer3), y
    sta (AddressPointer2), y

    inc AddressPointer3+0
    bne :+
    inc AddressPointer3+1

:   inc AddressPointer2+0
    bne :+
    inc AddressPointer2+1
:
    dex
    bne @loop

    pla
    cmp #5 ; end loop
    beq :+
    rts

:   ; Get loop start address off "stack"
    dec LoopStackIdx
    ldx LoopStackIdx
    lda LoopStackLo, x
    sta (AddressPointer2), y
    ; Subtract 2 to get the address of the
    ; first byte of the JMP argument
    sec
    sbc #2
    sta AddressPointer3+0

    inc AddressPointer2+0
    bne :+
    inc AddressPointer2+1
:
    lda LoopStackHi, x
    sta (AddressPointer2), y
    sbc #0
    sta AddressPointer3+1

    inc AddressPointer2+0
    bne :+
    inc AddressPointer2+1
:

    ; loop start jmp addr in AddressPointer3
    ; need to store AddressPointer2 value
    ; at (AddressPointer3)

    lda AddressPointer2+0
    sta (AddressPointer3), y

    iny
    lda AddressPointer2+1
    sta (AddressPointer3), y
    ldy #0

    rts

Instr_Lookup:
    .word Instr_Inc
    .word Instr_Dec
    .word Instr_Prev
    .word Instr_Next
    .word Instr_LoopStart
    .word Instr_LoopEnd
    .word Instr_Out
    .word Instr_In
    .word Instr_Done

Instr_Inc: ; +
    .byte (@end - * - 1)
    inc Cells, x
@end:

Instr_Dec: ; -
    .byte (@end - * - 1)
    dec Cells, x
@end:

Instr_Next: ; >
    .byte (@end - * - 1)
    inx
@end:

Instr_Prev: ; <
    .byte (@end - * - 1)
    dex
@end:

Instr_Out: ; .
    .byte (@end - * - 1)
    jsr PrintChar
@end:

Instr_In: ; ,
    .byte (@end - * - 1)
    jsr GetChar
@end:

Instr_LoopStart: ; [
    .byte (@end - * - 1)
    lda Cells, x
    .byte $D0, $03 ; bne @loop
    jmp $FFFF ; @loopend
;@loop:
    ; loop here
;@loopend:
@end:

Instr_LoopEnd: ; ]
    .byte (@end - * - 1)
;@loop:
    ; loop here
    lda Cells, x
    .byte $F0, $03 ; beq @end
    ;jmp $FFFF ; @loop
    .byte $4C ; JMP
;@loopend:
@end:

Instr_Done:
    .byte (@end - * - 1)
    rts
@end:
