; definicao dos metadados
.segment "HEADER"
.byte "NES", $1a ;identificador iNES
.byte $2 ; 2 x 16KB PRG ROM
.byte $1 ; 1 x 16KB CHR ROM
.byte $1 ; espelhamento vertical
.byte $0

; exigido pelo compilador -> pode fica vazio
.segment "STARTUP"

; local para definicao de variaveis
.segment "ZEROPAGE"
posX: .res 1
indAnim: .res 1
frame: .res 1
frameMusica: .res 1

; definindo o vetor de interrupcao
.segment "VECTORS"
.addr nmi ; interrupcoes nao mascaraveis -> FFFA - $FFFB
.addr reset ; ao apertar botao reset -> $FFFC - $FFFD
.addr $0 ; nao sera usado por enquanto -> $FFFE - $FFFF

; codigo -> inicia em $8000
.segment "CODE"
; aguardar v-blank -> momento em que o canhao de eletrons deve retornar para o canto superior esquerdo da tela
esperar_vblank:
bit $2002
bpl esperar_vblank
rts

; posicao Y, indice na CHR ROM, atributos, posicao X
.macro desenhar_sprite endereco, posY, indice, atributos, posX
ldx endereco
lda posY
sta $0200,x
lda indice
sta $0201,x
lda atributos
sta $0202,x
lda posX
sta $0203,x
.endmacro

reset:
cld
sei
ldx #%01000000 
stx $4017 ; desabilitar APU frame IRQ
ldx #$ff
txs ; ajustando registrador SP para apontar ´para o inicio da pilha
inx
stx $2000 ; desabilitando NMI
stx $2001 ; desabilitando renderizacao de sprites
stx $4010 ; desabilitar DMC IRQ

jsr esperar_vblank

; memoria RAM -> $0000 - $07FF
limpar_memoria:
lda #$fe
sta $0200,x ; regiao $0200 - $02FF sera reservada para DMA
lda #$00
sta $0000,x
sta $0100,x
sta $0300,x
sta $0400,x
sta $0500,x
sta $0600,x
sta $0700,x
inx
bne limpar_memoria

jsr esperar_vblank

; PPU pronta para ser usada
limpar_background:
lda $2002
lda #$20
sta $2006
lda #$00
sta $2006 ; endereco $2000 na PPU
ldy #$00
lda #$04
@loop:
sta $2007
iny
bne @loop
inx
cpx #$04
bne @loop

desenhar_linha1:
lda $2002
lda #$21
sta $2006
lda #$20
sta $2006
lda #$34
@loop:
sta $2007
iny
cpy #$20
bne @loop

desenhar_linha2:
lda $2002
lda #$22
sta $2006
lda #$40
sta $2006
lda #$34
ldy #$00
@loop:
sta $2007
iny
cpy #$20
bne @loop

carregar_paletas:
lda $2002
lda #$3f
sta $2006
stx $2006 ; endereco $3F00 na PPU
@loop:
lda paletas,x
sta $2007
inx
cpx #$20
bne @loop

permitir_renderizacao:
ldx #%10000000
stx $2000 ; ativa NMI
ldx #%00011010
stx $2001 ; permite exibir as sprites e background

definir_valores_iniciais:
lda #$05
sta posX
lda #$15
sta indAnim

jsr iniciar_apu

; nao permite que o registrador PC acesse as proximas posicoes da memoria
loop_eterno:
jmp loop_eterno

; ocorre 1 vez a cada frame -> aqui tera a logica principal do programa
nmi:
ldx #$00
stx $2003
ldx #$02
stx $4014 ; realizar DMA

; salvar posX
lda posX 
pha

; escrever a mensagem
desenhar_sprite #$00,#$60,#$13,#$00, posX
adc #$08
sta posX
desenhar_sprite #$04,#$60,#$01,#$00, posX
adc #$08
sta posX
desenhar_sprite #$08,#$60,#$02,#$00, posX
adc #$08
sta posX
desenhar_sprite #$0c,#$60,#$20,#$00, posX
adc #$08
sta posX
desenhar_sprite #$10,#$60,#$21,#$00, posX
sbc #$08
sta posX

desenhar_sprite #$14,#$6f,#$22,#$00, posX
adc #$08
sta posX
desenhar_sprite #$18,#$6f,#$23,#$00, posX
adc #$08
sta posX
desenhar_sprite #$1c,#$6f,#$30,#$00, posX
adc #$08
sta posX
desenhar_sprite #$20,#$6f,#$23,#$00, posX
adc #$08
sta posX
desenhar_sprite #$24,#$6f,#$02,#$00, posX

; recuperar e atualizar posX
pla 
sta posX
inc posX

; desenhar decoracoes
ldx indAnim
cpx #$19
bne @reiniciarAnimacao
ldx #$15
stx indAnim
@reiniciarAnimacao:

desenhar_sprite #$28,#$4b,indAnim,#$01, #$6c
desenhar_sprite #$2c,#$93,indAnim,#$02, #$40
desenhar_sprite #$44,#$93,indAnim,#$01, #$91
desenhar_sprite #$48,#$4b,indAnim,#$03, #$9f

; obter segundo indice de animacao
lda indAnim
pha 
clc
lda #$18
sbc indAnim
clc
adc #$15
sta indAnim

desenhar_sprite #$34,#$4b,indAnim,#$03, #$34
desenhar_sprite #$38,#$93,indAnim,#$01, #$12
desenhar_sprite #$3c,#$93,indAnim,#$03, #$67
desenhar_sprite #$40,#$4b,indAnim,#$02, #$81
desenhar_sprite #$30,#$93,indAnim,#$02, #$af
desenhar_sprite #$4c,#$4b,indAnim,#$01, #$bc

; recuperar indice de animacao
pla
sta indAnim

clc
lda frame
adc #$01 
and #$03
cmp #$00
bne @semIncremento
inc indAnim
@semIncremento:
sta frame

jsr musica

; nao ha scrolling
lda #$00
sta $2005
sta $2005

rti

iniciar_apu:
; enderecos $4000-4013
ldy #$13
@loop:  
lda @regs,y
sta $4000,y
dey
bpl @loop

lda #$0f
sta $4015
lda #$40
sta $4017

rts
@regs:
.byte $30,$08,$00,$00
.byte $30,$08,$00,$00
.byte $80,$00,$00,$00
.byte $30,$00,$00,$00
.byte $00,$00,$00,$00

;------------------------------------------------------------------------------------------------
musica:

lda #%00000001
sta $4015 ; square 1

lda #%10011111 ; Duty 10, Volume F
sta $4000

ldx frameMusica
cpx #$f0
beq @fim
inc frameMusica
@sem_incremento:

cpx #$10 
beq @n1
cpx #$20 
beq @n1
cpx #$30 
beq @n1

cpx #$50 
beq @n1
cpx #$60 
beq @n1
cpx #$70 
beq @n1

cpx #$90 
beq @n1
cpx #$a0 
beq @n2
cpx #$b0 
beq @n4
cpx #$c0 
beq @n3
cpx #$d0 
beq @n1

jmp @fim

@n1:
lda #$C9 
sta $4002
lda #$20
sta $4003
jmp @fim

@n2:
lda #$a9
sta $4002
lda #$20
sta $4003
jmp @fim

@n3:
lda #$e9
sta $4002
lda #$20
sta $4003
jmp @fim

@n4:
lda #$b9
sta $4002
lda #$20
sta $4003
jmp @fim

@fim:
rts
;------------------------------------------------------------------------------------------------

paletas:
; background
.byte $0f, $20, $20, $20
.byte $0f, $00, $00, $00
.byte $0f, $00, $00, $00
.byte $0f, $00, $00, $00

;sprites
.byte $0f, $10, $00, $00 ; letras
.byte $0f, $09, $19, $29 ; verde
.byte $0f, $06, $16, $36 ; vermelho
.byte $0f, $01, $11, $21 ; azul

bg_nam:

.incbin "screen.nam"

; armazena as sprites
.segment "CHARS"
.incbin "letras.chr"