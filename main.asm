;
; lab-2.asm
;
; Created: 10/02/2026 15:58:53
; Author : abigail
;


.include "M328PDEF.inc"
.cseg						;Code Segment (Segmento de Código)
.org 0x00 
.def contador_display =r19 ;definimos que el contador del display va a ser r19
.def leds_a = r17 ; contador de leds 
.def contador_ms = r18 ; contador de

rjmp start

start:
//stack
	LDI r16, LOW (RAMEND)  
	OUT SPL, R16 
	LDI r16, HIGH(RAMEND)
	OUT SPH, R16
	TABLA_SEG: .DB 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71

		// Salidas LEDS PORTB
    LDI r16, 0b0011_1111				 ; Configuramos los bits 0, 1,2,3 somo salida
    OUT DDRB, r16						 ; Puerto D manejará el contador binario de leds
    
		 ; Configuramos el Timer0 (Prescaler 1024)
		 ; en excel, el prescaler nos da un "tick" de 0.000064s entonces lo configuramos asi
    LDI r16, (1 << CS02) | (1 << CS00) 
    OUT TCCR0B, r16						 ; el Timer0 empieza a contar automáticamente

		CLR leds_a				; definimos el contador binario de 4 bits (LEDs)
		CLR contador_ms			; definimos el que ca a contar los overflow del Timer

	ldi r20, (1<<CLKPCE)  //colocamos un prescaler (que tan rapido lee las instrucciones)
	sts CLKPR, R20 
	LDI R20, 0B0000_0100  // dividimos en 16 ya que 2^4 = 16, 1MHz
	STS CLKPR, R20 

	// Salidas
	LDI r16, 0b0111_1111          ; salidas del display
	OUT DDRD, r16				  ; Puerto D manejará el contador del display
	
	// Entradas (pushbutto)
	LDI r16, 0b0000_0001
	out DDRC, r16

	LDI R16, 0b0000_0110 //PULL- UP (en 0V cuenta)
	OUT PORTC,R16

	;DESACTIVAMOS tx y rx
	LDI R16, 0X00
	STS UCSR0B, R16

	clr contador_display 
	rcall display

loop:

;botones
	sbis PINC, PC1		; verifica el bit 1 y llama a inc si el bit "is set"
	rcall DEC_DIS
	sbis PINC, PC2		; verifica si el bit 2 =0 lo que significa que esta encendido. 
	rcall INC_DIS	

;leds overflow (timer)
		 ; Revisar overflow
    IN r16, TIFR0			 ; Leemos el estado de todas las banderas del Timer0
    SBRS r16, TOV0			 ; Si el bit TOV0 es 1, pasa la siguiente línea (Timer Overflow Flag 0)
	RJMP loop			     ; si no se ha desbordado (tov0=0), seguimos esperando
    
; Limpiar bandera TOV0 y contar overflow 
    LDI r16, (1 << TOV0)		; limpiamos la bandera TOV0 escribiendo un 1 en ella	
    OUT TIFR0, r16				; esto para prepararse a la siguiente vuelta
    
	 INC contador_ms				; Incrementamos nuestro contador de overflow
    
    ; 6 overflows necesarios
    CPI contador_ms, 5			
    BRLO loop					; "Branch if Lower" si r18 < 5, volvemos al inicio a esperar otro overflow
    
;Incrementar contador
    CLR contador_ms					; reiniciamos el contador de los overflows
    INC leds_a						; iniciamos sumando en el contador de LEDs
    ANDI leds_a, 0b0000_1111		; aseguramos usar solo 4 bits (porque el andi mantiene unicamente lo que esta en 1)
	out portb, leds_a
    
//COMPARACIÓN CON EL DISPLAY
    CP leds_a, contador_display		 ;
    BRLO loop						 ; Si no ha llegado al valor del display, vuelve
    
    ; Si ya llego al valor
    CLR leds_a               ; Reiniciamos el segundero
    SBI PINC, 0              ; Invertimos el LED en A0 (PC0)				
    
    RJMP loop

	//SUBRUTINAS
DEC_DIS:
rcall DELAY
dec contador_display				;decrementa el contador de los leds amarillos 
andi contador_display, 0b0000_1111; compara para no pasar de 1111 el contador y si pasa vuelve a 0
rcall display
	W_A0: 
	SBIS PINC, 1				; verifica si esta ya en 1 entonces sigue el ret pero si es 0 (osea apachado) 
	RJMP W_A0					;entonces vuelve a a verificar hasta que lo hayamos soltado
	ret	

INC_DIS:
rcall DELAY
inc contador_display
andi contador_display, 0b0000_1111 ;deja lo que no es 1 y deja todo en 0 
rcall display
	W_A1: 
	SBIS PINC, 2		;espera PC1
	RJMP W_A1
	rcall display
	ret

display:
	LDI ZH, HIGH(TABLA_SEG<<1)
	LDI ZL, LOW(TABLA_SEG<<1)
	ADD ZL, contador_display
	LPM r16, Z
	out portd, r16
	ret 

delay:
	LDI R28,0X00
	delay0: //inicia el contador lento
		INC r28 //incrementa el nivel lento
		LDI r27,0x00 //reinicia el contador medio para la siguiente vuelta
		delay1: 
		INC r27		//incrementa el nivel medio  
		LDI r26, 0x00 //reinicia el contador rapido 
		delay2: 
			INC r26		//incrementamos el nivel rapido
			CPI R26,50	//verifica a que valor llego r26
			BRNE delay2 //si no ha llegado a 50 repetimos 'delay2' osea el rapido
			CPI R27,50	//verifica si el medio llego a 50
			BRNE DELAY1	 //si no ha llegado, repetimos el medio y el rapido
		CPI R28,50		//verifica si llego a 50 el lento
		BRNE DELAY0 //si no ha llegado repite todo delay 0
		RET