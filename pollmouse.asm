;----[ pollmouse.a ]--------------------

;Copyright (C) 2019 Gregory Nacu

;1351 Mouse Driver
; - Fully Commented
; - Screen Edge Bounded
; - Accelerated
; - Two Sprites
; - 16-bit Overflow Prevention

irqvec   = $0314
vic      = $d000
sid      = $d400

         *= $c000

         ldx irqvec
         ldy irqvec+1

         stx sysirq+1
         sty sysirq+2

         ldx #<mouseirq
         ldy #>mouseirq

         php
         sei

         stx irqvec
         sty irqvec+1

         plp

         lda #%00000011
         sta vic+$15 ;Enable Sprites

         rts

;---------------------------------------

mouseirq cld

         jsr scanmovs
         jsr boundmus

sysirq   jmp $ffff

;---------------------------------------

potx     = sid+$19
poty     = sid+$1a

xpos     = vic+$00
ypos     = vic+$01
xpos2    = vic+$02
ypos2    = vic+$03

xposmsb  = vic+$10

maxx     = 319 ;Screen Width
maxy     = 199 ;Screen Height

offsetx  = 24 ;Sprite left border edge
offsety  = 50 ;Sprite top  border edge

accelthr = 10 ;Acceleration threshold

musposx  .word 320/2
musposy  .word 200/2

boundmus
         ldx musposx+1
         bmi zerox
         beq chky

         ldx #maxx-256
         cpx musposx
         bcs chky

         stx musposx
         bcc chky

zerox    ldx #0
         stx musposx
         stx musposx+1

chky     ldy musposy+1
         bmi zeroy
         beq loychk

         dec musposy+1
         ldy #maxy
         sty musposy
         bne movemus

loychk   ldy #maxy
         cpy musposy
         bcs movemus

         sty musposy
         bcc movemus

zeroy    ldy #0
         sty musposy
         sty musposy+1

movemus  clc
         lda musposx
         adc #offsetx
         sta xpos
         sta xpos2

         lda musposx+1
         adc #0
         beq clearxhi
         
         ;set x sprite pos high
         lda xposmsb
         ora #%00000011         
         bne *+7
         
clearxhi ;set x sprite pos low
         lda xposmsb
         and #%11111100
         
         sta xposmsb

         clc
         lda musposy
         adc #offsety
         sta ypos
         sta ypos2

         rts

;---------------------------------------

scanmovs

         ;--- X Axis ---
         ldy potx
oldpotx  lda #0
         jsr movechk
         beq noxmove

         sty oldpotx+1

         clc
         adc musposx
         sta musposx
         txa            ;upper 8-bits
         adc musposx+1
         sta musposx+1
noxmove

         ;--- Y Axis ---
         ldy poty
oldpoty  lda #0
         jsr movechk
         beq noymov

         sty oldpoty+1

         clc
         eor #$ff       ;Reverse Sign
         adc #1

         clc
         adc musposy
         sta musposy
         txa            ;Upper 8-bits
         eor #$ff       ;Reverse Sign
         adc musposy+1
         sta musposy+1
noymov
         rts

movechk  ;A -> Old Pot Value
         ;Y -> New Pot Value

         and #%01111110
         sta oldvalue+1
         tya

         sec
oldvalue sbc #$ff
         and #%01111110    ; clear sign bit and noise bit
         beq nomove

         lsr a             ; shift out noise bit (already zeroed, so carry is now cleared)

         ; sign extend bit 5
         adc #%11100000
         eor #%11100000
         bmi neg

         ; +ve

         ldx #$00
         cmp #accelthr ;Acceleration Speed
         bcc noposaccel
         asl a   ;X2
         sbc #((2-1)*accelthr)-1
noposaccel

         ;A > 0
         ;X = $00 (sign extension)
         ;Y = newvalue
         ;Z = 0

         rts


neg      ; -ve

         ldx #$ff
         cmp #-accelthr ;Acceleration Speed
         bcs nonegaccel
         asl a       ;X2
         adc #((2-1)*accelthr)-1
nonegaccel

         ;A < 0
         ;X = $ff (sign extension)
         ;Y = newvalue
         ;Z = 0

         ;fallthrough

nomove   ;A = -
         ;X = -
         ;Y = -
         ;Z = 1

         rts
