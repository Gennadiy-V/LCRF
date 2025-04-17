;**********************************************************************
;    Filename:      MY_LCRF.asm                                         *
;    Date:          17.11.2012                                       *
;    File Version:  v 3.1.0                                           *
;**********************************************************************
;    Files required:                                                  *
;**********************************************************************
;    Notes:                                                           *
;**********************************************************************

;сделать 
;автодетект индикатора
;вкл/выкл генератора
;вкд/выкл автовыключение


;
;	Теория

; Программа работы LC-метра с использованием генераторного метода
; Номинальная частота кварца Fo=20'000'000 Гц.
;
; Вычисление емкости кондесаторов генераторным методом проводится согласно выражения
; Cx=COEFF_C*[nx*No/no*Nx-1]
; Rx=Ro*[nx*No/no*Nx-1], 
;, где
; Ro-точно известное значение опорного резистора, при котором производилась калибровка
; Co-точно известное значение опорного конденсатора, при котором производилась калибровка
; nx-целое число периодов Fo, подсчитанных счетчиком за время измерения Nx периодов колебаний генератора,
; образованного (Cx+Co)*Ro
; no-целое число периодов Fo, подсчитанных счетчиком за время измерения Nx периодов колебаний генератора,
; образованного Ro*Co при калибровке

; Вычисление индуктивности L генераторным методом проводится по выражению
; Lx=COEFF_L*[(nx*No/no*Nx)^2-1]
; где nx-целое число периодов тактовой частоты контроллера (Fo) за время измерения Nx
; no-целое число периодов Fo за время измерения No
; Nx-целое число периодов частоты генератора с подключенным измеряемым элементом за принятое время измерения
; No-целое число периодов частоты генератора с подключенным эталонным элементом за принятое время измерения

; Калибровка

; Нажать кнопку "0". После измерения и запоминания значений no, No о чем свидетельствует
; появление индикации "0.00", кнопку "0" отпустить.
; Подключить конденсатор известной величины к входам "Сx" и проверить правильность показаний.
; При калибровке канала измерения индуктивности вход "Lx" замкнуть накоротко.
;00 ; ЗАПОМНИТЬ ЧАСТОТУ НАЧАЛЬНОЙ ГЕНЕРАЦИИ  , КОНДЕР НЕ ПОДКЛЮЧЕН
;01 ; ЗАПОМНИТЬ ЧАСТОТУ НАЧАЛЬНОЙ ГЕНЕРАЦИИ  , РЕЗИСТОР ЗАМКНУТЬ
;02 ; ЗАПОМНИТЬ ЧАСТОТУ НАЧАЛЬНОЙ ГЕНЕРАЦИИ  , ИНДУКТИВНОСТЬ  ЗАМКНУТЬ
;03 ;  -----  Подключить извесный конденсатор и добиться его показаний
;04 ;  -----  Подключить извесный РЕЗИСТОР и добиться его показаний
;05 ;  -----  Подключить извесный INDUKTOR и добиться его показаний


	list		p=16f886		; list directive to define processor
	#include	<p16f886.inc>	; processor specific variable definitions


	__CONFIG    _CONFIG1, _LVP_OFF & _FCMEN_OFF & _IESO_OFF & _BOR_ON & _CPD_OFF & _CP_ON & _MCLRE_OFF & _PWRTE_ON & _WDT_OFF & _HS_OSC  & _DEBUG_OFF 
	__CONFIG    _CONFIG2, _WRT_HALF & _BOR21V

;**********************************************************************
;***** ЗАДАНИЕ ПЕРЕМЕННЫХ  Общее для всех банков
IND_1		EQU	0x70
IND_2		EQU	0x71
IND_3		EQU	0x72
IND_4		EQU	0x73

COUNT_TIMER_1		EQU	0x74


FLAG			EQU	0x75
#define   FLAG_SAVE_MODE				FLAG,0 ; 
#define   FLAG_DEBUG_MODE				FLAG,1 ;
#define   FLAG_SKIP_CLEAR_TMR1			FLAG,2 ;
#define   FLAG_PRESS_KEY_ZERRO_MID			FLAG,3 ; 
#define   FLAG_PRESS_KEY_ZERRO_SHORT		FLAG,4 ;  
#define   FLAG_PRESS_KEY_ZERRO_MID_1 		FLAG,5 ;  FLAG 
#define   FLAG_NEW_MODE		FLAG,6 ;  FLAG 
#define   FLAG_LCD_ON				FLAG,7 ;  FLAG 

FLAG1			EQU	0x76
#define   FLAG_FLASH_DP4			FLAG1,0 ; 
#define   FLAG_CALC_100MS			FLAG1,1 ;
#define   FLAG_FCOUNT_GO			FLAG1,2 ;
#define   FLAG_START_FCOUNT			FLAG1,3 ; 
#define   FLAG_MODE_F				FLAG1,4 ;  
#define   FLAG_MODE_L 				FLAG1,5 ;  FLAG 
#define   FLAG_MODE_C				FLAG1,6 ;  FLAG 
#define   FLAG_MODE_R				FLAG1,7 ;  FLAG 

FLAG2			EQU	0x77
#define   FLAG_INVERT_INDIKATOR		FLAG2,0 ;   0 = BSR  1 = ASR
#define   FLAG_9		FLAG2,1 ;
#define   FLAG_A		FLAG2,2 ;
#define   FLAG_B		FLAG2,3 ; 
#define   FLAG_C		FLAG2,4 ;  
#define   FLAG_D 		FLAG2,5 ;  FLAG 
#define   FLAG_E		FLAG2,6 ;  FLAG 
#define   FLAG_F		FLAG,7 ;  FLAG 

COUNT_TIMER_0		EQU	0x78
COUNT_TIMER_0_ST	EQU	0x79
COUNT_TIMER_1_ST	EQU	0x7A

NUMBER_DEBUG_MODE	EQU     0x7B	

cicle				EQU	0x7C
w_temp				EQU	0x7D			; variable used for context saving
status_temp			EQU	0x7E			; variable used for context saving
pclath_temp			EQU	0x7F			; variable used for context saving

;**********************************************************************
;FREE RAM
;		EQU     0x20
;		EQU     0x21
;		EQU     0x22
;		EQU     0x23



SAVE_COUNT_TIMER_1		EQU     0x2D
SAVE_TMR1H				EQU     0x2E
SAVE_TMR1L				EQU     0x2F



;NOT CLEAR _END

TEMP	  		EQU	0x30
TEMP1	  		EQU	0x31
TEMP2	  		EQU	0x32
TEMP3	  		EQU	0x33
TEMP4	  		EQU	0x34

ee_addr			EQU     0x35
ee_data			EQU     0x36
errors			EQU     0x37

MODE			EQU     0x38

MY_POWER_BAT	EQU     0x39

; norm .45-.44 . 47 -3.3V in
POWER_BAT_LOW	EQU 	0x3A


DELAY_COUNTER_1			EQU     0x3B
DELAY_COUNTER_2			EQU     0x3C
DELAY_COUNTER_3			EQU     0x3D



bin1			EQU	0x3E
bin2			EQU	0x3F
bcd1			EQU	0x40
bcd2			EQU	0x41
bcd3			EQU	0x42
ctr				EQU	0x43

BARGB0			EQU	0x44
BARGB1			EQU	0x45

AARGB0			EQU	0x46
AARGB1			EQU	0x47
AARGB2			EQU	0x48

LOOPCOUNT		EQU	0x49

AARGB3		EQU	0x4A
REMB0		EQU	0x4B
REMB1		EQU	0x4C


COUNT_PRESS_KEY			EQU     0x4D
COUNT_PRESS_KEY_ST		EQU     0x4E
COUNT_PRESS_KEY_2		EQU     0x4F

COUNT_OFF_ML			EQU     0x50
COUNT_OFF_ST			EQU     0x51




CLR_MODE_FRQ_OPORA_ML		EQU     0x52
CLR_MODE_FRQ_OPORA_ST		EQU     0x53
CLR_MODE_FRQ_OPORA_UP		EQU     0x54



CLR_NOMINAL_OPORA_ML		EQU     0x55
CLR_NOMINAL_OPORA_ST		EQU     0x56


Dividend		EQU     0x57
Dividend1		EQU     0x58
Dividend2		EQU     0x59
Dividend3		EQU     0x5A
Dividend4		EQU     0x5B
Dividend5		EQU     0x5C
Dividend6		EQU     0x5D
Dividend7		EQU     0x5E
bcd4			EQU		0x5F


;CLR_KORRECTOR_KOF_ML		EQU     0x
;CLR_KORRECTOR_KOF_ST		EQU     0x






COUNT_PRESS_KEY_ZERRO		EQU     0x6C 

CLR_ZERRO_ML		EQU     0x6D  ; КОРРЕКЦИЯ ЩУПОВ, ОЧИЩАЕТСЯ ПРИ СМЕНЕ РЕЖИМА
CLR_ZERRO_ST		EQU     0x6E
CLR_ZERRO_UP		EQU     0x6F

;************* IN / OUT *****************

#define   SEG_A		PORTB,7
#define   SEG_B		PORTC,4
#define   SEG_C		PORTB,2
#define   SEG_D		PORTB,4
#define   SEG_E		PORTB,5
#define   SEG_F		PORTC,7
#define   SEG_G		PORTB,1

#define   SEG_H		PORTB,3

#define   SEG_1		PORTB,6
#define   SEG_2		PORTC,6
#define   SEG_3		PORTC,5
#define   SEG_4		PORTB,0


#define   KEY_1		PORTE,3
#define   KEY_2		PORTA,2


#define   POWER_ON	PORTA,3

#define   L_MODE_ON		PORTC,2
#define   C_MODE_ON		PORTC,1



;***** ЗАДАНИЕ АДРЕСОВ EEPROMa 

ADDR_MODE_EE    					EQU 0x00 ; 0 -C+ESR 1-ESR 2-C
ADDR_POWER_BAT_LOW_EE				EQU     0x01

ADDR_C_MODE_FRQ_OPORA_ML_EE		EQU     0x02
ADDR_C_MODE_FRQ_OPORA_ST_EE		EQU     0x03
ADDR_C_MODE_FRQ_OPORA_UP_EE		EQU     0x04

ADDR_L_MODE_FRQ_OPORA_ML_EE		EQU     0x05
ADDR_L_MODE_FRQ_OPORA_ST_EE		EQU     0x06
ADDR_L_MODE_FRQ_OPORA_UP_EE		EQU     0x07
;
ADDR_R_MODE_FRQ_OPORA_ML_EE		EQU     0x08
ADDR_R_MODE_FRQ_OPORA_ST_EE		EQU     0x09
ADDR_R_MODE_FRQ_OPORA_UP_EE		EQU     0x0A


ADDR_C_NOMINAL_OPORA_ML_EE		EQU     0x0B
ADDR_C_NOMINAL_OPORA_ST_EE		EQU     0x0C

ADDR_L_NOMINAL_OPORA_ML_EE		EQU     0x0D
ADDR_L_NOMINAL_OPORA_ST_EE		EQU     0x0E

ADDR_R_NOMINAL_OPORA_ML_EE		EQU     0x0F
ADDR_R_NOMINAL_OPORA_ST_EE		EQU     0x10




ADDR_C_KORRECTOR_KOF_ML_EE		EQU     0x11
ADDR_C_KORRECTOR_KOF_ST_EE		EQU     0x12


ADDR_L_KORRECTOR_KOF_ML_EE		EQU     0x13
ADDR_L_KORRECTOR_KOF_ST_EE		EQU     0x14


ADDR_R_KORRECTOR_KOF_ML_EE		EQU     0x15
ADDR_R_KORRECTOR_KOF_ST_EE		EQU     0x16

;ADDR__EE		EQU     0x0D
;ADDR__EE  		EQU     0x0E
;ADDR__EE  		EQU     0x0F




;   МАКРОСЫ             ; -----------------------------------------------
;***************
magic   macro                           ;"магическая" последовательность записи в EEPROM
	movlw   55H            
	movwf   EECON2^80H
	movlw   0AAH
	movwf   EECON2^80H
	endm
;***************
BANK_0   macro		;------------------------------------------;
	BCF	STATUS,RP0
	endm
;***************
BANK_1   macro		;------------------------------------------;
	BSF	STATUS,RP0
	endm
;***************	
	
;***************
BANK0   macro		;------------------------------------------;
	BCF	STATUS,RP1
	BCF	STATUS,RP0
	endm
;***************
BANK1   macro		;------------------------------------------;
	BCF	STATUS,RP1
	BSF	STATUS,RP0
	endm
;***************
BANK2   macro		;------------------------------------------;
	BSF	STATUS,RP1
	BCF	STATUS,RP0
	endm
;***************
BANK3   macro		;------------------------------------------;
	BSF	STATUS,RP1
	BSF	STATUS,RP0
	endm
;***************
;***************
IRQ_ON   	macro				;------------------------------------------;
				BSF	INTCON,GIE
			endm
;***************
;***************
IRQ_OFF   	macro				;------------------------------------------;
				BCF	INTCON,GIE
			endm
;**********************************************************************
;**********************************************************************
		ORG     0x000             ;  старт программы
	NOP
	NOP
	NOP
		ORG     0x003             ;  старт программы
		goto    START_RESET             ;  и сразу переходим на метку START

;**********************************************************************
		ORG     	0x004             ;  Сюда попадем если прерывание
		movwf   	w_temp            ; сохраним содержание регистра W 
		movf		STATUS,w          ; Переместите регистр статуса в регистр W
		movwf		status_temp       ; сохраним  содержание регистра СТАТУСА
		
		BANK0
		movf		PCLATH,w		; move pclath register into W register
		movwf		pclath_temp		; save off contents of PCLATH register
	
		PAGESEL		RETIRQ

		BANK0
; тута программа обработки прерываний
;**********************************************************************
		BTFSC		INTCON,T0IF
		GOTO		IRQ_TMR0


		BTFSC		PIR1,TMR1IF
		GOTO		IRQ_TMR1



		GOTO		RETIRQ
;**********************************************************************	
IRQ_TMR0		;TMR0 CONNECT TO CLK/4 = 5 000 000 Hz   Prescaler  = 64
				; 	= 305 Hz
		BCF		INTCON,T0IF

; ТУТ ЗАПУСКАТЬ И ОСТАНАВЛИВАТЬ ТАЙМЕР ДЛЯ ПОДСЧЕТА ЧАСТОТЫ	
	
		
		BTFSS	FLAG_START_FCOUNT			
		GOTO	SKIP_FCOUNT
		

		BTFSC	FLAG_SKIP_CLEAR_TMR1
		GOTO	SKIP_CLR_FCOUNT	
	
		BTFSC	FLAG_FCOUNT_GO
		GOTO	SKIP_CLR_FCOUNT
	
	
		BCF		T1CON,TMR1ON	
		CLRF	COUNT_TIMER_1
		CLRF	COUNT_TIMER_1_ST		
		CLRF	COUNT_TIMER_0
		CLRF	COUNT_TIMER_0_ST
		CLRF	TMR1L
		CLRF	TMR1H				

		BSF		T1CON,TMR1ON		
SKIP_CLR_FCOUNT		
		BSF		FLAG_FCOUNT_GO		
		
		INCF	COUNT_TIMER_0,F
		BTFSC	STATUS,Z
		INCF	COUNT_TIMER_0_ST,F	
		
		
		BTFSC	FLAG_CALC_100MS
		GOTO	CALC_100MS
		
		MOVLW	.50		
		XORWF	COUNT_TIMER_0,W
		BTFSS	STATUS,Z
		GOTO	SKIP_FCOUNT	
		
		
		MOVLW	.1		
		XORWF	COUNT_TIMER_0_ST,W
		BTFSS	STATUS,Z
		GOTO	SKIP_FCOUNT	

		MOVLW	.0
WAITS_IR
		ADDLW	.1		
		BTFSS	STATUS,Z
		GOTO	WAITS_IR

		MOVLW	.0
WAITS_IR1
		ADDLW	.1		
		BTFSS	STATUS,Z
		GOTO	WAITS_IR1		
	
		MOVLW	.50
WAITS_IR2
		ADDLW	.1		
		BTFSS	STATUS,Z
		GOTO	WAITS_IR2			
		
		BCF		T1CON,TMR1ON		 ; TMR1ON = 1000 MS	
		BCF		FLAG_START_FCOUNT		
		BCF		FLAG_FCOUNT_GO	
		BCF		PIR1,TMR1IF
			
	
		GOTO	SKIP_FCOUNT


CALC_100MS
		
		MOVLW	.31		
		XORWF	COUNT_TIMER_0,W
		BTFSS	STATUS,Z
		GOTO	SKIP_FCOUNT	

		MOVLW	.0
WAITS_1IR
		ADDLW	.1		
		BTFSS	STATUS,Z
		GOTO	WAITS_1IR

		MOVLW	.0
WAITS_1IR1
		ADDLW	.1		
		BTFSS	STATUS,Z
		GOTO	WAITS_1IR1		
	
		MOVLW	.0
WAITS_1IR3
		ADDLW	.1		
		BTFSS	STATUS,Z
		GOTO	WAITS_1IR3

		MOVLW	.0
WAITS_1IR4
		ADDLW	.1		
		BTFSS	STATUS,Z
		GOTO	WAITS_1IR4		
	
		MOVLW	.0
WAITS_1IR5
		ADDLW	.1		
		BTFSS	STATUS,Z
		GOTO	WAITS_1IR5
		
		
		MOVLW	.0
WAITS_1IR6
		ADDLW	.1		
		BTFSS	STATUS,Z
		GOTO	WAITS_1IR6				
				
		MOVLW	.0
WAITS_1IR7
		ADDLW	.1		
		BTFSS	STATUS,Z
		GOTO	WAITS_1IR7		
	
		MOVLW	.0
WAITS_1IR8
		ADDLW	.1		
		BTFSS	STATUS,Z
		GOTO	WAITS_1IR8
	
		MOVLW	.186
WAITS_1IR2
		ADDLW	.1		
		BTFSS	STATUS,Z
		GOTO	WAITS_1IR2	
		
		NOP
		NOP
		NOP			
		NOP				
		
				
		BCF		T1CON,TMR1ON		 ; TMR1ON = 100 MS	
		BCF		FLAG_START_FCOUNT		
		BCF		FLAG_FCOUNT_GO		
		BCF		PIR1,TMR1IF
		GOTO	SKIP_FCOUNT	
		
SKIP_FCOUNT		

		INCF	COUNT_OFF_ML,F
		BTFSS	STATUS,Z	
		GOTO	IRQ_TMR0_1

		INCF	COUNT_OFF_ST,F
		MOVLW  	.250;  .120 ;= 100SEC
		XORWF	COUNT_OFF_ST,W
		BTFSS	STATUS,Z	
		GOTO	IRQ_TMR0_1	


		BCF		FLAG_LCD_ON
		BCF		POWER_ON		
		BCF		FLAG_DEBUG_MODE	


;		BsF 	SEG_1
;		BsF 	SEG_2
;		BsF 	SEG_3
;		BsF 	SEG_4
;
;		btfsc	FLAG_INVERT_INDIKATOR 
;		goto	IRQ_TMR0_1
;
;		BCF 	SEG_1
;		BCF 	SEG_2
;		BCF 	SEG_3
;		BCF 	SEG_4

		CALL	ON_OFF_SEG


;ОПРОС КНОПКИ
IRQ_TMR0_1

		BTFSS	KEY_2
		CLRF	COUNT_PRESS_KEY_ZERRO	

		BTFSS	KEY_2
		GOTO 	IRQ_TMR0_2
		
		INCFSZ	COUNT_PRESS_KEY_ZERRO,W
		INCF	COUNT_PRESS_KEY_ZERRO,F

		MOVLW	.10
		XORWF	COUNT_PRESS_KEY_ZERRO,W
		BTFSC	STATUS,Z	
		
		BSF		FLAG_PRESS_KEY_ZERRO_SHORT


		MOVLW	.250
		XORWF	COUNT_PRESS_KEY_ZERRO,W

		BTFSC	STATUS,Z	
		BSF		FLAG_PRESS_KEY_ZERRO_MID
		BTFSC	STATUS,Z	
		BSF		FLAG_PRESS_KEY_ZERRO_MID_1

IRQ_TMR0_2

		BTFSS	KEY_1
		GOTO	TESTING_END_1		

		CLRF	COUNT_OFF_ML
		CLRF	COUNT_OFF_ST

		
		INCFSZ	COUNT_PRESS_KEY,W ; УВЕЛИЧИМ ДО 255
		INCF	COUNT_PRESS_KEY,F

		INCF	COUNT_PRESS_KEY_2,F
		BTFSC	STATUS,Z	
		INCF	COUNT_PRESS_KEY_ST,F

		MOVLW	.15
		XORWF	COUNT_PRESS_KEY,W
		BTFSS	STATUS,Z	
		GOTO    OPROS_2
; КОРОТКОЕ НАЖАТЕ
		INCF	MODE,F	
		MOVLW	b'00000011'
		ANDWF	MODE,F		

		CLRF	CLR_ZERRO_ML
		CLRF	CLR_ZERRO_ST
		CLRF	CLR_ZERRO_UP

		BSF		FLAG_SAVE_MODE

		bsf		FLAG_NEW_MODE
		BTFSS	FLAG_DEBUG_MODE	;	ЕСЛИ СМЕНА РЕЖИМА - ТО ВЫЙТИ ИЗ ИЗМЕРЕНИЯ
		BCF		FLAG_START_FCOUNT


OPROS_2
		BTFSS	FLAG_DEBUG_MODE
		GOTO	OPROS_2A

		MOVLW	.250
		XORWF	COUNT_PRESS_KEY,W
		BTFSS	STATUS,Z	
		GOTO    OPROS_3

		INCF	NUMBER_DEBUG_MODE,F
			
		MOVLW	.10
		XORWF	NUMBER_DEBUG_MODE,W
		BTFSC	STATUS,Z
		GOTO	OPROS_2A_RUN

		GOTO    TESTING_END

OPROS_2A
		MOVLW	.250
		XORWF	COUNT_PRESS_KEY,W
		BTFSS	STATUS,Z	
		GOTO    OPROS_3

; СРЕДНЕЕ НАЖАТЕ
OPROS_2A_RUN
		BCF		FLAG_LCD_ON
		BCF		POWER_ON
		
;		BsF 	SEG_1
;		BsF 	SEG_2
;		BsF 	SEG_3
;		BsF 	SEG_4
;		
;		btfsc	FLAG_INVERT_INDIKATOR 
;		goto	inv_1
;
;		BCF 	SEG_1
;		BCF 	SEG_2
;		BCF 	SEG_3
;		BCF 	SEG_4
;inv_1

		CALL	ON_OFF_SEG


		DECF	MODE,F	
		MOVLW	b'00000011'
		ANDWF	MODE,F		

		BSF		FLAG_SAVE_MODE


		GOTO    TESTING_END

OPROS_3
		MOVLW	.10
		XORWF	COUNT_PRESS_KEY_ST,W
		BTFSS	STATUS,Z	
		GOTO    OPROS_4
		
		BSF		FLAG_DEBUG_MODE
		BSF		FLAG_LCD_ON

OPROS_4

		MOVLW	.11
		XORWF	COUNT_PRESS_KEY_ST,W
		BTFSS	STATUS,Z	
		GOTO    TESTING_END
		
		BCF		FLAG_DEBUG_MODE
		
		BCF		FLAG_LCD_ON
		BCF		POWER_ON
	

;		BsF 	SEG_1
;		BsF 	SEG_2
;		BsF 	SEG_3
;		BsF 	SEG_4
;
;		btfsc	FLAG_INVERT_INDIKATOR 
;		goto	inv_2		
;
;		BCF 	SEG_1
;		BCF 	SEG_2
;		BCF 	SEG_3
;		BCF 	SEG_4
;inv_2

		CALL	ON_OFF_SEG


TESTING_END

		BTFSC	FLAG_LCD_ON
		CALL	LCD_WORK
		GOTO	RETIRQ	
TESTING_END_1
		clrf	COUNT_PRESS_KEY
		CLRF	COUNT_PRESS_KEY_2
		CLRF	COUNT_PRESS_KEY_ST

		GOTO	TESTING_END	


;**********************************************************************
IRQ_TMR1
; FRQ TMR1 = 2 000 000
	
		BCF		PIR1,TMR1IF ; =  32,768 mS
		
		INCF	COUNT_TIMER_1,F
		BTFSC	STATUS,Z
		INCF	COUNT_TIMER_1_ST,F


		GOTO	RETIRQ
;***********************************************************************			
;********************************
RETIRQ	
		movf		pclath_temp,w		; retrieve copy of PCLATH register
		movwf		PCLATH				; restore pre-isr PCLATH register contents	
		movf    	status_temp,w     	;  ВОССТАНОВИМ ВСЕ
		movwf		STATUS            	;  register contents
		swapf   	w_temp,f
		swapf   	w_temp,w          	; restore pre-isr W register contents
		retfie                    		; Bозврат из обработчика прерываний
;***************************************************************************************************
;***************************************************************************************************
ON_OFF_SEG
		BsF 	SEG_1
		BsF 	SEG_2
		BsF 	SEG_3
		BsF 	SEG_4

		btfsc	FLAG_INVERT_INDIKATOR 
		RETURN

		BCF 	SEG_1
		BCF 	SEG_2
		BCF 	SEG_3
		BCF 	SEG_4


	RETURN


;***************************************************************************************************

LCD_WORK
; ПОТУШИМ ВСЕ

		BTFSS	FLAG_INVERT_INDIKATOR
		GOTO	LCD_WORK_OA

		PAGESEL	LCD_WORK_OK	
		CALL	LCD_WORK_OK	^800
		PAGESEL	LCD_WORK_OA	
		RETURN

LCD_WORK_OA

		BCF 	SEG_1
		BCF 	SEG_2
		BCF 	SEG_3
		BCF 	SEG_4

		BSF		SEG_A
		BSF		SEG_B	
		BSF		SEG_C	
		BSF		SEG_D	
		BSF		SEG_E	
		BSF		SEG_F	
		BSF		SEG_G	
		BSF		SEG_H	

; покажем индикатор  полностью за 4 проходa
; узнаем номер прохода
ST_LCD_ON		
		MOVF	cicle,W		; в W номер прохода
; табличное ветвление
		btfsc   STATUS,Z
		GOTO 	MCICLE1
		
		MOVLW	.1
		XORWF	cicle,W	
		btfsc   STATUS,Z
		GOTO 	MCICLE2
		
		MOVLW	.2
		XORWF	cicle,W	
		btfsc   STATUS,Z
		GOTO 	MCICLE3

		MOVLW	.3
		XORWF	cicle,W	
		btfsc   STATUS,Z
		GOTO 	MCICLE4

		clrf	cicle
		GOTO 	MCICLE1
MCICLE1
		BTFSS  	IND_1,7
		BCF		SEG_A
		BTFSS  	IND_1,6
		BCF		SEG_B	
		BTFSS  	IND_1,5
		BCF		SEG_C	
		BTFSS  	IND_1,4
		BCF		SEG_D	
		BTFSS  	IND_1,3
		BCF		SEG_E	
		BTFSS  	IND_1,2
		BCF		SEG_F	
		BTFSS  	IND_1,1
		BCF		SEG_G	
		BTFSS  	IND_1,0
		BCF		SEG_H	
; зажжем этот разряд
		BSF 	SEG_1
		NOP
		goto    ENDIND
MCICLE2
		BTFSS  	IND_2,7
		BCF		SEG_A
		BTFSS  	IND_2,6
		BCF		SEG_B	
		BTFSS  	IND_2,5
		BCF		SEG_C	
		BTFSS  	IND_2,4
		BCF		SEG_D	
		BTFSS  	IND_2,3
		BCF		SEG_E	
		BTFSS  	IND_2,2
		BCF		SEG_F	
		BTFSS  	IND_2,1
		BCF		SEG_G	
		BTFSS  	IND_2,0
		BCF		SEG_H	
; зажжем этот разряд
		BSF 	SEG_2
		NOP
		goto    ENDIND
MCICLE3
		BTFSS  	IND_3,7
		BCF		SEG_A
		BTFSS  	IND_3,6
		BCF		SEG_B	
		BTFSS  	IND_3,5
		BCF		SEG_C	
		BTFSS  	IND_3,4
		BCF		SEG_D	
		BTFSS  	IND_3,3
		BCF		SEG_E	
		BTFSS  	IND_3,2
		BCF		SEG_F	
		BTFSS  	IND_3,1
		BCF		SEG_G	
		BTFSS  	IND_3,0
		BCF		SEG_H	
; зажжем этот разряд
		BSF 	SEG_3
		NOP
		goto    ENDIND
MCICLE4
		BTFSS  	IND_4,7
		BCF		SEG_A
		BTFSS  	IND_4,6
		BCF		SEG_B	
		BTFSS  	IND_4,5
		BCF		SEG_C	
		BTFSS  	IND_4,4
		BCF		SEG_D	
		BTFSS  	IND_4,3
		BCF		SEG_E	
		BTFSS  	IND_4,2
		BCF		SEG_F	
		BTFSS  	IND_4,1
		BCF		SEG_G	
		BTFSS  	IND_4,0
		BCF		SEG_H	
		
		
		BTFSS	FLAG_FLASH_DP4
		GOTO	MCICLE4_1
		
		BCF		SEG_H
		BTFSS	COUNT_OFF_ML,7
		BSF		SEG_H		
		
		
MCICLE4_1		
; зажжем этот разряд
		BSF 	SEG_4
		NOP
		goto    ENDIND	
ENDIND

		INCF	cicle,F 	; Счетчик проходов увеличим	
		MOVLW	.4
		XORWF	cicle,W
		BTFSC	STATUS,Z
		CLRF	cicle
;********************************		
;	На индикаторе состояние рама
;********************************
		RETURN

;	ORG			0x160
;*********************************************************************;
;=================== LCD TABLE ==================================
; Подпрограмма вывода на семисегментный индикатор
;порт В0 -А ........ В7 - Н
;Исходные данные: В регистре W число от 0 до 7F
;Выходные данные: В регистре W код для индикатора
LCDTable

;            retlw     ; ABCDEFGH = '8,'	hXX    
	  ADDLW		.0
			BTFSC	STATUS,Z	  
            retlw      b'00000011' ; 0	  
	  ADDLW		.255 				
			BTFSC	STATUS,Z	  
            retlw      b'10011111' ; 1
	  ADDLW		.255 				
			BTFSC	STATUS,Z	  
            retlw      b'00100101' ; 2
	  ADDLW		.255 				
			BTFSC	STATUS,Z	  
            retlw      b'00001101' ; 3
	  ADDLW		.255 				
			BTFSC	STATUS,Z	  
            retlw      b'10011001' ; 4
	  ADDLW		.255 				
			BTFSC	STATUS,Z	  
            retlw      b'01001001' ; 5
	  ADDLW		.255 				
			BTFSC	STATUS,Z	  
            retlw      b'01000001' ; 6
	  ADDLW		.255 				
			BTFSC	STATUS,Z	  
            retlw      b'00011111' ; 7
	  ADDLW		.255 				
			BTFSC	STATUS,Z	  
            retlw      b'00000001' ; 8
	  ADDLW		.255 				
			BTFSC	STATUS,Z	  
            retlw      b'00001001' ; 9
	  ADDLW		.255 				
			BTFSC	STATUS,Z	  
            retlw      b'00010001' ; A
	  ADDLW		.255 				
			BTFSC	STATUS,Z	  
            retlw      b'11000001' ; B
	  ADDLW		.255 				
			BTFSC	STATUS,Z	  
            retlw      b'01100011' ; C
	  ADDLW		.255 				
			BTFSC	STATUS,Z	  
            retlw      b'10000101' ; D
	  ADDLW		.255 				
			BTFSC	STATUS,Z	  
            retlw      b'01100001' ; E
	  ADDLW		.255 				
			BTFSC	STATUS,Z	  
            retlw      b'01110001' ; F
            
            retlw      b'00000011' ; 0	             
;***************************************************************************************************




;***************************************************************************************************
;***************************************************************************************************
; Начало нашей программы
START_RESET

START
		PAGESEL		_INIT_CPU	
		CALL 		_INIT_CPU^800	
		CALL		TEST_INDIKATOR^800
		PAGESEL		START


		CALL	Delay_1S
		CALL	Delay_1S

;INITS	POWER LEVEL

		PAGESEL		LOAD_POWER_BAT	
		CALL 		LOAD_POWER_BAT^800	
		PAGESEL		START


		MOVLW	0x20
		XORWF	POWER_BAT_LOW,W
		BTFSS	STATUS,Z
		GOTO	GET_BAT_POWER


		MOVLW 	.20
		CALL	Delay_xx01S


		BANK1 					; Select Bank 1
		MOVLW	b'00000000'; 	
		MOVWF	ADCON1^80		
		BANK0	

		MOVLW	b'10111101'
		MOVWF	ADCON0			; LEFT, Fosc/32, CH 06V  , ADC EN        
		
		MOVLW 	.1
		CALL	Delay_XXXmS
		
		BSF		ADCON0,GO_DONE	; START DAC
WAIT_CHVR6_DAC1
		BTFSC	ADCON0,GO_DONE
		GOTO	WAIT_CHVR6_DAC1	
							; DAC-OK
		MOVF	ADRESH,W
		MOVWF	MY_POWER_BAT
		
		MOVWF	POWER_BAT_LOW

		INCF	POWER_BAT_LOW,F
		INCF	POWER_BAT_LOW,F
		INCF	POWER_BAT_LOW,F
		
		PAGESEL		SAVE_POWER_BAT_LOW	
		CALL 		SAVE_POWER_BAT_LOW^800	
		PAGESEL		START


		GOTO	TESTS_POW

; Меряем питание
GET_BAT_POWER


		BANK1 					; Select Bank 1
		MOVLW	b'00000000'; 	
		MOVWF	ADCON1^80		
		BANK0	

		MOVLW	b'10111101'
		MOVWF	ADCON0			; LEFT, Fosc/32, CH 06V  , ADC EN        
		
		MOVLW 	.1
		CALL	Delay_XXXmS
		
		BSF		ADCON0,GO_DONE	; START DAC
WAIT_CHVR6_DAC
		BTFSC	ADCON0,GO_DONE
		GOTO	WAIT_CHVR6_DAC	
							; DAC-OK
		MOVF	ADRESH,W
		MOVWF	MY_POWER_BAT

;*************************** 
;;***************************
;;ТЕСТОВО ПОКАЖЕМ ПИТАНИЕ
;		
;		MOVWF	POWER_LEVEL
;		CALL	POWER_TO_LCD
;		CALL	Delay_100mS	
;		GOTO	GET_BAT_POWER
;;***************************
;***************************
TESTS_POW
		MOVF	MY_POWER_BAT,W
		SUBWF	POWER_BAT_LOW,W

		BTFSC	STATUS,C
		GOTO	POWER_0K

POWER_LOW



		MOVLW	b'11000001' ; b
		MOVWF	IND_1

		MOVLW	b'11100000' ;t
		MOVWF	IND_2

		MOVLW	b'11100011' ;L
		MOVWF	IND_3

		MOVLW	b'11000101';o
		MOVWF	IND_4

		MOVLW 	.30
		CALL	Delay_xx01S



		btfss	KEY_2	
		GOTO	POWER_0K


POWER_OFF
; POWER OFF ************
		BCF		FLAG_LCD_ON	
		BCF			POWER_ON


		
;		BCF 	SEG_1
;		BCF 	SEG_2
;		BCF 	SEG_3
;		BCF 	SEG_4
;				
;		BTFSS	FLAG_INVERT_INDIKATOR 
;		GOTO	WAIT_OFF_BAT
;		BSF 	SEG_1
;		BSF 	SEG_2
;		BSF 	SEG_3
;		BSF 	SEG_4

		CALL	ON_OFF_SEG


WAIT_OFF_BAT
		GOTO	WAIT_OFF_BAT
; POWER OFF ************

POWER_0K
;*****************************************************************
; ВОССТАНОВИМ КОНСТАНТЫ


		PAGESEL		LOAD_CONSTANT	
		CALL 		LOAD_CONSTANT^800	
		PAGESEL		START


		CLRF	CLR_ZERRO_ML
		CLRF	CLR_ZERRO_ST
		CLRF	CLR_ZERRO_UP

		bcf	   FLAG_PRESS_KEY_ZERRO_MID		
		bcf	   FLAG_PRESS_KEY_ZERRO_SHORT	
		bcf	   FLAG_PRESS_KEY_ZERRO_MID_1 	
		bcf	   FLAG_NEW_MODE		



;*****************************************************************************
;*****************************************************************************
;*****************************************************************************
;*****************************************************************************
;*****************************************************************************
;*****************************************************************************
;*****************************************************************************
;*****************************************************************************	
BEGIN
;		BTFSS	FLAG_SAVE_MODE	
;		GOTO	BEGIN_A
;
;		PAGESEL		SAVE_MODE_EE	
;		CALL 		SAVE_MODE_EE^800	
;		PAGESEL		START
;
;BEGIN_A

;**************
;;;ТЕСТОВО ПОКАЖЕМ 
;		MOVF	MODE,W		
;		MOVWF	POWER_LEVEL
;		CALL	POWER_TO_LCD
;		CALL	Delay_100mS	
;*************
		BTFSS	FLAG_DEBUG_MODE
		GOTO	BEGIN1
		GOTO	DEBUG_MODE
BEGIN1

		BTFSS			POWER_ON
		GOTO	BEGIN

		MOVF	MODE,W		
		BTFSS	STATUS,Z
		GOTO	BEGIN2
	
		CALL	Delay_100mS	
		CALL	F_MODE

		GOTO	BEGIN
BEGIN2
		DECF	MODE,W	
		BTFSS	STATUS,Z
		GOTO	BEGIN3

		CALL	Delay_100mS	
		CALL	L_MODE
		GOTO	BEGIN
BEGIN3

		MOVLW	.2
		SUBWF	MODE,W	
		BTFSS	STATUS,Z
		GOTO	BEGIN4

		CALL	Delay_100mS	
		CALL	C_MODE
		GOTO	BEGIN

BEGIN4

		CALL	Delay_100mS	
		CALL	R_MODE
		GOTO	BEGIN
;*****************************************************************************
;*****************************************************************************
F_MODE
		BTFSC		FLAG_MODE_F
		GOTO		F_MODE_START

		BSF		FLAG_MODE_F
		BCF		FLAG_MODE_L
		BCF		FLAG_MODE_C
		BCF		FLAG_MODE_R

		MOVLW	b'01110001' ; F
		MOVWF	IND_1

		CALL	SEND_SET

		PAGESEL		SET_TO_F_MODE	
		CALL 		SET_TO_F_MODE^800	
		PAGESEL		START


	MOVLW	.250
	CALL	Delay_XXXmS	
	MOVLW	.250
	CALL	Delay_XXXmS	
	MOVLW	.250
	CALL	Delay_XXXmS	


		BTFSS	FLAG_SAVE_MODE	
		GOTO	BEGIN_A

		PAGESEL		SAVE_MODE_EE	
		CALL 		SAVE_MODE_EE^800	
		PAGESEL		START

BEGIN_A


	BCF		FLAG_PRESS_KEY_ZERRO_MID_1
	BCF		FLAG_PRESS_KEY_ZERRO_MID
;--------------------------------------------------------------
F_MODE_START
	BTFSS		FLAG_NEW_MODE	
	GOTO		F_MODE_START_A
	BCF			FLAG_NEW_MODE
	RETURN

F_MODE_START_A
	BCF		FLAG_SKIP_CLEAR_TMR1

;	BSF		FLAG_CALC_100MS  ; Hz*10

	BCF		FLAG_CALC_100MS	 ; Hz
	BSF		FLAG_START_FCOUNT
; измеритель запускается в прерывании  100 или 1000 мс
WAIT_COUNT_F	

	BTFSC		FLAG_START_FCOUNT	
	GOTO		WAIT_COUNT_F	
; ЧАСТОТА =  COUNT_TIMER_1_ST:COUNT_TIMER_1:TMR1H:TMR1L	
;270F = 9999 HZ
;-------------------------------------------------------------
F_MODE_CALC
	MOVF	COUNT_TIMER_1_ST,W
	BTFSS	STATUS,Z
	GOTO	F16_MHZ

	MOVF	COUNT_TIMER_1,W
	MOVWF	AARGB0
	MOVF	TMR1H,W
	MOVWF	AARGB1	
	MOVF	TMR1L,W
	MOVWF	AARGB2
F_MODE_CALC_A; ( AARGB0:AARGB1:AARGB2)
	CALL	TEST_UP_9999_AARGB0_1
	ADDLW	.0
	BTFSC	STATUS,Z
	GOTO	SKIP_F_HZ

	CALL	TWO_BYTE_TO_LCD_AARGB1_2 ;(AARGB1:AARGB2)
	BCF		FLAG_FLASH_DP4	

	RETURN
;********************************	

SKIP_F_HZ	
	CALL	F_DIV_10_TMR

	CALL	TEST_UP_9999_AARGB0_1
	ADDLW	.0
	BTFSC	STATUS,Z
	GOTO	SKIP_KF_HZ

	CALL	TWO_BYTE_TO_LCD_AARGB1_2 ;(AARGB1:AARGB2)
	BCF		IND_2,0	
	BSF		FLAG_FLASH_DP4

	RETURN
;*************
SKIP_KF_HZ
	CALL	F_DIV_10

	CALL	TEST_UP_9999_AARGB0_1
	ADDLW	.0
	BTFSC	STATUS,Z
	GOTO	SKIP_K1F_HZ

	CALL	TWO_BYTE_TO_LCD_AARGB1_2 ;(AARGB1:AARGB2)
	BCF		IND_3,0	
	BSF		FLAG_FLASH_DP4

	RETURN
;*************************************
SKIP_K1F_HZ
	CALL	F_DIV_10

	CALL	TEST_UP_9999_AARGB0_1
	ADDLW	.0
	BTFSC	STATUS,Z
	GOTO	SKIP_K2F_HZ

	CALL	TWO_BYTE_TO_LCD_AARGB1_2 ;(AARGB1:AARGB2)
	BSF		FLAG_FLASH_DP4

	RETURN
;***************************************
SKIP_K2F_HZ
	CALL	F_DIV_10
;AARGB0:AARGB1:AARGB2	
	MOVF	AARGB1,W
	MOVWF	bin1	
	MOVF	AARGB2,W
	MOVWF	bin2
	
	CALL	TWO_BYTE_TO_LCD	
	BCF		IND_2,0	
	BCF		IND_4,0		
	BCF		FLAG_FLASH_DP4

	RETURN
F16_MHZ	
	MOVF	COUNT_TIMER_1,W
	MOVWF	AARGB0
	MOVF	TMR1H,W
	MOVWF	AARGB1	
	MOVF	TMR1L,W
	MOVWF	AARGB2
	
	RRF		COUNT_TIMER_1_ST,F  ; /2
	RRF		AARGB0,F	
	RRF		AARGB1,F	
	RRF		AARGB2,F			
		
		MOVLW	0xC3
		MOVWF	BARGB0
		MOVLW	0x50
		MOVWF	BARGB1

		PAGESEL		FXD2416U	
		CALL		FXD2416U^800	
		PAGESEL		F_MODE_CALC


	CALL	TWO_BYTE_TO_LCD	
	BCF		IND_2,0	
	BCF		IND_4,0		
	BCF		FLAG_FLASH_DP4

	RETURN
;*****************************************************************************
F_DIV_10_TMR
;   Dividend - AARGB0:AARGB1:AARGB2 (0 - most significant!)
;   Divisor  - BARGB0:BARGB1
;Temporary:
;   Counter  - LOOPCOUNT
;   Remainder- REMB0:REMB1
;Output:
;   Quotient - AARGB0:AARGB1:AARGB2
		MOVF	COUNT_TIMER_1,W
		MOVWF	AARGB0
		MOVF	TMR1H,W
		MOVWF	AARGB1
		MOVF	TMR1L,W
		MOVWF	AARGB2
		
F_DIV_10		
		CLRF	BARGB0
		MOVLW	.10
		MOVWF	BARGB1
		PAGESEL		FXD2416U	
		CALL		FXD2416U^800	
		PAGESEL		F_MODE_CALC
		RETURN
;*****************************************************************************
TEST_UP_9999_AARGB0_1

	MOVF	AARGB0,W	
	BTFSS	STATUS,Z
	RETLW	.0 ; OVERLOAD
	
	MOVLW	0x27
	SUBWF	AARGB1,W 
	BTFSC	STATUS,Z ; =27 00	
	GOTO	TEST_UP_9999_AARGB0_1_A	

	BTFSC	STATUS,C ; > 27 00
	RETLW	.0	
	
	RETLW	.1
	
TEST_UP_9999_AARGB0_1_A	
	MOVLW	0x10
	SUBWF	AARGB2,W 
	BTFSC	STATUS,C ; >= 2710
	RETLW	.0		

	RETLW	.1


;*****************************************************************************
C_MODE
		BTFSC		FLAG_MODE_C
		GOTO		C_MODE_START

		BSF		FLAG_MODE_C

		BCF		FLAG_MODE_F
		BCF		FLAG_MODE_L
		BCF		FLAG_MODE_R

		MOVLW	b'01100011' ; C
		MOVWF	IND_1

		CALL	SEND_SET
;-------------------------------------------------------------

		PAGESEL		SET_TO_C_MODE 	
		CALL 		SET_TO_C_MODE ^800	
		PAGESEL		START


	MOVLW	.250
	CALL	Delay_XXXmS	
	MOVLW	.250
	CALL	Delay_XXXmS	
	MOVLW	.250
	CALL	Delay_XXXmS	


		BTFSS	FLAG_SAVE_MODE	
		GOTO	BEGIN_AA

		PAGESEL		SAVE_MODE_EE	
		CALL 		SAVE_MODE_EE^800	
		PAGESEL		START

BEGIN_AA


	BCF		FLAG_PRESS_KEY_ZERRO_MID_1
	BCF		FLAG_PRESS_KEY_ZERRO_MID
;--------------------------------------------------------------
C_MODE_START
	BTFSS		FLAG_NEW_MODE	
	GOTO		C_MODE_START_A
	BCF			FLAG_NEW_MODE
	RETURN

C_MODE_START_A
	BCF		FLAG_SKIP_CLEAR_TMR1 ; ЕСЛИ МАЛО ТО МЕРЯТЬ ЕЩЕ СЕКУНДУ И ЕЩЕ УСТАНОВИВ ЭТОТ ФЛАГ	
;	BSF		FLAG_CALC_100MS  ; Hz*10
	BCF		FLAG_CALC_100MS	 ; Hz

	BSF		FLAG_START_FCOUNT
; измеритель запускается в прерывании  100 или 1000 мс
WAIT_COUNT_C	
	BTFSC		FLAG_START_FCOUNT	
	GOTO		WAIT_COUNT_C	
; ЧАСТОТА =  COUNT_TIMER_1_ST:COUNT_TIMER_1:TMR1H:TMR1L	
;270F = 9999 HZ
; ПОСЧИТАЛИ ЧАСТОТУ В СЧЕТЧИКИ.....

CALC_CAPISTOR

;***************************
; COUNT =  COUNT_TIMER_1_ST:COUNT_TIMER_1:TMR1H:TMR1L	
; FRQ_OPORA = CLR_MODE_FRQ_OPORA_UP:CLR_MODE_FRQ_OPORA_ST:CLR_MODE_FRQ_OPORA_ML

;	REZULT =  FRQ_OPORA / COUNT  - 1
;	REZULT =	REZULT ( * C_KORRECTOR_KOF  ????  )*  C_NOMINAL_OPORA
;***************************

; Dividend:Dividend1:Dividend2: , :Dividend3:Dividend4:Dividend5 / AARGB0:AARGB1:AARGB2= Dividend:Dividend1:Dividend2: , :Dividend3:Dividend4:Dividend5
;20.05.2011
	MOVF	COUNT_TIMER_1,W
	MOVWF	AARGB0
	MOVWF	SAVE_COUNT_TIMER_1 ; СОХРАНИМ КОПИЮ СЧЕТЧИКА ;20.05.2011

	MOVF	TMR1H,W
	MOVWF	AARGB1	
	MOVWF	SAVE_TMR1H;20.05.2011

	MOVF	TMR1L,W
	MOVWF	AARGB2
	MOVWF	SAVE_TMR1L;20.05.2011
;;************************************************

;;*************************************************
CALC_CAP_2

	MOVF	CLR_MODE_FRQ_OPORA_UP,W
	MOVWF	Dividend
	MOVF	CLR_MODE_FRQ_OPORA_ST,W
	MOVWF	Dividend1	
	MOVF	CLR_MODE_FRQ_OPORA_ML,W
	MOVWF	Dividend2
	CLRF	Dividend3
	CLRF	Dividend4
	CLRF	Dividend5

		PAGESEL		DIVIDE_48by24	
		CALL		DIVIDE_48by24^800	
		PAGESEL		CALC_CAPISTOR
		ADDLW	.0
		BTFSC	STATUS,Z
	GOTO	ERR_XX_0 ; НЕТ ОПОРНОЙ ЧАСТОТЫ ПРИ ИЗМЕРЕНИИ ИЛИ ОНА = 0 КЗ, ОЧЕНЬ  БОЛЬШАЯ ЕМКОСТЬ

        MOVF    Dividend,W
        IORWF   Dividend1,W
        IORWF   Dividend2,W

        BTFSs   STATUS,Z
		goto	SKIP_OTR3		

 ;Dividend:Dividend1:Dividend2: , :Dividend3:Dividend4:Dividend5
;ЧАСТОТА ПОСЛЕ ИЗМЕРЕНИЯ ВЫШЕ ОПОНОЙ - ОТРИЦАТЕЛЬНАЯ ВЕЛИЧИНА НОМИНАЛА
 
 ;Dividend:Dividend1:Dividend2: , :Dividend3:Dividend4:Dividend5
;20.05.2011

;>>>>>>>
;ТУТ КОПИЮ СЧЕТЧИКА В ОПОРНУЮ ЧАСТОТУ ПОМЕСТИТЬ
;>ЕСЛИ КНОПКУ "0" НАЖАЛИ

		BTFSS	FLAG_DEBUG_MODE
		CALL	SET_FRQ_OPORA_

		MOVLW	.1	
		MOVWF	Dividend2
		CLRF	Dividend3
		CLRF	Dividend4
		CLRF	Dividend5

		goto	SKIP_OTR3


        BTFSC   STATUS,Z
    		GOTO	ERR_XX_1	 ;	 ЧАСТОТА ПОСЛЕ ИЗМЕРЕНИЯ ВЫШЕ ОПОНОЙ - ОТРИЦАТЕЛЬНАЯ  ЕМКОСТЬ	 - INVALID / 1- XXXXXXXXXX
; REZULT = Dividend:Dividend1:Dividend2: , :Dividend3:Dividend4:Dividend5
;;****  
;      	MOVF    Dividend,W
;        IORWF   Dividend1,W
;        BTFSC   STATUS,Z
;  			GOTO	ERR_XX_3 ; МАЛА ИЗМЕРЕННАЯ ЧАСТОТА, СЛИШКОМ БОЛЬШАЯ ИНДУКТИВНОСТЬ
;;**** 
;820 uH * 255 =  209*209 =  43H max

; REZULT = Dividend2: , :Dividend3:Dividend4:Dividend5


SKIP_OTR3
; ТУТ ПРОВЕРИТЬ ДРОБНУЮ ЧАТЬ - ЕСЛИ БОЛЬШАЯ ТО УРАВНЯТЬ НА 1 И ПРОДОЛЖИТЬ
; -1
		MOVLW	.1
		SUBWF   Dividend2,F
		BTFSS	STATUS,C	
		SUBWF   Dividend1,F
		BTFSS	STATUS,C	
		DECF   	Dividend,F

;	REZULT =	REZULT ( * C_KORRECTOR_KOF  ????  )*  C_NOMINAL_OPORA
;mult_32_16:
; Dividend2:Dividend3: , :Dividend4:Dividend5 * bin1:bin2 -> Dividend:Dividend1:Dividend2:Dividend3: , : Dividend4:Dividend5  pF

        MOVF    Dividend,W
        BTFSS   STATUS,Z
	    GOTO	ERR_XX_3	 ;	 СЛИШКОМ БОЛЬШАЯ ЕМКОСТЬ

 ; Dividend1:Dividend2: , :Dividend3:Dividend4 ->  Dividend2:Dividend3: , :Dividend4:Dividend5
	MOVF	Dividend4,W
	MOVWF	Dividend5
	MOVF	Dividend3,W
	MOVWF	Dividend4
	MOVF	Dividend2,W
	MOVWF	Dividend3
	MOVF	Dividend1,W
	MOVWF	Dividend2

	MOVF	CLR_NOMINAL_OPORA_ST,W
	MOVWF	bin1
	MOVF	CLR_NOMINAL_OPORA_ML,W
	MOVWF	bin2


		PAGESEL		mult_32_16	
		CALL		mult_32_16^800	
		PAGESEL		CALC_CAPISTOR


;	C= Dividend:Dividend1:Dividend2:Dividend3: , : Dividend4:Dividend5  pF
;Dividend5 - DEL
		CALL	ZERRO_CORRECTOR

;ПРИВЕДЕМ ДРОБНУЮ ЧАСТЬ 
;	C= Dividend:Dividend1:Dividend2:Dividend3: , : Dividend4
 ; Dividend4:Dividend5  / 0x199A

;FXD2416U
;AARGB0:AARGB1:AARGB2 /  BARGB0:BARGB1 = AARGB0:AARGB1:AARGB2 OST = REMB0:REMB1

		CLRF	AARGB0
		CLRF	AARGB1

		MOVF	Dividend4,W
		MOVWF	AARGB2
		
		MOVLW	0x00	
		MOVWF	BARGB0
		MOVLW	.26
		MOVWF	BARGB1

		PAGESEL		FXD2416U	
		CALL		FXD2416U^800	
		PAGESEL		CALC_CAPISTOR

		MOVF	AARGB2,W
		MOVWF	Dividend4
;	C= Dividend:Dividend1:Dividend2:Dividend3: , : Dividend4 (Dividend4 - DEC 0-9)    pF
		GOTO	REZ_TO_IND_1

;*****************************************************************************	
ERR_XX_0;  ; НЕТ ОПОРНОЙ ЧАСТОТЫ ПРИ ИЗМЕРЕНИИ ИЛИ ОНА = 0 КЗ, ЕМКОСТЬ/ REZ /INDUCT

		BTFSC	FLAG_MODE_C
		MOVLW	b'11100101';c
		BTFSC	FLAG_MODE_R
		MOVLW	b'11110101' ;r
		BTFSC	FLAG_MODE_L
		MOVLW	b'11100011' ; L

		MOVWF	IND_1
		MOVLW	b'01100001' ; E
		MOVWF	IND_2
		MOVLW	b'11110101' ;r
		MOVWF	IND_3
		MOVLW	b'11110101' ;r
		MOVWF	IND_4

	RETURN	
;*****************************************************************************	
ERR_XX_1;	 ЧАСТОТА ПОСЛЕ ИЗМЕРЕНИЯ ВЫШЕ ОПОНОЙ - ОТРИЦАТЕЛЬНАЯ  ЕМКОСТЬ/ REZ /INDUCT

		BTFSC	FLAG_MODE_C
		MOVLW	b'11100101';c
		BTFSC	FLAG_MODE_R
		MOVLW	b'11110101' ;r
		BTFSC	FLAG_MODE_L
		MOVLW	b'11100011' ; L

		MOVWF	IND_1	

		MOVLW	b'11111101' ;-
		MOVWF	IND_2

	MOVLW	.0
	CALL		LCDTable
		MOVWF	IND_3
		MOVWF	IND_4

	RETURN	
;*****************************************************************************	
ERR_XX_3;	 СЛИШКОМ БОЛЬШАЯ ЕМКОСТЬ/ REZ /INDUCT
		BTFSC	FLAG_MODE_C
		MOVLW	b'11100101';c
		BTFSC	FLAG_MODE_R
		MOVLW	b'11110101' ;r
		BTFSC	FLAG_MODE_L
		MOVLW	b'11100011' ; L

		MOVWF	IND_1

		MOVLW	b'11111101' ;-
		MOVWF	IND_2

		MOVLW	b'11111101' ;-
		MOVWF	IND_3

		MOVLW	b'11111101';-
		MOVWF	IND_4

	RETURN	
;*****************************************************************************	




;*****************************************************************************
;*****************************************************************************
;*****************************************************************************
;*****************************************************************************
;*****************************************************************************
R_MODE
		BTFSC		FLAG_MODE_R
		GOTO		R_MODE_START
; ВЫПОЛНЯЕТСЯ 1 РАЗ ПРИ ВХОДЕ ВРЕЖИМ
		BSF		FLAG_MODE_R
		BCF		FLAG_MODE_F
		BCF		FLAG_MODE_L
		BCF		FLAG_MODE_C

		MOVLW	b'11110101'	; r
		MOVWF	IND_1
		CALL	SEND_SET

		PAGESEL		SET_TO_R_MODE	
		CALL 		SET_TO_R_MODE^800	; ТУТ И КОНСТАНТЫ ГРУЗЯТСЯ 1 RAZ
		PAGESEL		START
;-------------------------------------------------------------
	MOVLW	.250
	CALL	Delay_XXXmS	
	MOVLW	.250
	CALL	Delay_XXXmS	
	MOVLW	.250
	CALL	Delay_XXXmS	

		BTFSS	FLAG_SAVE_MODE	
		GOTO	BEGIN_AAA

		PAGESEL		SAVE_MODE_EE	
		CALL 		SAVE_MODE_EE^800	
		PAGESEL		START

BEGIN_AAA


	BCF		FLAG_PRESS_KEY_ZERRO_MID_1
	BCF		FLAG_PRESS_KEY_ZERRO_MID
;--------------------------------------------------------------
R_MODE_START
	BTFSS		FLAG_NEW_MODE	
	GOTO		R_MODE_START_A
	BCF			FLAG_NEW_MODE
	RETURN

R_MODE_START_A
	BCF		FLAG_SKIP_CLEAR_TMR1 ; ЕСЛИ МАЛО ТО МЕРЯТЬ ЕЩЕ СЕКУНДУ И ЕЩЕ УСТАНОВИВ ЭТОТ ФЛАГ	
;	BSF		FLAG_CALC_100MS  ; Hz*10
	BCF		FLAG_CALC_100MS	 ; Hz

	BSF		FLAG_START_FCOUNT
; измеритель запускается в прерывании  100 или 1000 мс
WAIT_COUNT_R	
	BTFSC		FLAG_START_FCOUNT	
	GOTO		WAIT_COUNT_R	
; ЧАСТОТА =  COUNT_TIMER_1_ST:COUNT_TIMER_1:TMR1H:TMR1L	
;270F = 9999 HZ
; ПОСЧИТАЛИ ЧАСТОТУ В СЧЕТЧИКИ.....

;	GOTO	F_MODE_CALC_A ( AARGB0:AARGB1:AARGB2)

CALC_REZISTOR
;***************************
; COUNT =  COUNT_TIMER_1_ST:COUNT_TIMER_1:TMR1H:TMR1L	
; FRQ_OPORA = CLR_MODE_FRQ_OPORA_UP:CLR_MODE_FRQ_OPORA_ST:CLR_MODE_FRQ_OPORA_ML

;	REZULT =  FRQ_OPORA / COUNT  - 1
;	REZULT =	REZULT ( * C_KORRECTOR_KOF  ????  )*  R_NOMINAL_OPORA
;***************************
; Dividend:Dividend1:Dividend2: , :Dividend3:Dividend4:Dividend5 / AARGB0:AARGB1:AARGB2
;     = Dividend:Dividend1:Dividend2: , :Dividend3:Dividend4:Dividend5

;20.05.2011
	MOVF	COUNT_TIMER_1,W
	MOVWF	AARGB0
	MOVWF	SAVE_COUNT_TIMER_1 ; СОХРАНИМ КОПИЮ СЧЕТЧИКА ;20.05.2011

	MOVF	TMR1H,W
	MOVWF	AARGB1	
	MOVWF	SAVE_TMR1H;20.05.2011

	MOVF	TMR1L,W
	MOVWF	AARGB2
	MOVWF	SAVE_TMR1L;20.05.2011

;;************************************************
CALC_REZ_2

	MOVF	CLR_MODE_FRQ_OPORA_UP,W
	MOVWF	Dividend
	MOVF	CLR_MODE_FRQ_OPORA_ST,W
	MOVWF	Dividend1	
	MOVF	CLR_MODE_FRQ_OPORA_ML,W
	MOVWF	Dividend2
	CLRF	Dividend3
	CLRF	Dividend4
	CLRF	Dividend5

		PAGESEL		DIVIDE_48by24	
		CALL		DIVIDE_48by24^800	
		PAGESEL		CALC_REZISTOR
		ADDLW	.0
		BTFSC	STATUS,Z
			GOTO	ERR_XX_0 ; НЕТ ОПОРНОЙ ЧАСТОТЫ ПРИ ИЗМЕРЕНИИ ИЛИ ОНА = 0 ОБРЫВ  ОЧЕНЬ  БОЛЬШOЙ РЕЗИСТОР

        MOVF    Dividend,W
        IORWF   Dividend1,W
        IORWF   Dividend2,W  ; Dividend:Dividend1:Dividend2: = 0 ????

        BTFSs   STATUS,Z
		goto	SKIP_OTR2	; ЕСЛИ ПОСЛЕ ДЕЛЕНИЯ >=1 ТО ВСЕ ХОРОШО

;ЧАСТОТА ПОСЛЕ ИЗМЕРЕНИЯ ВЫШЕ ОПОНОЙ - ОТРИЦАТЕЛЬНАЯ ВЕЛИЧИНА НОМИНАЛА
 
 ;Dividend:Dividend1:Dividend2: , :Dividend3:Dividend4:Dividend5
;20.05.2011

;>>>>>>>
;ТУТ КОПИЮ СЧЕТЧИКА В ОПОРНУЮ ЧАСТОТУ ПОМЕСТИТЬ
;>ЕСЛИ КНОПКУ "0" НАЖАЛИ

		BTFSS	FLAG_DEBUG_MODE
		CALL	SET_FRQ_OPORA_

		MOVLW	.1	
		MOVWF	Dividend2
		CLRF	Dividend3
		CLRF	Dividend4
		CLRF	Dividend5

		goto	SKIP_OTR2

	        BTFSC   STATUS,Z
    		GOTO	ERR_XX_1	 ;	 ЧАСТОТА ПОСЛЕ ИЗМЕРЕНИЯ ВЫШЕ ОПОНОЙ - ОТРИЦАТЕЛЬНАЯ  ЕМКОСТЬ	 - INVALID / 1- XXXXXXXXXX
; REZULT = Dividend:Dividend1:Dividend2: , :Dividend3:Dividend4:Dividend5
;;****  
;      		MOVF    Dividend,W
;        	IORWF   Dividend1,W
;       	 BTFSC   STATUS,Z
;  			GOTO	ERR_XX_3 ; МАЛА ИЗМЕРЕННАЯ ЧАСТОТА, СЛИШКОМ БОЛЬШАЯ ИНДУКТИВНОСТЬ
;;**** 
;820 uH * 255 =  209*209 =  43H max
; REZULT = Dividend2: , :Dividend3:Dividend4:Dividend5


SKIP_OTR2

; -1
		MOVLW	.1
		SUBWF   Dividend2,F
		BTFSS	STATUS,C	
		SUBWF   Dividend1,F
		BTFSS	STATUS,C	
		DECF   	Dividend,F



        MOVF    Dividend,W
        BTFSS   STATUS,Z
	    GOTO	ERR_XX_3	 ;	 ОЧЕНЬ  БОЛЬШOЙ РЕЗИСТОР (НЕ ВЛЕЗАЕТ В РАЗМЕР ЧИСЛА)

; REZULT     = Dividend1:Dividend2: , :Dividend3:Dividend4

;	REZULT =	REZULT * R_NOMINAL_OPORA
;mult_32_16:
; Dividend2:Dividend3: , :Dividend4:Dividend5 * bin1:bin2 -> Dividend:Dividend1:Dividend2:Dividend3: , : Dividend4:Dividend5  Om


; Dividend1:Dividend2: , :Dividend3:Dividend4 ->  Dividend2:Dividend3: , :Dividend4:Dividend5
	MOVF	Dividend4,W
	MOVWF	Dividend5
	MOVF	Dividend3,W
	MOVWF	Dividend4
	MOVF	Dividend2,W
	MOVWF	Dividend3
	MOVF	Dividend1,W
	MOVWF	Dividend2

	MOVF	CLR_NOMINAL_OPORA_ST,W
	MOVWF	bin1
	MOVF	CLR_NOMINAL_OPORA_ML,W
	MOVWF	bin2


; bcd1:bcd2:bcd3:bcd4  * Dividend4:Dividend5:Dividend6:Dividend7 = Dividend:Dividend1:Dividend2:Dividend3:   Dividend4:Dividend5:Dividend6:Dividend7
;		CALL		MULTIPLY_32x32	

		PAGESEL		mult_32_16	
		CALL		mult_32_16^800	
		PAGESEL		CALC_REZISTOR

;	R= Dividend:Dividend1:Dividend2:Dividend3: , : Dividend4:Dividend5  Om

;Dividend5 - DEL

		CALL	ZERRO_CORRECTOR
		GOTO	CALC_REZ_3
;****************************************
SET_FRQ_OPORA_
		BTFSS	FLAG_PRESS_KEY_ZERRO_MID_1
		RETURN

	BCF		FLAG_PRESS_KEY_ZERRO_MID_1
	MOVF	SAVE_COUNT_TIMER_1,W
	MOVWF	CLR_MODE_FRQ_OPORA_UP

	MOVF	SAVE_TMR1H,W
	MOVWF	CLR_MODE_FRQ_OPORA_ST

	MOVF	SAVE_TMR1L,W
	MOVWF	CLR_MODE_FRQ_OPORA_ML
		RETURN
;***************************
ZERRO_CORRECTOR


		BTFSC	FLAG_DEBUG_MODE
		RETURN



; ЕСЛИ НАЖАЛИ ОБНУЛЕНИЕ 
		BTFSS	FLAG_PRESS_KEY_ZERRO_MID
		GOTO	SKIP_SET_ZERRO_REZ

		BCF		FLAG_PRESS_KEY_ZERRO_MID
; ОБНУЛЯТЬ ТОЛЬКО ДЛЯ МАЛЫХ ЕМКОСТЕЙ < 65536 PF
        MOVF    Dividend,W
        IORWF   Dividend1,W
        BTFSS   STATUS,Z
		GOTO	SKIP_SET_ZERRO_REZ
;CLR_ZERRO_ML		  ; КОРРЕКЦИЯ ЩУПОВ, ОЧИЩАЕТСЯ ПРИ СМЕНЕ РЕЖИМА
;CLR_ZERRO_ST		
;CLR_ZERRO_UP
	MOVF	Dividend2,W
	MOVWF	CLR_ZERRO_UP
	MOVF	Dividend3,W
	MOVWF	CLR_ZERRO_ST
	MOVF	Dividend4,W
	MOVWF	CLR_ZERRO_ML

SKIP_SET_ZERRO_REZ
; Применим обнуление

;>>>> ТУТ ПРАВИЛЬНО ВЫЧЕСТЬ  24 BIT  
;Dividend:Dividend1:Dividend2:Dividend3:Dividend4 - CLR_ZERRO_UP:CLR_ZERRO_ST:CLR_ZERRO_ML
	MOVF	CLR_ZERRO_ML,W
	SUBWF	Dividend4,F
	BTFSC	STATUS,C
	GOTO	SUB_2_ST_REZ

		MOVLW		.1
		SUBWF	Dividend3,F
		BTFSC	STATUS,C
		GOTO	SUB_2_ST_REZ

		MOVLW		.1
		SUBWF	Dividend2,F
		BTFSC	STATUS,C
		GOTO	SUB_2_ST_REZ

		MOVLW		.1
		SUBWF	Dividend1,F
		BTFSC	STATUS,C
		GOTO	SUB_2_ST_REZ

		DECF	Dividend,F

SUB_2_ST_REZ

	MOVF	CLR_ZERRO_ST,W	
	SUBWF	Dividend3,F
	BTFSC	STATUS,C
	GOTO	SUB_3_ST_REZ

		MOVLW		.1
		SUBWF	Dividend2,F
		BTFSC	STATUS,C
		GOTO	SUB_2_ST_REZ

		MOVLW		.1
		SUBWF	Dividend1,F
		BTFSC	STATUS,C
		GOTO	SUB_2_ST_REZ

		DECF	Dividend,F

SUB_3_ST_REZ

	MOVF		CLR_ZERRO_UP,W
	SUBWF	Dividend2,F

		MOVLW	.0	
		BTFSS	STATUS,C
		MOVLW	.1	
		SUBWF	Dividend1,F

		MOVLW	.0	
		BTFSS	STATUS,C
		MOVLW	.1	
		SUBWF	Dividend,F

	BTFSS	Dividend,7
	GOTO	SKIP_CLEAR_REZ 
;*************
; ERROR SET TO NULL , CLEAR 
;	C= Dividend:Dividend1:Dividend2:Dividend3: , : Dividend4
	CLRF	Dividend	
	CLRF	Dividend1
	CLRF	Dividend2
	CLRF	Dividend3
	CLRF	Dividend4
SKIP_CLEAR_REZ 
;*************
		RETURN



CALC_REZ_3
;ПРИВЕДЕМ ДРОБНУЮ ЧАСТЬ 
;	R= Dividend:Dividend1:Dividend2:Dividend3: , : Dividend4
 ; Dividend4:Dividend5  / 0x199A

;FXD2416U
;AARGB0:AARGB1:AARGB2 /  BARGB0:BARGB1 = AARGB0:AARGB1:AARGB2 OST = REMB0:REMB1

		CLRF	AARGB0
		CLRF	AARGB1

		MOVF	Dividend4,W
		MOVWF	AARGB2
		
		MOVLW	0x00	
		MOVWF	BARGB0
		MOVLW	.26
		MOVWF	BARGB1

		PAGESEL		FXD2416U	
		CALL		FXD2416U^800	
		PAGESEL		CALC_CAPISTOR

		MOVF	AARGB2,W
		MOVWF	Dividend4
;	R= Dividend:Dividend1:Dividend2:Dividend3: , : Dividend4 (Dividend4 - DEC 0-9)    Om

REZ_TO_IND_1
; ПОКАЖЕМ REZISTOR
;	C= Dividend:Dividend1:Dividend2:Dividend3: , : Dividend4 (Dividend4 - DEC 0-9)    Om
; 0 - 999.9 Om = 0 - 3E7.9

        MOVF    Dividend,W
        IORWF   Dividend1,W
        BTFSS   STATUS,Z
		GOTO	REZ_TO_IND_2 ;> 65535 OM

		MOVLW	.3
		SUBWF	Dividend2,W
		BTFSC	STATUS,Z
		GOTO	REZ_TO_IND_1B ; = 3

		BTFSC	STATUS,C
		GOTO	REZ_TO_IND_2;	>=3
		
		GOTO	REZ_TO_IND_1A ; <3

REZ_TO_IND_1B
		MOVLW	0xE7
		SUBWF	Dividend3,W
		BTFSC	STATUS,C
		GOTO	REZ_TO_IND_2 ; > E7

REZ_TO_IND_1A
CAP_TO_IND_1A
;  Dividend2:Dividend3: , : Dividend4  - > НА ИНДИКАТОР....

;Входные данные: двоичное число в регистрах bin1, bin2. При этом bin1 - старший байт.		
	MOVF	Dividend2,W
	MOVWF	bin1	
	MOVF	Dividend3,W
	MOVWF	bin2
	CALL		bin2bcd 
;Выходные: единицы будут в младшей тетраде регистра bcd3, десятки в старшей регистра bcd3,
;сотни в младшей тетраде регистра bcd2, тысячи в старшей bcd2,
;десятки тысяч будут находиться в младшей тетраде регистра bcd1.
	MOVF		bcd2,W
	ANDLW		b'00001111'

	CALL		LCDTable
	MOVWF	IND_1	

	SWAPF		bcd3,W	
	ANDLW		b'00001111'
	CALL		LCDTable
	MOVWF	IND_2

	MOVF		bcd3,W		
	ANDLW		b'00001111'
	CALL		LCDTable
	MOVWF	IND_3

	MOVF		Dividend4,W	
	ANDLW		b'00001111'
	CALL		LCDTable
	MOVWF	IND_4

	BCF		IND_3,0	
	BCF		FLAG_FLASH_DP4	

	RETURN		
;*********************************************************************
;*****************************************************************************
TEST_UP_9999_Dividend2_3
       	MOVF    Dividend,W
        IORWF   Dividend1,W
        BTFSS  	STATUS,Z
			RETLW	.1

;	C= Dividend:Dividend1:Dividend2:Dividend3:   pF
; 999.9 - 9999 pF = 0 - 2710
		MOVLW	0x27
		SUBWF	Dividend2,W
		BTFSC	STATUS,Z
		GOTO	TEST_UP_9999_23

		BTFSC	STATUS,C
			RETLW	.1

			RETLW	.0
TEST_UP_9999_23
		MOVLW	0x10
		SUBWF	Dividend3,W
		BTFSC	STATUS,C
			RETLW	.1

			RETLW	.0


;*********************************************************************
REZ_TO_IND_2
;	R= Dividend:Dividend1:Dividend2:Dividend3: , : Dividend4 (Dividend4 - DEC 0-9)    Om
;	R= Dividend:Dividend1:Dividend2:Dividend3:   Om
; 999.9 - 9999 Om = 0 - 2710
		CALL	TEST_UP_9999_Dividend2_3

		ADDLW		.0
		BTFSS	STATUS,Z
		GOTO	REZ_TO_IND_3

	CALL	TWO_BYTE_TO_LCD_Dividend2_3

	BCF		FLAG_FLASH_DP4	
	RETURN	
;;**************************
;*****************************************************************************
TEST_UP_9999_Dividend4_5
        MOVF    Dividend2,W
        IORWF   Dividend3,W
        BTFSS   STATUS,Z
				RETLW	.1

		MOVLW	0x27
		SUBWF	Dividend4,W
		BTFSC	STATUS,Z
		GOTO	TEST_UP_9999_45

		BTFSC	STATUS,C
			RETLW	.1
			RETLW	.0

TEST_UP_9999_45
		MOVLW	0x10
		SUBWF	Dividend5,W
		BTFSC	STATUS,C
			RETLW	.1
			RETLW	.0
;*****************************************************************************
;**************************
REZ_TO_IND_3

;	R= Dividend:Dividend1:Dividend2:Dividend3:     Om


;	R= Dividend:Dividend1:Dividend2:Dividend3: /10    00.01 nF

;09.99 - 99.99 KR = 0 - 2710

; Dividend:Dividend1 ....Dividend5 / AARGB0:AARGB1:AARGB2 =  Dividend:Dividend1 ....Dividend5
;DIVIDE_48by24
	
	CLRF	Dividend4
	CLRF	Dividend5
	MOVLW	.10
	MOVWF	AARGB0
	CLRF	AARGB1
	CLRF	AARGB2
		PAGESEL		DIVIDE_48by24	
		CALL		DIVIDE_48by24^800	
		PAGESEL		CALC_CAPISTOR

;	R= Dividend2:Dividend3:Dividend4:Dividend5   00.01 KR
		CALL	TEST_UP_9999_Dividend4_5

		ADDLW		.0
		BTFSS	STATUS,Z
		GOTO	REZ_TO_IND_4


	CALL	TWO_BYTE_TO_LCD_Dividend4_5
	BCF		IND_2,0	
	BSF		FLAG_FLASH_DP4
	RETURN	
;**************************
;**************************
REZ_TO_IND_4

;	C= Dividend2:Dividend3:Dividend4:Dividend5 /10    000.1 nF

;099.9 - 999.9 nF = 0 - 2710

; Dividend:Dividend1 ....Dividend5 / AARGB0:AARGB1:AARGB2 =  Dividend:Dividend1 ....Dividend5
;DIVIDE_48by24

	CLRF	Dividend
	CLRF	Dividend1	
	MOVLW	.10
	MOVWF	AARGB2
	CLRF	AARGB1
	CLRF	AARGB0
		PAGESEL		DIVIDE_48by24	
		CALL		DIVIDE_48by24^800	
		PAGESEL		CALC_CAPISTOR

;	C= Dividend2:Dividend3:Dividend4:Dividend5   000.1 nF
		CALL	TEST_UP_9999_Dividend4_5

		ADDLW		.0
		BTFSS	STATUS,Z
		GOTO	REZ_TO_IND_5

	CALL	TWO_BYTE_TO_LCD_Dividend4_5
	BCF		IND_3,0	
	BSF		FLAG_FLASH_DP4
	RETURN	
;**************************
;**************************
REZ_TO_IND_5

;	C= Dividend2:Dividend3:Dividend4:Dividend5 /10    0000 nF

;0999 - 9999 nF = 0 - 2710

; Dividend:Dividend1 ....Dividend5 / AARGB0:AARGB1:AARGB2 =  Dividend:Dividend1 ....Dividend5
;DIVIDE_48by24

	CLRF	Dividend
	CLRF	Dividend1	
	MOVLW	.10
	MOVWF	AARGB2
	CLRF	AARGB1
	CLRF	AARGB0
		PAGESEL		DIVIDE_48by24	
		CALL		DIVIDE_48by24^800	
		PAGESEL		CALC_CAPISTOR
;	C= Dividend2:Dividend3:Dividend4:Dividend5   0001 nF
  		CALL	TEST_UP_9999_Dividend4_5

		ADDLW		.0
		BTFSS	STATUS,Z
		GOTO	REZ_TO_IND_6


	CALL	TWO_BYTE_TO_LCD_Dividend4_5
	BSF		FLAG_FLASH_DP4


	RETURN	
;**************************
;**************************
REZ_TO_IND_6
;	C= Dividend2:Dividend3:Dividend4:Dividend5 /10    00.00 uF
;09.99 - 99.99 uF = 0 - 2710

; Dividend:Dividend1 ....Dividend5 / AARGB0:AARGB1:AARGB2 =  Dividend:Dividend1 ....Dividend5
;DIVIDE_48by24

	CLRF	Dividend
	CLRF	Dividend1	
	MOVLW	.10
	MOVWF	AARGB2
	CLRF	AARGB1
	CLRF	AARGB0
		PAGESEL		DIVIDE_48by24	
		CALL		DIVIDE_48by24^800	
		PAGESEL		CALC_CAPISTOR

;	C= Dividend2:Dividend3:Dividend4:Dividend5   99.99 uF

		CALL	TEST_UP_9999_Dividend4_5

		ADDLW		.0
		BTFSS	STATUS,Z
		GOTO	REZ_TO_IND_7


	CALL	TWO_BYTE_TO_LCD_Dividend4_5
	BCF		IND_2,0	
	BCF		IND_4,0	
	BCF		FLAG_FLASH_DP4


	RETURN	
;**************************
REZ_TO_IND_7

;	C= Dividend2:Dividend3:Dividend4:Dividend5 /10    000.0 uF
;099.9 - 999.9 uF = 0 - 2710

; Dividend:Dividend1 ....Dividend5 / AARGB0:AARGB1:AARGB2 =  Dividend:Dividend1 ....Dividend5
;DIVIDE_48by24

	CLRF	Dividend
	CLRF	Dividend1	
	MOVLW	.10
	MOVWF	AARGB2
	CLRF	AARGB1
	CLRF	AARGB0
		PAGESEL		DIVIDE_48by24	
		CALL		DIVIDE_48by24^800	
		PAGESEL		CALC_CAPISTOR

;	C= Dividend2:Dividend3:Dividend4:Dividend5   99.99 uF

		CALL	TEST_UP_9999_Dividend4_5

		ADDLW		.0
		BTFSS	STATUS,Z
		GOTO	REZ_TO_IND_8


	CALL	TWO_BYTE_TO_LCD_Dividend4_5
	BCF		IND_3,0	
	BCF		IND_4,0	
	BCF		FLAG_FLASH_DP4


	RETURN	
;**************************
REZ_TO_IND_8







	GOTO	ERR_XX_3


	RETURN


;*****************************************************************************	
;*****************************************************************************
;*****************************************************************************	
;*****************************************************************************	
;*****************************************************************************
;*****************************************************************************	
;*****************************************************************************
;*****************************************************************************	
;*****************************************************************************



L_MODE
		BTFSC		FLAG_MODE_L
		GOTO		L_MODE_START

		BSF		FLAG_MODE_L

		BCF		FLAG_MODE_F
		BCF		FLAG_MODE_C
		BCF		FLAG_MODE_R

		MOVLW	b'11100011' ; L
		MOVWF	IND_1

		CALL	SEND_SET

		PAGESEL		SET_TO_L_MODE 	
		CALL 		SET_TO_L_MODE ^800	
		PAGESEL		START
;-------------------------------------------------------------
	MOVLW	.250
	CALL	Delay_XXXmS	
	MOVLW	.250
	CALL	Delay_XXXmS	
	MOVLW	.250
	CALL	Delay_XXXmS	

		BTFSS	FLAG_SAVE_MODE	
		GOTO	BEGIN_AAAA

		PAGESEL		SAVE_MODE_EE	
		CALL 		SAVE_MODE_EE^800	
		PAGESEL		START

BEGIN_AAAA

	BCF		FLAG_PRESS_KEY_ZERRO_MID_1
	BCF		FLAG_PRESS_KEY_ZERRO_MID
;--------------------------------------------------------------
L_MODE_START
	BTFSS		FLAG_NEW_MODE	
	GOTO		L_MODE_START_A
	BCF			FLAG_NEW_MODE
	RETURN
L_MODE_START_A
	BCF		FLAG_SKIP_CLEAR_TMR1 ; ЕСЛИ МАЛО ТО МЕРЯТЬ ЕЩЕ СЕКУНДУ И ЕЩЕ УСТАНОВИВ ЭТОТ ФЛАГ	
	; ДЛЯ L MODE НЕ ПОНАДОБИТСЯ....
;	BSF		FLAG_CALC_100MS  ; Hz*10
	BCF		FLAG_CALC_100MS	 ; Hz
	BSF		FLAG_START_FCOUNT
; измеритель запускается в прерывании  100 или 1000 мс
WAIT_COUNT_L	
	BTFSC		FLAG_START_FCOUNT	
	GOTO		WAIT_COUNT_L	
; ЧАСТОТА =  COUNT_TIMER_1_ST:COUNT_TIMER_1:TMR1H:TMR1L	
;270F = 9999 HZ
; ПОСЧИТАЛИ ЧАСТОТУ В СЧЕТЧИКИ.....
; Lx=COEFF_L*[(nx*No/no*Nx)^2-1]

		RRF		COUNT_TIMER_1,F
		RRF		TMR1H,F
		RRF		TMR1L,F

		RRF		COUNT_TIMER_1,F
		RRF		TMR1H,F
		RRF		TMR1L,F

		BCF		COUNT_TIMER_1,7
		BCF		COUNT_TIMER_1,6

CALC_INDUCTOR

;***************************
; COUNT =  COUNT_TIMER_1_ST:COUNT_TIMER_1:TMR1H:TMR1L	
; FRQ_OPORA = CLR_MODE_FRQ_OPORA_UP:CLR_MODE_FRQ_OPORA_ST:CLR_MODE_FRQ_OPORA_ML

;	REZULT =  (FRQ_OPORA / COUNT)  * (FRQ_OPORA / COUNT)  - 1

;	REZULT =	REZULT ( * L_KORRECTOR_KOF  ????  )*  L_NOMINAL_OPORA
;***************************


; Dividend:Dividend1:Dividend2: , :Dividend3:Dividend4:Dividend5 / AARGB0:AARGB1:AARGB2= Dividend:Dividend1:Dividend2: , :Dividend3:Dividend4:Dividend5
;20.05.2011
	MOVF	COUNT_TIMER_1,W
	MOVWF	AARGB0
	MOVWF	SAVE_COUNT_TIMER_1 ; СОХРАНИМ КОПИЮ СЧЕТЧИКА ;20.05.2011

	MOVF	TMR1H,W
	MOVWF	AARGB1	
	MOVWF	SAVE_TMR1H;20.05.2011

	MOVF	TMR1L,W
	MOVWF	AARGB2
	MOVWF	SAVE_TMR1L;20.05.2011
;;************************************************
;;*************************************************
CALC_INDUCTOR_2
	MOVF	CLR_MODE_FRQ_OPORA_UP,W
	MOVWF	Dividend
	MOVF	CLR_MODE_FRQ_OPORA_ST,W
	MOVWF	Dividend1	
	MOVF	CLR_MODE_FRQ_OPORA_ML,W
	MOVWF	Dividend2
	CLRF	Dividend3
	CLRF	Dividend4
	CLRF	Dividend5

		PAGESEL		DIVIDE_48by24	
		CALL		DIVIDE_48by24^800	
		PAGESEL		CALC_REZISTOR
		ADDLW	.0
		BTFSC	STATUS,Z
			GOTO	ERR_XX_0 ; НЕТ ОПОРНОЙ ЧАСТОТЫ ПРИ ИЗМЕРЕНИИ ИЛИ ОНА = 0 КЗ, не подключена индуктивность
	

        MOVF    Dividend,W
        IORWF   Dividend1,W
        IORWF   Dividend2,W

        BTFSs   STATUS,Z
		goto	SKIP_OTR1		


 ;Dividend:Dividend1:Dividend2: , :Dividend3:Dividend4:Dividend5
;ЧАСТОТА ПОСЛЕ ИЗМЕРЕНИЯ ВЫШЕ ОПОНОЙ - ОТРИЦАТЕЛЬНАЯ ВЕЛИЧИНА НОМИНАЛА
 
 ;Dividend:Dividend1:Dividend2: , :Dividend3:Dividend4:Dividend5
;20.05.2011

;>>>>>>>
;ТУТ КОПИЮ СЧЕТЧИКА В ОПОРНУЮ ЧАСТОТУ ПОМЕСТИТЬ
;>ЕСЛИ КНОПКУ "0" НАЖАЛИ
		BTFSS	FLAG_DEBUG_MODE
		CALL	SET_FRQ_OPORA_

		MOVLW	.1	
		MOVWF	Dividend2
		CLRF	Dividend3
		CLRF	Dividend4
		CLRF	Dividend5

		goto	SKIP_OTR1


        BTFSC   STATUS,Z
    		GOTO	ERR_XX_1	 ;	 ЧАСТОТА ПОСЛЕ ИЗМЕРЕНИЯ ВЫШЕ ОПОНОЙ - ОТРИЦАТЕЛЬНАЯ  ЕМКОСТЬ	 - INVALID / 1- XXXXXXXXXX
; REZULT = Dividend:Dividend1:Dividend2: , :Dividend3:Dividend4:Dividend5
;;****  
;      	MOVF    Dividend,W
;        IORWF   Dividend1,W
;        BTFSC   STATUS,Z
;  			GOTO	ERR_XX_3 ; МАЛА ИЗМЕРЕННАЯ ЧАСТОТА, СЛИШКОМ БОЛЬШАЯ ИНДУКТИВНОСТЬ
;;**** 
;820 uH * 255 =  209*209 =  43H max

; REZULT = Dividend2: , :Dividend3:Dividend4:Dividend5


SKIP_OTR1


;***********
	MOVF	Dividend5,W
	MOVWF	bcd4
	MOVWF	Dividend7
	MOVF	Dividend4,W
	MOVWF	bcd3
	MOVWF	Dividend6
	MOVF	Dividend3,W
	MOVWF	bcd2
	MOVWF	Dividend5
	MOVF	Dividend2,W
	MOVWF	bcd1
	MOVWF	Dividend4


; bcd1:bcd2:bcd3:bcd4  * Dividend4:Dividend5:Dividend6:Dividend7 = Dividend:Dividend1:Dividend2:Dividend3:   Dividend4:Dividend5:Dividend6:Dividend7
		PAGESEL		MULTIPLY_32x32	
		CALL		MULTIPLY_32x32^800	
		PAGESEL		CALC_INDUCTOR

;*****************************************************


; REZULT = Dividend:Dividend1: , :Dividend2:Dividend3:Dividend4:Dividend5:Dividend6:Dividend7


; -1
		MOVLW	.1
		SUBWF   Dividend1,F
		BTFSS	STATUS,C	
		DECF   	Dividend,F

;	REZULT =	REZULT  L_NOMINAL_OPORA

;        BTFSC   Dividend,7
;	    GOTO	ERR_XX_3	 ;	 СЛИШКОМ БОЛЬШАЯ ИНДУКТИВНОСТЬ 
;        BTFSC   Dividend,6
;	    GOTO	ERR_XX_3	 ;	 СЛИШКОМ БОЛЬШАЯ ИНДУКТИВНОСТЬ 
;; 10 H max

;mult_32_16:
; Dividend2:Dividend3: , :Dividend4:Dividend5 * bin1:bin2 -> Dividend:Dividend1:Dividend2:Dividend3: , : Dividend4:Dividend5  pF

	MOVF	Dividend3,W
	MOVWF	Dividend5
	MOVF	Dividend2,W
	MOVWF	Dividend4
	MOVF	Dividend1,W
	MOVWF	Dividend3
	MOVF	Dividend,W
	MOVWF	Dividend2

	MOVF	CLR_NOMINAL_OPORA_ST,W
	MOVWF	bin1
	MOVF	CLR_NOMINAL_OPORA_ML,W
	MOVWF	bin2

		PAGESEL		mult_32_16	
		CALL		mult_32_16^800	
		PAGESEL		CALC_CAPISTOR

;	L= Dividend:Dividend1:Dividend2:Dividend3: , : Dividend4:Dividend5  uH
;Dividend - DEL

		MOVF	Dividend,W
        BTFSS   STATUS,Z
	    GOTO	ERR_XX_3	 ;	 СЛИШКОМ БОЛЬШАЯ ИНДУКТИВНОСТЬ 



;	L=   Dividend1:Dividend2:Dividend3: , : Dividend4:Dividend5  uH
;0.01 uH  - 16H 

; ЕСЛИ НАЖАЛИ ОБНУЛЕНИЕ 
		CALL	ZERRO_CORRECTOR


;	L=   Dividend1:Dividend2:Dividend3: , : Dividend4:Dividend5  uH
;ПРИВЕДЕМ ДРОБНУЮ ЧАСТЬ 
 ; Dividend4:Dividend5  / .656

;FXD2416U
;AARGB0:AARGB1:AARGB2 /  BARGB0:BARGB1 = AARGB0:AARGB1:AARGB2 OST = REMB0:REMB1

		CLRF	AARGB0
		MOVF	Dividend4,W
		MOVWF	AARGB1
		MOVF	Dividend5,W
		MOVWF	AARGB2



		
		MOVLW	0x19	
		MOVWF	BARGB0
		MOVLW	0x9A
		MOVWF	BARGB1

		PAGESEL		FXD2416U	
		CALL		FXD2416U^800	
		PAGESEL		CALC_CAPISTOR

		MOVF	AARGB2,W
		MOVWF	Dividend4



		CLRF	AARGB0
		MOVF	REMB0,W
		MOVWF	AARGB1
		MOVF	REMB1,W
		MOVWF	AARGB2

		
		MOVLW	0x02	
		MOVWF	BARGB0
		MOVLW	0x90
		MOVWF	BARGB1

		PAGESEL		FXD2416U	
		CALL		FXD2416U^800	
		PAGESEL		CALC_CAPISTOR

		MOVF	AARGB2,W
		MOVWF	Dividend5


;	L= Dividend1:Dividend2:Dividend3: , : Dividend4:Dividend5    (Dividend4 - DEC 0-9  :Dividend5 - DEC 0-9)    uH
;ПОКАЖЕМ МИНИМАЛЬНЫЕ ДАННЫЕ

        MOVF    Dividend1,W
        IORWF   Dividend2,W
        BTFSS   STATUS,Z
		GOTO	L_TO_IND_1


		MOVLW	.99
		SUBWF	Dividend3,W
		BTFSC	STATUS,C
		GOTO	L_TO_IND_1


; L = 99.99 U=uH


;Входные данные: двоичное число в регистрах bin1, bin2. При этом bin1 - старший байт.		
	CLRF	bin1	
	MOVF	Dividend3,W
	MOVWF	bin2
	CALL		bin2bcd 
;Выходные: единицы будут в младшей тетраде регистра bcd3, десятки в старшей регистра bcd3,
;сотни в младшей тетраде регистра bcd2, тысячи в старшей bcd2,
;десятки тысяч будут находиться в младшей тетраде регистра bcd1.
	SWAPF		bcd3,W
	ANDLW		b'00001111'
	CALL		LCDTable
	MOVWF	IND_1	

	MOVF		bcd3,W
	ANDLW		b'00001111'
	CALL		LCDTable
	MOVWF	IND_2

	MOVF		Dividend4,W			
	ANDLW		b'00001111'
	CALL		LCDTable
	MOVWF	IND_3

	MOVF		Dividend5,W	
	ANDLW		b'00001111'
	CALL		LCDTable
	MOVWF	IND_4

	BCF		IND_2,0	
	BCF		FLAG_FLASH_DP4	

	RETURN	
;***********************************



L_TO_IND_1
		GOTO	REZ_TO_IND_1

; ПОКАЖЕМ ЕМКОСТЬ
;	L= Dividend:Dividend1:Dividend2:Dividend3: , : Dividend4 (Dividend4 - DEC 0-9)    uH
; 0 - 999.9 uH = 0 - 3E7.9

        MOVF    Dividend,W
        IORWF   Dividend1,W
        BTFSS   STATUS,Z
		GOTO	L_TO_IND_2 ;> 65535 pF


		MOVLW	.3
		SUBWF	Dividend2,W
		BTFSC	STATUS,Z
		GOTO	L_TO_IND_1B ; = 3

		BTFSC	STATUS,C
		GOTO	L_TO_IND_2;	>=3
		
		GOTO	L_TO_IND_1A ; <3

L_TO_IND_1B
		MOVLW	0xE7
		SUBWF	Dividend3,W
		BTFSC	STATUS,C
		GOTO	L_TO_IND_2 ; > E7

L_TO_IND_1A
		GOTO	CAP_TO_IND_1A
	
;**************************
L_TO_IND_2

;	C= Dividend:Dividend1:Dividend2:Dividend3:   pF
; 999.9 - 9999 pF = 0 - 2710
		CALL	TEST_UP_9999_Dividend2_3

		ADDLW		.0
		BTFSS	STATUS,Z
		GOTO	L_TO_IND_3

	CALL	TWO_BYTE_TO_LCD_Dividend2_3
	BCF		FLAG_FLASH_DP4	
	RETURN	
;**************************
L_TO_IND_3

;	C= Dividend:Dividend1:Dividend2:Dividend3: /10    00.01 nF

;09.99 - 99.99 nF = 0 - 2710

; Dividend:Dividend1 ....Dividend5 / AARGB0:AARGB1:AARGB2 =  Dividend:Dividend1 ....Dividend5
;DIVIDE_48by24
	
	CLRF	Dividend4
	CLRF	Dividend5
	MOVLW	.10
	MOVWF	AARGB0
	CLRF	AARGB1
	CLRF	AARGB2
		PAGESEL		DIVIDE_48by24	
		CALL		DIVIDE_48by24^800	
		PAGESEL		CALC_CAPISTOR

;	C= Dividend2:Dividend3:Dividend4:Dividend5   00.01 nF

		CALL	TEST_UP_9999_Dividend4_5

		ADDLW		.0
		BTFSS	STATUS,Z
		GOTO	L_TO_IND_4



	CALL	TWO_BYTE_TO_LCD_Dividend4_5
	BCF		IND_2,0	
	BSF		FLAG_FLASH_DP4
	RETURN	
;**************************
L_TO_IND_4

;	C= Dividend2:Dividend3:Dividend4:Dividend5 /10    000.1 nF

;099.9 - 999.9 nF = 0 - 2710

; Dividend:Dividend1 ....Dividend5 / AARGB0:AARGB1:AARGB2 =  Dividend:Dividend1 ....Dividend5
;DIVIDE_48by24

	CLRF	Dividend
	CLRF	Dividend1	
	MOVLW	.10
	MOVWF	AARGB2
	CLRF	AARGB1
	CLRF	AARGB0
		PAGESEL		DIVIDE_48by24	
		CALL		DIVIDE_48by24^800	
		PAGESEL		CALC_CAPISTOR

;	C= Dividend2:Dividend3:Dividend4:Dividend5   000.1 nF

		CALL	TEST_UP_9999_Dividend4_5

		ADDLW		.0
		BTFSS	STATUS,Z
		GOTO	L_TO_IND_5

	CALL	TWO_BYTE_TO_LCD_Dividend4_5
	BCF		IND_3,0	
	BSF		FLAG_FLASH_DP4
	RETURN	
;**************************
L_TO_IND_5

;	C= Dividend2:Dividend3:Dividend4:Dividend5 /10    0000 nF

;0999 - 9999 nF = 0 - 2710

; Dividend:Dividend1 ....Dividend5 / AARGB0:AARGB1:AARGB2 =  Dividend:Dividend1 ....Dividend5
;DIVIDE_48by24

	CLRF	Dividend
	CLRF	Dividend1	
	MOVLW	.10
	MOVWF	AARGB2
	CLRF	AARGB1
	CLRF	AARGB0
		PAGESEL		DIVIDE_48by24	
		CALL		DIVIDE_48by24^800	
		PAGESEL		CALC_CAPISTOR
;	C= Dividend2:Dividend3:Dividend4:Dividend5   0001 nF

		CALL	TEST_UP_9999_Dividend4_5

		ADDLW		.0
		BTFSS	STATUS,Z
		GOTO	L_TO_IND_6


	CALL	TWO_BYTE_TO_LCD_Dividend4_5
	BSF		FLAG_FLASH_DP4


	RETURN	
;**************************
L_TO_IND_6
;	C= Dividend2:Dividend3:Dividend4:Dividend5 /10    00.00 uF
;09.99 - 99.99 uF = 0 - 2710

; Dividend:Dividend1 ....Dividend5 / AARGB0:AARGB1:AARGB2 =  Dividend:Dividend1 ....Dividend5
;DIVIDE_48by24

	CLRF	Dividend
	CLRF	Dividend1	
	MOVLW	.10
	MOVWF	AARGB2
	CLRF	AARGB1
	CLRF	AARGB0
		PAGESEL		DIVIDE_48by24	
		CALL		DIVIDE_48by24^800	
		PAGESEL		CALC_CAPISTOR

;	C= Dividend2:Dividend3:Dividend4:Dividend5   99.99 H

		CALL	TEST_UP_9999_Dividend4_5

		ADDLW		.0
		BTFSS	STATUS,Z
		GOTO	L_TO_IND_7


	CALL	TWO_BYTE_TO_LCD_Dividend4_5
	BCF		IND_2,0	
	BCF		IND_4,0	
	BCF		FLAG_FLASH_DP4


	RETURN	
;**************************
L_TO_IND_7

	GOTO	ERR_XX_3


	RETURN	


;	GOTO	F_MODE_CALC



	RETURN
;*****************************************************************************
;*****************************************************************************
;**************************************************************************** 
;**************************************************************************** 
;**************************************************************************** 
;**************************************************************************** 
;**************************************************************************** 
;**************************************************************************** 
;**************************************************************************** 


;**************************************************************************** 	
;**************************************************************************** 
;**************************************************************************** 
;**************************************************************************** 
DB_0X

	MOVLW	.13
	CALL		LCDTable
	MOVWF	IND_1	
	
	MOVLW	.11
	CALL		LCDTable
	MOVWF	IND_2	
	
	MOVLW	.0
	CALL		LCDTable
	MOVWF	IND_3	

	RETURN
;**************************************************************************** 
DEBUG_MODE

		CLRF	NUMBER_DEBUG_MODE
		BSF			POWER_ON

;*****************************************************************************
; ЗАПОМНИТЬ ЧАСТОТУ НАЧАЛЬНОЙ ГЕНЕРАЦИИ  , КОНДЕР НЕ ПОДКЛЮЧЕН
DEBUG_MODE_0
	CALL	DB_0X
	MOVLW	.0
	CALL		LCDTable
	MOVWF	IND_4	

	CALL	Delay_1S
		PAGESEL		SET_TO_C_MODE 	
		CALL 		SET_TO_C_MODE ^800	
		PAGESEL		START
		BCF			FLAG_PRESS_KEY_ZERRO_MID_1
		BCF		FLAG_PRESS_KEY_ZERRO_MID
;******
		CLRF	MODE
CIKLE_DEBUG_0; 
; 		CALL	Delay_100mS	

		MOVF	MODE,W
		BTFSC	STATUS,Z
		GOTO	DEBUG_0_A	
;		INCF	ESR_1_POROG_NULL,F
		CLRF	MODE
DEBUG_0_A
		MOVLW	.1
		XORWF 	NUMBER_DEBUG_MODE,W
		BTFSC	STATUS,Z
		GOTO	DEBUG_MODE_1


	BCF		FLAG_SKIP_CLEAR_TMR1 ; ЕСЛИ МАЛО ТО МЕРЯТЬ ЕЩЕ СЕКУНДУ И ЕЩЕ УСТАНОВИВ ЭТОТ ФЛАГ	
;	BSF		FLAG_CALC_100MS  ; Hz*10
	BCF		FLAG_CALC_100MS	 ; Hz
	BSF		FLAG_START_FCOUNT
; измеритель запускается в прерывании  100 или 1000 мс
WAIT_COUNT_DEBUG_0	
	BTFSC		FLAG_START_FCOUNT	
	GOTO		WAIT_COUNT_DEBUG_0

; СОХРАНИМ ЧАСТОТУ ВРЕМЕННО
	MOVF	COUNT_TIMER_1,W
	MOVWF	CLR_MODE_FRQ_OPORA_UP
	MOVF	TMR1H,W
	MOVWF	CLR_MODE_FRQ_OPORA_ST	
	MOVF	TMR1L,W
	MOVWF	CLR_MODE_FRQ_OPORA_ML

; ПОКАЖЕМ
		CALL	F_MODE_CALC


		GOTO	CIKLE_DEBUG_0
;******;******
DEBUG_MODE_1; 


		PAGESEL		SAVE_C_MODE_FRQ_OPORA	
		CALL 		SAVE_C_MODE_FRQ_OPORA^800	
		PAGESEL		START
;*****************************************************************************
; ЗАПОМНИТЬ ЧАСТОТУ НАЧАЛЬНОЙ ГЕНЕРАЦИИ  , РЕЗИСТОР ЗАМКНУТЬ

	CALL	DB_0X
	MOVLW	.1
	CALL		LCDTable
	MOVWF	IND_4	

	CALL	Delay_1S

		PAGESEL		SET_TO_R_MODE	
		CALL 		SET_TO_R_MODE^800	
		PAGESEL		START
	BCF		FLAG_PRESS_KEY_ZERRO_MID_1
	BCF		FLAG_PRESS_KEY_ZERRO_MID
;******
		CLRF	MODE
CIKLE_DEBUG_1; 
; 		CALL	Delay_100mS	

		MOVF	MODE,W
		BTFSC	STATUS,Z
		GOTO	DEBUG_1_A	
;		INCF	ESR_1_POROG_NULL,F
		CLRF	MODE
DEBUG_1_A
		MOVLW	.2
		XORWF 	NUMBER_DEBUG_MODE,W
		BTFSC	STATUS,Z
		GOTO	DEBUG_MODE_2

	BCF		FLAG_SKIP_CLEAR_TMR1 ; ЕСЛИ МАЛО ТО МЕРЯТЬ ЕЩЕ СЕКУНДУ И ЕЩЕ УСТАНОВИВ ЭТОТ ФЛАГ	
;	BSF		FLAG_CALC_100MS  ; Hz*10
	BCF		FLAG_CALC_100MS	 ; Hz
	BSF		FLAG_START_FCOUNT
; измеритель запускается в прерывании  100 или 1000 мс
WAIT_COUNT_DEBUG_1	
	BTFSC		FLAG_START_FCOUNT	
	GOTO		WAIT_COUNT_DEBUG_1
; СОХРАНИМ ЧАСТОТУ ВРЕМЕННО
	MOVF	COUNT_TIMER_1,W
	MOVWF	CLR_MODE_FRQ_OPORA_UP
	MOVF	TMR1H,W
	MOVWF	CLR_MODE_FRQ_OPORA_ST	
	MOVF	TMR1L,W
	MOVWF	CLR_MODE_FRQ_OPORA_ML
; ПОКАЖЕМ
		CALL	F_MODE_CALC

		GOTO	CIKLE_DEBUG_1
;******;******
DEBUG_MODE_2; 
;>>>Сохраним 


		PAGESEL		SAVE_R_MODE_FRQ_OPORA	
		CALL 		SAVE_R_MODE_FRQ_OPORA^800	
		PAGESEL		START

;*****************************************************************************
; ЗАПОМНИТЬ ЧАСТОТУ НАЧАЛЬНОЙ ГЕНЕРАЦИИ  , ИНДУКТИВНОСТЬ  ЗАМКНУТЬ
; ИЗМЕРЕНИЕ  100 МС

	CALL	DB_0X	
	
	MOVLW	.2
	CALL		LCDTable
	MOVWF	IND_4	

	CALL	Delay_1S

		PAGESEL		SET_TO_L_MODE 	
		CALL 		SET_TO_L_MODE ^800	
		PAGESEL		START
	BCF		FLAG_PRESS_KEY_ZERRO_MID_1
	BCF		FLAG_PRESS_KEY_ZERRO_MID

;******
		CLRF	MODE
CIKLE_DEBUG_2; 
; 		CALL	Delay_100mS	
		MOVF	MODE,W
		BTFSC	STATUS,Z
		GOTO	DEBUG_2_A	
;		INCF	ESR_1_POROG_NULL,F
		CLRF	MODE
DEBUG_2_A
		MOVLW	.3
		XORWF 	NUMBER_DEBUG_MODE,W
		BTFSC	STATUS,Z
		GOTO	DEBUG_MODE_3

	BCF		FLAG_SKIP_CLEAR_TMR1 ; ЕСЛИ МАЛО ТО МЕРЯТЬ ЕЩЕ СЕКУНДУ И ЕЩЕ УСТАНОВИВ ЭТОТ ФЛАГ	
;	BSF		FLAG_CALC_100MS  ; Hz*10
	BCF		FLAG_CALC_100MS	 ; Hz
	BSF		FLAG_START_FCOUNT
; измеритель запускается в прерывании  100 или 1000 мс
WAIT_COUNT_DEBUG_2	
	BTFSC		FLAG_START_FCOUNT	
	GOTO		WAIT_COUNT_DEBUG_2


		RRF		COUNT_TIMER_1,F
		RRF		TMR1H,F
		RRF		TMR1L,F

		RRF		COUNT_TIMER_1,F
		RRF		TMR1H,F
		RRF		TMR1L,F

		BCF		COUNT_TIMER_1,7
		BCF		COUNT_TIMER_1,6


; СОХРАНИМ ЧАСТОТУ ВРЕМЕННО
	MOVF	COUNT_TIMER_1,W
	MOVWF	CLR_MODE_FRQ_OPORA_UP
	MOVF	TMR1H,W
	MOVWF	CLR_MODE_FRQ_OPORA_ST	
	MOVF	TMR1L,W
	MOVWF	CLR_MODE_FRQ_OPORA_ML
; ПОКАЖЕМ
		CALL	F_MODE_CALC
		GOTO	CIKLE_DEBUG_2
;******;******
DEBUG_MODE_3; 
;>>>Сохраним 


		PAGESEL		SAVE_L_MODE_FRQ_OPORA	
		CALL 		SAVE_L_MODE_FRQ_OPORA^800	
		PAGESEL		START

;*****************************************************************************
;CALIBR 
;C= 0 
;COUNT >> FRQ_OPORA  сделано 
;
;C= BIG
;
;C_KORRECTOR_KOF*C_NOMINAL_OPORA (def =4500 key +/-1) = FRQ_OPORA/ COUNT -1

; indicator =   
;	REZULT =  FRQ_OPORA / COUNT  - 1
;	REZULT =	REZULT ( * C_KORRECTOR_KOF  ????  )*  C_NOMINAL_OPORA
;***************************

;  -----  Подключить извесный конденсатор и добиться его показаний

; ИЗМЕРЕНИЕ  1000 МС

	CALL	DB_0X	
	
	MOVLW	.3
	CALL		LCDTable
	MOVWF	IND_4	

	CALL	Delay_1S

		PAGESEL		SET_TO_C_MODE 	
		CALL 		SET_TO_C_MODE ^800	
		PAGESEL		START
	BCF		FLAG_PRESS_KEY_ZERRO_MID_1
	BCF		FLAG_PRESS_KEY_ZERRO_MID

		BCF	  FLAG_MODE_F		
		BCF	  FLAG_MODE_L 			
		BSF	  FLAG_MODE_C		
		BCF	  FLAG_MODE_R			


;******
		CLRF	MODE
CIKLE_DEBUG_3; 
; 		CALL	Delay_100mS	
		MOVF	MODE,W
		BTFSC	STATUS,Z
		GOTO	DEBUG_3_B	
		CLRF	MODE

		movlw	.10
		ADDWF	CLR_NOMINAL_OPORA_ML,F
		BTFSC	STATUS,C
		INCF	CLR_NOMINAL_OPORA_ST,F

DEBUG_3_B

		BTFSS	FLAG_PRESS_KEY_ZERRO_SHORT
		GOTO	DEBUG_3_A
		BCF		FLAG_PRESS_KEY_ZERRO_SHORT

		MOVLW	.1
		SUBWF	CLR_NOMINAL_OPORA_ML,F
		BTFSS	STATUS,C
		DECF	CLR_NOMINAL_OPORA_ST,F

DEBUG_3_A
		MOVLW	.4
		XORWF 	NUMBER_DEBUG_MODE,W
		BTFSC	STATUS,Z
		GOTO	DEBUG_MODE_4


;************************************************
;CLR_NOMINAL_OPORA_ML;	DE	0x94
;CLR_NOMINAL_OPORA_ST;	DE	0x11


TEST_HIGH_LEVEL_C
		MOVLW	0x13
		SUBWF	CLR_NOMINAL_OPORA_ST,W

		BTFSS	STATUS,C 
		GOTO	TEST_LOW_LEVEL_C
; >= 12h
		BTFSS	STATUS,Z
		GOTO	SET_LOW_LEVEL_C	;>12
; = 12		
		MOVLW	0xF0
		SUBWF	CLR_NOMINAL_OPORA_ML,W
		BTFSS	STATUS,C
		GOTO	TEST_LOW_LEVEL_C
;>DOh
SET_LOW_LEVEL_C
		MOVLW	0x11
		MOVWF	CLR_NOMINAL_OPORA_ST
		MOVLW	0x08
		MOVWF	CLR_NOMINAL_OPORA_ML

		GOTO	END_TEST_LEVEL_C
TEST_LOW_LEVEL_C
		MOVLW	0x11
		SUBWF	CLR_NOMINAL_OPORA_ST,W
		BTFSS	STATUS,C 
		GOTO	SET_HIGH_LEVEL_C ; <11h

		BTFSS	STATUS,Z
		GOTO	END_TEST_LEVEL_C	;>11
; = 11
		MOVLW	0x01
		SUBWF	CLR_NOMINAL_OPORA_ML,W
		BTFSC	STATUS,C
		GOTO	END_TEST_LEVEL_C ; >= 01h
; <01
SET_HIGH_LEVEL_C
		MOVLW	0x13
		MOVWF	CLR_NOMINAL_OPORA_ST
		MOVLW	0xE8
		MOVWF	CLR_NOMINAL_OPORA_ML

END_TEST_LEVEL_C
;************************************************

	BCF		FLAG_SKIP_CLEAR_TMR1 ; ЕСЛИ МАЛО ТО МЕРЯТЬ ЕЩЕ СЕКУНДУ И ЕЩЕ УСТАНОВИВ ЭТОТ ФЛАГ	
;	BSF		FLAG_CALC_100MS  ; Hz*10
	BCF		FLAG_CALC_100MS	 ; Hz
	BSF		FLAG_START_FCOUNT
; измеритель запускается в прерывании  100 или 1000 мс
WAIT_COUNT_DEBUG_3	
	BTFSC		FLAG_START_FCOUNT	
	GOTO		WAIT_COUNT_DEBUG_3

; ПОКАЖЕМ

		CALL	CALC_CAPISTOR
		GOTO	CIKLE_DEBUG_3
;******;******
DEBUG_MODE_4; 


		PAGESEL		SAVE_C_NOMINAL_OPORA	
		CALL 		SAVE_C_NOMINAL_OPORA^800	
		PAGESEL		START
;*******************************************************************************************************************
;  -----  Подключить извесный РЕЗИСТОР и добиться его показаний

; ИЗМЕРЕНИЕ  1000 МС
	CALL	DB_0X	
	
	MOVLW	.4
	CALL		LCDTable
	MOVWF	IND_4	

	CALL	Delay_1S

		PAGESEL		SET_TO_R_MODE	
		CALL 		SET_TO_R_MODE^800	
		PAGESEL		START
	BCF		FLAG_PRESS_KEY_ZERRO_MID_1
	BCF		FLAG_PRESS_KEY_ZERRO_MID

		BCF	  FLAG_MODE_F		
		BCF	  FLAG_MODE_L 			
		BCF	  FLAG_MODE_C		
		BSF	  FLAG_MODE_R			



;******
		CLRF	MODE
CIKLE_DEBUG_4; 
; 		CALL	Delay_100mS	
		MOVF	MODE,W
		BTFSC	STATUS,Z
		GOTO	DEBUG_4_B	
		CLRF	MODE

		movlw	.10
		ADDWF	CLR_NOMINAL_OPORA_ML,F
		BTFSC	STATUS,C
		INCF	CLR_NOMINAL_OPORA_ST,F

DEBUG_4_B

		BTFSS	FLAG_PRESS_KEY_ZERRO_SHORT
		GOTO	DEBUG_4_A
		BCF		FLAG_PRESS_KEY_ZERRO_SHORT

		MOVLW	.1
		SUBWF	CLR_NOMINAL_OPORA_ML,F
		BTFSS	STATUS,C
		DECF	CLR_NOMINAL_OPORA_ST,F

DEBUG_4_A
		MOVLW	.5
		XORWF 	NUMBER_DEBUG_MODE,W
		BTFSC	STATUS,Z
		GOTO	DEBUG_MODE_5
;************************************************
			;
;	DE	0x80			;ADDR_R_NOMINAL_OPORA_ML_EE		EQU     0x0F
;	DE	0x07			;ADDR_R_NOMINAL_OPORA_ST_EE		EQU     0x10

;MAX=09F0
;MIN=0610
TEST_HIGH_LEVEL_R
		MOVLW	0x09
		SUBWF	CLR_NOMINAL_OPORA_ST,W

		BTFSS	STATUS,C 
		GOTO	TEST_LOW_LEVEL_R
; >= 11h
		BTFSS	STATUS,Z
		GOTO	SET_LOW_LEVEL_R	;>11
; = 11		
		MOVLW	0xF0
		SUBWF	CLR_NOMINAL_OPORA_ML,W
		BTFSS	STATUS,C
		GOTO	TEST_LOW_LEVEL_R
;>8Oh
SET_LOW_LEVEL_R
		MOVLW	0x06
		MOVWF	CLR_NOMINAL_OPORA_ST
		MOVLW	0x0F
		MOVWF	CLR_NOMINAL_OPORA_ML

		GOTO	END_TEST_LEVEL_R
TEST_LOW_LEVEL_R
		MOVLW	0x06
		SUBWF	CLR_NOMINAL_OPORA_ST,W
		BTFSS	STATUS,C 
		GOTO	SET_HIGH_LEVEL_R ; <09h

		BTFSS	STATUS,Z
		GOTO	END_TEST_LEVEL_R	;>09
; = 09
		MOVLW	0x08
		SUBWF	CLR_NOMINAL_OPORA_ML,W
		BTFSC	STATUS,C
		GOTO	END_TEST_LEVEL_R ; >= 80h
; <80
SET_HIGH_LEVEL_R
		MOVLW	0x09
		MOVWF	CLR_NOMINAL_OPORA_ST
		MOVLW	0xE8
		MOVWF	CLR_NOMINAL_OPORA_ML

END_TEST_LEVEL_R
;************************************************

	BCF		FLAG_SKIP_CLEAR_TMR1 ; ЕСЛИ МАЛО ТО МЕРЯТЬ ЕЩЕ СЕКУНДУ И ЕЩЕ УСТАНОВИВ ЭТОТ ФЛАГ	
;	BSF		FLAG_CALC_100MS  ; Hz*10
	BCF		FLAG_CALC_100MS	 ; Hz
	BSF		FLAG_START_FCOUNT
; измеритель запускается в прерывании  100 или 1000 мс
WAIT_COUNT_DEBUG_4	
	BTFSC		FLAG_START_FCOUNT	
	GOTO		WAIT_COUNT_DEBUG_4

; ПОКАЖЕМ

		CALL	CALC_REZISTOR
		GOTO	CIKLE_DEBUG_4
;******;******
DEBUG_MODE_5; 

		PAGESEL		SAVE_R_NOMINAL_OPORA	
		CALL 		SAVE_R_NOMINAL_OPORA^800	
		PAGESEL		START

;*******************************************************************************************************************
;  -----  Подключить извесный INDUKTOR и добиться его показаний

; ИЗМЕРЕНИЕ  1000 МС
	CALL	DB_0X	
	
	MOVLW	.5
	CALL		LCDTable
	MOVWF	IND_4	

	CALL	Delay_1S

		PAGESEL		SET_TO_L_MODE	
		CALL 		SET_TO_L_MODE^800	
		PAGESEL		START

	BCF		FLAG_PRESS_KEY_ZERRO_MID_1
	BCF		FLAG_PRESS_KEY_ZERRO_MID
		BCF	  FLAG_MODE_F		
		BSF	  FLAG_MODE_L 			
		BCF	  FLAG_MODE_C		
		BCF	  FLAG_MODE_R

;******
		CLRF	MODE
CIKLE_DEBUG_5; 


; 		CALL	Delay_100mS	
		MOVF	MODE,W
		BTFSC	STATUS,Z
		GOTO	DEBUG_5_B	
		CLRF	MODE

		movlw	.10
		ADDWF	CLR_NOMINAL_OPORA_ML,F
		BTFSC	STATUS,C
		INCF	CLR_NOMINAL_OPORA_ST,F

DEBUG_5_B

		BTFSS	FLAG_PRESS_KEY_ZERRO_SHORT
		GOTO	DEBUG_5_A
		BCF		FLAG_PRESS_KEY_ZERRO_SHORT

		MOVLW	.1
		SUBWF	CLR_NOMINAL_OPORA_ML,F
		BTFSS	STATUS,C
		DECF	CLR_NOMINAL_OPORA_ST,F

DEBUG_5_A
		MOVLW	.6
		XORWF 	NUMBER_DEBUG_MODE,W
		BTFSC	STATUS,Z
		GOTO	DEBUG_MODE_6
;************************************************

			;
;	DE	0xC0			;ADDR_L_NOMINAL_OPORA_ML_EE		EQU     0x0D
;	DE	0x02			;ADDR_L_NOMINAL_OPORA_ST_EE		EQU     0x0E
			;

;MAX=04C0
;MIN=0110
TEST_HIGH_LEVEL_L
		MOVLW	0x04
		SUBWF	CLR_NOMINAL_OPORA_ST,W

		BTFSS	STATUS,C 
		GOTO	TEST_LOW_LEVEL_L
; >= 11h
		BTFSS	STATUS,Z
		GOTO	SET_LOW_LEVEL_L	;>11
; = 11		
		MOVLW	0xC0
		SUBWF	CLR_NOMINAL_OPORA_ML,W
		BTFSS	STATUS,C
		GOTO	TEST_LOW_LEVEL_L
;>8Oh
SET_LOW_LEVEL_L
		MOVLW	0x01
		MOVWF	CLR_NOMINAL_OPORA_ST
		MOVLW	0x18
		MOVWF	CLR_NOMINAL_OPORA_ML

		GOTO	END_TEST_LEVEL_L
TEST_LOW_LEVEL_L
		MOVLW	0x01
		SUBWF	CLR_NOMINAL_OPORA_ST,W
		BTFSS	STATUS,C 
		GOTO	SET_HIGH_LEVEL_L ; <09h

		BTFSS	STATUS,Z
		GOTO	END_TEST_LEVEL_L	;>09
; = 09
		MOVLW	0x10
		SUBWF	CLR_NOMINAL_OPORA_ML,W
		BTFSC	STATUS,C
		GOTO	END_TEST_LEVEL_L ; >= 80h
; <80
SET_HIGH_LEVEL_L
		MOVLW	0x04
		MOVWF	CLR_NOMINAL_OPORA_ST
		MOVLW	0xB8
		MOVWF	CLR_NOMINAL_OPORA_ML

END_TEST_LEVEL_L
;************************************************

	BCF		FLAG_SKIP_CLEAR_TMR1 ; ЕСЛИ МАЛО ТО МЕРЯТЬ ЕЩЕ СЕКУНДУ И ЕЩЕ УСТАНОВИВ ЭТОТ ФЛАГ	
;	BSF		FLAG_CALC_100MS  ; Hz*10
	BCF		FLAG_CALC_100MS	 ; Hz
	BSF		FLAG_START_FCOUNT
; измеритель запускается в прерывании  100 или 1000 мс
WAIT_COUNT_DEBUG_5	
	BTFSC		FLAG_START_FCOUNT	
	GOTO		WAIT_COUNT_DEBUG_5


		RRF		COUNT_TIMER_1,F
		RRF		TMR1H,F
		RRF		TMR1L,F

		RRF		COUNT_TIMER_1,F
		RRF		TMR1H,F
		RRF		TMR1L,F

		BCF		COUNT_TIMER_1,7
		BCF		COUNT_TIMER_1,6

; ПОКАЖЕМ

		CALL	CALC_INDUCTOR
		GOTO	CIKLE_DEBUG_5
;******;******
DEBUG_MODE_6; 

		PAGESEL		SAVE_L_NOMINAL_OPORA	
		CALL 		SAVE_L_NOMINAL_OPORA^800	
		PAGESEL		START




;**********************
	MOVLW	.13
	CALL		LCDTable
	MOVWF	IND_1	
	
	MOVLW	.11
	CALL		LCDTable
	MOVWF	IND_2	
	
		MOVLW	b'11000101' ;o
		MOVWF	IND_3

		MOVLW	b'11100101';c
		MOVWF	IND_4	

		MOVLW	0x20
		MOVWF	POWER_BAT_LOW
		

		PAGESEL		SAVE_POWER_BAT_LOW	
		CALL 		SAVE_POWER_BAT_LOW^800	
		PAGESEL		START

		MOVLW 	.8
		MOVWF	TEMP
WAITS_DB9		
		CALL	Delay_100mS	
		DECFSZ	TEMP,F
		GOTO	WAITS_DB9
;***
		MOVLW	.9
		MOVWF 	NUMBER_DEBUG_MODE
		BCF		FLAG_DEBUG_MODE	

		BCF		POWER_ON
		BCF		FLAG_LCD_ON

;		BsF 	SEG_1
;		BsF 	SEG_2
;		BsF 	SEG_3
;		BsF 	SEG_4
;
;		btfsc	FLAG_INVERT_INDIKATOR 
;		goto	inv_3
;
;		BCF 	SEG_1
;		BCF 	SEG_2
;		BCF 	SEG_3
;		BCF 	SEG_4
;inv_3		

		CALL	ON_OFF_SEG


		GOTO	BEGIN
;**************************************************************************** 
;**************************************************************************** 
TWO_BYTE_TO_LCD_Dividend4_5
	MOVF	Dividend4,W
	MOVWF	bin1	
	MOVF	Dividend5,W
	MOVWF	bin2

	GOTO	TWO_BYTE_TO_LCD


TWO_BYTE_TO_LCD_Dividend2_3

	MOVF	Dividend2,W
	MOVWF	bin1	
	MOVF	Dividend3,W
	MOVWF	bin2

	GOTO	TWO_BYTE_TO_LCD


TWO_BYTE_TO_LCD_AARGB1_2
	MOVF	AARGB1,W
	MOVWF	bin1	
	MOVF	AARGB2,W
	MOVWF	bin2


TWO_BYTE_TO_LCD
;Входные данные: двоичное число в регистрах bin1, bin2. При этом bin1 - старший байт.
;Выходные: единицы будут в младшей тетраде регистра bcd3, десятки в старшей регистра bcd3,
;сотни в младшей тетраде регистра bcd2, тысячи в старшей bcd2,
;десятки тысяч будут находиться в младшей тетраде регистра bcd1.
;	MOVF		POWER_LEVEL,W	
;	MOVWF		bin2
;	CLRF		bin1
	CALL		bin2bcd 
	
	SWAPF		bcd2,W	
	ANDLW		b'00001111'

	CALL		LCDTable
	MOVWF	IND_1	

	MOVF		bcd2,W	
	ANDLW		b'00001111'
	CALL		LCDTable
	MOVWF	IND_2

	SWAPF		bcd3,W	
	ANDLW		b'00001111'
	CALL		LCDTable
	MOVWF	IND_3

	MOVF		bcd3,W	
	ANDLW		b'00001111'
	CALL		LCDTable
	MOVWF	IND_4
				RETURN
;**************************************************************************** 
;================    function  ==============================================
;****************************************************************************;
;Название: bin2bcd   bcd1, bcd2, bcd3 = bin1, bin2
;Входные данные: двоичное число в регистрах bin1, bin2. При этом bin1 - старший байт.
;Выходные: единицы будут в младшей тетраде регистра bcd3, десятки в старшей регистра bcd3,
;сотни в младшей тетраде регистра bcd2, тысячи в старшей bcd2,
;десятки тысяч будут находиться в младшей тетраде регистра bcd1. 
;Используемые регистры: bin1, bin2, bcd1, bcd2, bcd3, ctr.
bin2bcd 
		        movlw 	.16 
                movwf 	ctr
                clrf 	bcd1
                clrf 	bcd2
                clrf 	bcd3
                goto 	start 

adjdec          movlw 	0x33 
                addwf 	bcd1,f 
                addwf 	bcd2,f 
                addwf 	bcd3,f 

                movlw 	0x03 
                btfss 	bcd1,3 
                subwf 	bcd1,f 
                btfss 	bcd2,3 
                subwf 	bcd2,f 
                btfss 	bcd3,3 
                subwf 	bcd3,f 

                movlw 	0x30 
                btfss 	bcd1,7 
                subwf 	bcd1,f 
                btfss 	bcd2,7 
                subwf 	bcd2,f 
                btfss 	bcd3,7 
                subwf 	bcd3,f 

start           rlf 	bin2,f 
                rlf 	bin1,f 
                rlf 	bcd3,f 
                rlf 	bcd2,f 
                rlf 	bcd1,f 
                decfsz 	ctr,f 
                goto 	adjdec 

                return 
;****************************************************************************************


;****************************************************************************************** 
SEND_SET
; ПИШЕМ SET , ЖДЕМ СЕКУНДУ , ПИШЕМ НУЛИ 
		MOVLW	b'01001001' ; S
		MOVWF	IND_2
		MOVLW	b'01100001' ; E
		MOVWF	IND_3
		MOVLW	b'11100001' ; t
		MOVWF	IND_4

		MOVLW 	.10
		MOVWF	TEMP
WAITS_MODS		
		CALL	Delay_100mS	
		DECFSZ	TEMP,F
		GOTO	WAITS_MODS

	MOVLW	.0
	CALL		LCDTable
	MOVWF	IND_1	
	MOVWF	IND_2	
	MOVWF	IND_3	
	MOVWF	IND_4

		RETURN

;****************************************************************************************** 

Delay_1S
		MOVLW 	.10
Delay_xx01S
		MOVWF	DELAY_COUNTER_3
WAITS_1S		
		CALL	Delay_100mS	
		DECFSZ	DELAY_COUNTER_3,F
		GOTO	WAITS_1S
		RETURN
;****************************************************************************************** 
;  ПОЛУБАЙТ В НЕХ ВИДЕ
BUTE_TO_HEX    
BIN_TO_HEX
				ANDLW	b'00001111'
				SUBLW	.9
				BTFSC	STATUS,C
				GOTO 	NUM_19
NUM_AF			
				SUBLW	.9
				ADDLW	.55
				RETURN
NUM_19		
				SUBLW	.9
				ADDLW	.48
				RETURN
     
;**********************************************************************
Delay_100mS
		MOVLW	.100	
Delay_XXXmS
        MOVWF   DELAY_COUNTER_2
	    CLRF   DELAY_COUNTER_1
DELAY_CIKLE1:
		NOP
		NOP
		NOP
		NOP
		NOP

		NOP
		NOP
		NOP
		NOP
		NOP
		
		NOP
		NOP
		NOP
		NOP
		NOP		

		NOP

        decfsz  DELAY_COUNTER_1,F
        goto    DELAY_CIKLE1
        decfsz  DELAY_COUNTER_2,F
        goto    DELAY_CIKLE1

        
        return 
;**********************************************************************


;************************************************************************
;************************************************************************
;************************************************************************

		ORG 0x800
;************************************************************************		
;************************************************************************

;**********************************************************************
;         ПОДПРОГРАММА  инициализации: установка портов              *
;**********************************************************************
_INIT_CPU
;CLEAR RAM
;ПАМЯТЬ 0x20 - 0x30 НЕ ОЧИЩАЕТСЯ 
;		MOVLW	0x30;initialize pointer

		MOVLW	0x20
		MOVWF	FSR	;to RAM
NEXT_B0
		CLRF	INDF
		INCF	FSR,F
		BTFSS	FSR,7
		GOTO	NEXT_B0
		
		MOVLW	0xA0
		MOVWF	FSR
NEXT_B1
		CLRF	INDF
		INCF	FSR,F
		BTFSS	STATUS,Z
		GOTO	NEXT_B1
		
		
		MOVLW	0x20;initialize pointer
		MOVWF	FSR	;to RAM
		BSF		STATUS,IRP
NEXT_B2
		CLRF	INDF
		INCF	FSR,F
		BTFSS	FSR,7
		GOTO	NEXT_B2
		BCF		STATUS,IRP	
;CLEAR RAM END	
;****************************************
	BANK3
		MOVLW   B'00000000';
		MOVWF	ANSEL^180H
		MOVLW   B'00000000';
		MOVWF	ANSELH^180H	
	
	BANK1
		CLRF	WPUB^80H		
	; ПОДТЯЖКА ВЫКЛ
	BANK0


        MOVLW   B'00100111';
        MOVWF   PORTA  ;

        MOVLW   B'00000000';
        MOVWF   PORTB  ;

        MOVLW   B'00000000';
        MOVWF   PORTC  ;
        
        MOVLW   B'00000000';
        MOVWF   PORTE ;

	BANK1
		MOVLW   B'00000111';
        MOVWF	TRISA^80H	
        
		MOVLW   B'00000000';        		
        MOVWF	TRISB^80H
		
		MOVLW   B'00000001';        
        MOVWF	TRISC^80H
 
 		MOVLW   B'00001000';        
        MOVWF	TRISE^80H
 
 
	BANK2

	movlw	b'11110100'
	movwf	CM2CON0^100H	


	movlw	b'11000010'
	movwf	CM2CON1^100H	
	
	BANK3
	
	movlw	b'00000001'
	movwf	SRCON^180H	


		BANK0 
;*****************************


;TIMER 1
		
        MOVLW   B'00000110';
        MOVWF	T1CON	; 

;adc

		BANK1 					; Select Bank 1
		MOVLW	b'00000000'; 	Fosc/16
		MOVWF	ADCON1^80		
		BANK0	


     	BANK1  

;				 >--------------PULL UP ENABLE(0) DISABLE(1)			
;				 |>-------------RB0 INT 1 to 0  (0)
;				 ||>------------TMR0 CONNECT TO CLK/4 (0)
;				 |||>-----------FOR TMR0  OF EXTERNAL INPUT FRONT
;				 ||||>----------PRESCALER TO TMR0 (0)     wdt(1)
;				 |||||>--\		   Prescaler 
;				 ||||||>-->-----; 1:128WDT, rising edge
;				 |||||||>/	
	movlw      b'11000101'

	movwf      OPTION_REG^80H	
;*****************
;TMR0 CONNECT TO CLK/4 = 2 000 000 Hz   Prescaler  = 32


; ПОКА ЕЩЕ БАНК 1

; 				 >--------------IRQ PSP			
;				 |>-------------IRQ AD
;				 ||>------------IRQ USART RX
;				 |||>-----------IRQ USART TX
;				 ||||>----------IRQ SPP
;				 |||||>---------IRQ CPP1
;				 ||||||>--------IRQ TMR2
;				 |||||||>-------IRQ TMR1	        
;		MOVLW  b'11110000'	;
		MOVLW  b'00000001'	;  IRQ MODULE
		MOVWF	PIE1^80		;
; 				 >--------------IRQ OSFIE			
;				 |>-------------IRQ C2IE
;				 ||>------------IRQ C1IE
;				 |||>-----------IRQ EEIE
;				 ||||>----------IRQ 
;				 |||||>---------IRQ 
;				 ||||||>--------IRQ 
;				 |||||||>-------IRQ 	        
;		MOVLW  b'00000000'	;
		MOVLW  b'00000000'	;  IRQ MODULE
		MOVWF	PIE2^80		;
		


; ПОКА ЕЩЕ БАНК 1
	
		BANK0 


	

; 				 >--------------IRQ ON			
;				 |>-------------IRQ ON PEREPHERIAL
;				 ||>------------IRQ ON TMR0 
;				 |||>-----------IRQ ON RB0 INT
;				 ||||>----------OFF CHANGE PORTB
;				 |||||>---------
;				 ||||||>--------
;				 |||||||>-------	        
		MOVLW  b'11100000'	; IRQ ON
		MOVWF	INTCON		;        
		BCF		FLAG_LCD_ON	
		
		BCF		FLAG_DEBUG_MODE	
		
		RETURN
; *********************************************************************

;****************************************************************************************
;****************************************************************************************
;from Anonymous Author 
;As a thank you for all the code, here is a 32x16 bit Mult.
;Unsigned 32 bit by 16 bit multiplication
;This routine will take Dividend2:Dividend3:Dividend4:Dividend5*bin1:bin2 -> Dividend:Dividend1:Dividend2:Dividend3:Dividend4:Dividend5

;mult_32_16:
; Dividend2:Dividend3:Dividend4:Dividend5 * bin1:bin2 -> Dividend:Dividend1:Dividend2:Dividend3:Dividend4:Dividend5

mult_32_16:

; Begin rearrange code
	nop
	movf	Dividend2,w
	movwf	Dividend
	movf	Dividend3,w
	movwf	Dividend1
	movf	Dividend4,w
	movwf	Dividend2
	movf	Dividend5,w
	movwf	Dividend3
; End rearrange code
                CLRF    Dividend4          ; clear partial product
                CLRF    Dividend5
                MOVF    Dividend,W
                MOVWF   AARGB0
                MOVF    Dividend1,W
                MOVWF   AARGB1
                MOVF    Dividend2,W
                MOVWF   AARGB2
                MOVF    Dividend3,W
                MOVWF   AARGB3

                MOVLW   0x08
                MOVWF   LOOPCOUNT

LOOPUM3216A:
                RRF     bin2, F
                BTFSC   STATUS, C
                GOTO    ALUM3216NAP
                DECFSZ  LOOPCOUNT, F
                GOTO    LOOPUM3216A

                MOVWF   LOOPCOUNT

LOOPUM3216B:
                RRF     bin1, F
                BTFSC   STATUS, C
                GOTO    BLUM3216NAP
                DECFSZ  LOOPCOUNT, F
                GOTO    LOOPUM3216B

                CLRF    Dividend
                CLRF    Dividend1
                CLRF    Dividend2
                CLRF    Dividend3
                RETLW   0x00

BLUM3216NAP:
                BCF     STATUS, C
                GOTO    BLUM3216NA

ALUM3216NAP:
                BCF     STATUS, C
                GOTO    ALUM3216NA

ALOOPUM3216:
                RRF     bin2, F
                BTFSS   STATUS, C
                GOTO    ALUM3216NA
                MOVF   AARGB3,W
                ADDWF   Dividend3, F
                MOVF    AARGB2,W
                BTFSC   STATUS, C
                INCFSZ  AARGB2,W
                ADDWF   Dividend2, F
                MOVF    AARGB1,W
                BTFSC   STATUS, C
                INCFSZ  AARGB1,W
                ADDWF   Dividend1, F
                MOVF    AARGB0,W
                BTFSC   STATUS, C
                INCFSZ  AARGB0,W
                ADDWF   Dividend, F

ALUM3216NA:
                RRF    Dividend, F
                RRF    Dividend1, F
                RRF    Dividend2, F
                RRF    Dividend3, F
                RRF    Dividend4, F
                DECFSZ  LOOPCOUNT, f
                GOTO    ALOOPUM3216

                MOVLW   0x08
                MOVWF   LOOPCOUNT

BLOOPUM3216:
                RRF    bin1, F
                BTFSS  STATUS, C
                GOTO   BLUM3216NA
                MOVF   AARGB3,W
                ADDWF  Dividend3, F
                MOVF   AARGB2,W
                BTFSC  STATUS, C
                INCFSZ AARGB2,W
                ADDWF  Dividend2, F
                MOVF   AARGB1,W
                BTFSC  STATUS, C
                INCFSZ AARGB1,W
                ADDWF  Dividend1, F
                MOVF   AARGB0,W
                BTFSC  STATUS, C
                INCFSZ AARGB0,W
                ADDWF  Dividend, F

BLUM3216NA
                RRF    Dividend, F
                RRF    Dividend1, F
                RRF    Dividend2, F
                RRF    Dividend3, F
                RRF    Dividend4, F
                RRF    Dividend5, F
                DECFSZ  LOOPCOUNT, F
                GOTO    BLOOPUM3216
	nop
	return

;*****************************************************
; bcd1:bcd2:bcd3:bcd4  * Dividend4:Dividend5:Dividend6:Dividend7 = Dividend:Dividend1:Dividend2:Dividend3:   Dividend4:Dividend5:Dividend6:Dividend7

MULTIPLY_32x32

        CLRF    Dividend         ; clear destination
        CLRF    Dividend1
        CLRF    Dividend2
        CLRF    Dividend3
        
        MOVLW   D'32'
        MOVWF   LOOPCOUNT        ; number of bits

        RRF     Dividend4,F     ; shift out to carry
        RRF     Dividend5,F     ; next multiplier bit
        RRF     Dividend6,F
        RRF     Dividend7,F

ADD_LOOP_32x32

        BTFSS   STATUS,C        ; if carry is set we must add multipland
                                ; to the product
          GOTO  SKIP_LOOP_32x32 ; nope, skip this bit
                
        MOVF    bcd4,W  ; get LSB of multiplicand
        ADDWF   Dividend3,F     ; add it to the lsb of the product
  
        MOVF    bcd3,W  ; middle byte
        BTFSC   STATUS,C        ; check carry for overflow
        INCFSZ  bcd3,W  ; if carry set we add one to the source 
        ADDWF   Dividend2,F     ; and add it  (if not zero, in
                                ; that case mulitpland = 0xff->0x00 )
        MOVF    bcd2,W    ; MSB byte
        BTFSC   STATUS,C        ; check carry
        INCFSZ  bcd2,W
        ADDWF   Dividend1,F       ; handle overflow
       
        MOVF    bcd1,W    ; MSB byte
        BTFSC   STATUS,C        ; check carry
        INCFSZ  bcd1,W
        ADDWF   Dividend,F       ; handle overflow


SKIP_LOOP_32x32
        ; note carry contains most significant bit of
        ; addition here

        ; shift in carry and shift out
        ; next multiplier bit, starting from less
        ; significant bit

        RRF     Dividend,F
        RRF     Dividend1,F
        RRF     Dividend2,F
        RRF     Dividend3,F
        RRF     Dividend4,F
        RRF     Dividend5,F
        RRF     Dividend6,F
        RRF     Dividend7,F

        DECFSZ  LOOPCOUNT,F
        GOTO    ADD_LOOP_32x32

        RETURN




;****************************************************
;****************************************************************************************
;24x24 multiplication 
;
;from Nikolai Golovchenko 
;
;        cblock
;        Product:6
;        Multipland:3
;        BitCount:1
;        endc
;
;Multiplier EQU Product+3  ;3 bytes shared with Product's
;                          ;less significant bytes (+3..5)

;MULTIPLY_24x24
        ; preload values to test
;        MOVLW   0xAB
;        MOVWF   Multipland
;        MOVLW   0xCD
;        MOVWF   Multipland+1
;        MOVLW   0xEF
;        MOVWF   Multipland+2
;
;        MOVLW   0x98
;        MOVWF   Multiplier
;        MOVLW   0x76
;        MOVWF   Multiplier+1
;        MOVLW   0x54
;        MOVWF   Multiplier+2

        ; these values should generate the reply = 0x6651AF33BC6C


;24 x 24 Multiplication
;Input:
; Multiplier - 3 bytes (shared with Product)
; Multiplicand - 3 bytes (not modified)
;Temporary:
; Bitcount
;Output:
; Product - 6 bytes


 ; bcd1:bcd2:bcd3 * Dividend3:Dividend5:Dividend5 = Dividend:Dividend1:Dividend2:Dividend3:Dividend4:Dividend5


MULTIPLY_24x24

        CLRF    Dividend         ; clear destination
        CLRF    Dividend1
        CLRF    Dividend2

        
        MOVLW   D'24'
        MOVWF   LOOPCOUNT        ; number of bits

        RRF     Dividend3,F     ; shift out to carry
        RRF     Dividend4,F     ; next multiplier bit
        RRF     Dividend5,F

ADD_LOOP_24x24

        BTFSS   STATUS,C        ; if carry is set we must add multipland
                                ; to the product
          GOTO  SKIP_LOOP_24x24 ; nope, skip this bit
                
        MOVF    bcd3,W  ; get LSB of multiplicand
        ADDWF   Dividend2,F     ; add it to the lsb of the product
  
        MOVF    bcd2,W  ; middle byte
        BTFSC   STATUS,C        ; check carry for overflow
        INCFSZ  bcd2,W  ; if carry set we add one to the source 
        ADDWF   Dividend1,F     ; and add it  (if not zero, in
                                ; that case mulitpland = 0xff->0x00 )
        
        MOVF    bcd1,W    ; MSB byte
        BTFSC   STATUS,C        ; check carry
        INCFSZ  bcd1,W
        ADDWF   Dividend,F       ; handle overflow

SKIP_LOOP_24x24
        ; note carry contains most significant bit of
        ; addition here

        ; shift in carry and shift out
        ; next multiplier bit, starting from less
        ; significant bit

        RRF     Dividend,F
        RRF     Dividend1,F
        RRF     Dividend2,F
        RRF     Dividend3,F
        RRF     Dividend4,F
        RRF     Dividend5,F

        DECFSZ  LOOPCOUNT,F
        GOTO    ADD_LOOP_24x24
        RETURN




;****************************************************
;max time in loop: 30 cycles

; Dividend:Dividend1 ....Dividend5 / AARGB0:AARGB1:AARGB2 =  Dividend:Dividend1 ....Dividend5

DIVIDE_48by24
        ; Test for zero division
        MOVF    AARGB0,W
        IORWF   AARGB1,W
        IORWF   AARGB2,W
        BTFSC   STATUS,Z
        RETLW   0x00    ; divisor = zero, not possible to calculate return with zero in w
        ; prepare used variables
        CLRF    bcd1
        CLRF    bcd2
        CLRF    bcd3

        clrf    ctr

        MOVLW   D'48'           ; initialize bit counter
        MOVWF   LOOPCOUNT

DIVIDE_LOOP_48by24
        RLF     Dividend5,F
        RLF     Dividend4,F
        RLF     Dividend3,F
        RLF     Dividend2,F
        RLF     Dividend1,F
        RLF     Dividend,F
        ; shift in highest bit from dividend through carry in temp
        RLF     bcd3,F
        RLF     bcd2,F
        RLF     bcd1,F

        rlf     ctr, f

        MOVF    AARGB2,W     ; get LSB of divisor
        btfsc   ctr, 7
        goto    Div48by24_add

        ; subtract 24 bit divisor from 24 bit temp
        SUBWF   bcd3,F        ; subtract

        MOVF    AARGB1,W     ; get middle byte
        SKPC                    ;  if overflow ( from prev.subtraction )
        INCFSZ  AARGB1,W     ; incresase source
        SUBWF   bcd2,F        ; and subtract from dest.

        MOVF    AARGB0,W       ; get top byte
        SKPC                    ;  if overflow ( from prev.subtraction )
        INCFSZ  AARGB0,W       ; increase source
        SUBWF   bcd1,F          ; and subtract from dest.

        movlw 1
        skpc
         subwf   ctr, f
        GOTO    DIVIDE_SKIP_48by24 ; carry was set, subtraction ok, continue with next bit

Div48by24_add
        ; result of subtraction was negative restore temp
        ADDWF   bcd3,F        ; add it to the lsb of temp

        MOVF    AARGB1,W     ; middle byte
        BTFSC   STATUS,C        ; check carry for overflow from previous addition
        INCFSZ  AARGB1,W     ; if carry set we add 1 to the source
        ADDWF   bcd2,F        ; and add it if not zero in that case Product+Multipland=Product

        MOVF    AARGB0,W       ; MSB byte
        BTFSC   STATUS,C        ; check carry for overflow from previous addition
        INCFSZ  AARGB0,W
        ADDWF   bcd1,F          ; handle overflow

        movlw 1
        skpnc
         addwf   ctr, f

DIVIDE_SKIP_48by24
        DECFSZ  LOOPCOUNT,F      ; decrement loop counter
        GOTO    DIVIDE_LOOP_48by24      ; another run
        ; finally shift in the last carry
        RLF     Dividend5,F
        RLF     Dividend4,F
        RLF     Dividend3,F
        RLF     Dividend2,F
        RLF     Dividend1,F
        RLF     Dividend,F
        RETLW   0x01    ; done

;****************************************************
;**********************************************************************

; Double Precision Multiplication
;
; BARGB0:BARGB1 * REMB0:REMB1 -> AARGB0:AARGB1:AARGB2:AARGB3
;
; Standard shift and add.
; Execution time: 215 to 295 clock cycles.
; Code space: 22 locations
;
; Cleaned up and corrected version from Microchip Ap note by BF.
; Note: Ap note has errors! Additional mods by Scott Dattalo.
;
;*******************************************************************

MUL_16_16
mpy16b16: 
		clrf 	AARGB0
		clrf 	AARGB1
		clrf 	AARGB2
		clrf 	AARGB3
		bsf 	AARGB2, 7
m1:
		rrf 	BARGB0, f
		rrf 	BARGB1, f
		skpc
		goto 	m2
		movf 	REMB1, w
		addwf 	AARGB1, f
		movf 	REMB0, w
		skpnc
		incfsz 	REMB0, w
		addwf 	AARGB0, f
m2:
		rrf 	AARGB0, f
		rrf 	AARGB1, f
		rrf 	AARGB2, f
		rrf 	AARGB3, f
		skpc
		goto 	m1

	RETURN
;*****************************************************************************
;*****************************************************************************
;The routine above is actually 24 by 15 bits division. Below is a 24 by 16 bits division routine: 

;Inputs:
;   Dividend - AARGB0:AARGB1:AARGB2 (0 - most significant!)
;   Divisor  - BARGB0:BARGB1
;Temporary:
;   Counter  - LOOPCOUNT
;   Remainder- REMB0:REMB1
;Output:
;   Quotient - AARGB0:AARGB1:AARGB2
;
;       Size: 28
; Max timing: 4+24*(6+6+4+3+6)-1+3+2=608 cycles (with return)
; Min timing: 4+24*(6+6+5+6)-1+3+2=560 cycles (with return)
FXD2416U:
        	CLRF 	REMB0
        	CLRF 	REMB1
        	MOVLW 	.24
        	MOVWF 	LOOPCOUNT
LOOPU2416
        	RLF 	AARGB2, F           ;shift left divider to pass next bit to remainder
        	RLF 	AARGB1, F           ;and shift in next bit of result
        	RLF 	AARGB0, F

        	RLF 	REMB1, F            ;shift carry into remainder
        	RLF 	REMB0, F

        	RLF 	LOOPCOUNT, F        ;save carry in counter
         
        	MOVF 	BARGB1, W          ;substract divisor from remainder
        	SUBWF 	REMB1, F
        	MOVF 	BARGB0, W
        	BTFSS 	STATUS,C
        	INCFSZ 	BARGB0, W
        	SUBWF 	REMB0, W          ;keep that byte in W untill we make sure about borrow

        	SKPNC                   ;if no borrow
         	BSF 	LOOPCOUNT, 0       ;set bit 0 of counter (saved carry)

        	BTFSC 	LOOPCOUNT, 0      ;if no borrow
         	GOTO 	UOK46LL           ;jump

        	MOVF 	BARGB1, W          ;restore remainder if borrow
        	ADDWF 	REMB1, F
        	MOVF 	REMB0, W           ;read high byte of remainder to W
                                ;to not change it by next instruction
UOK46LL
        	MOVWF 	REMB0             ;store high byte of remainder
        	CLRC                    ;copy bit 0 to carry
        	RRF 	LOOPCOUNT, F        ;and restore counter
        	DECFSZ 	LOOPCOUNT, F     ;decrement counter
         	GOTO 	LOOPU2416         ;and repeat loop if not zero
         
        	RLF 	AARGB2, F           ;shift in last bit of result
        	RLF 	AARGB1, F   
        	RLF 	AARGB0, F
        	RETURN
;**********************************************************************
;=====================================================
; Сохранение в еепром
;=====================================================
SAVE_EE
eewrite					; Write	to EEPROM
	movlw	.10			; попытка записи максимум 10 циклов 
	movwf	errors
write_2
	movf	ee_data, W
	BANK2
	movwf	EEDATA^100
	BANK0
	movf	ee_addr, W
	BANK2
	movwf	EEADR^100

	BANK3
	bcf	INTCON,	GIE		; Запретить прерывания
	bcf	EECON1^180,EEPGD
	bsf	EECON1^180,	WREN		; Разрешить запись
	movlw	55h
	movwf	EECON2^180
	movlw	0AAh
	movwf	EECON2^180
	bsf	EECON1^180,	WR		; Начать запись !
W_1
	clrwdt
	btfsc	EECON1^180,	WR
	goto	W_1

	bcf	EECON1^180,	WREN		; Запретить запись

	bsf	INTCON,	GIE

; Проверка записи
	BANK0
	movf	ee_data,W

	BANK3
	bcf	EECON1^180,EEPGD
	bsf	EECON1^180,	RD
	nop
	BANK2
	XORWF	EEDATA^100,W		; Проверка окончания записи
	BANK0
	btfsc	STATUS,	Z
	retlw	0			; Ok ! Запись произведена !

	decfsz	errors,F
	goto	write_2
	retlw	1			; Error  ! Запись  НЕ произведена !
;=====================================================
;****************************************************************************
SAVE_C_MODE_FRQ_OPORA

;>>>Сохраним 
		MOVLW	ADDR_C_MODE_FRQ_OPORA_ML_EE
		MOVWF	ee_addr
		MOVF	CLR_MODE_FRQ_OPORA_ML,W
		MOVWF	ee_data		
		CALL	SAVE_EE

		MOVLW	ADDR_C_MODE_FRQ_OPORA_ST_EE
		MOVWF	ee_addr
		MOVF	CLR_MODE_FRQ_OPORA_ST,W
		MOVWF	ee_data		
		CALL	SAVE_EE

		MOVLW	ADDR_C_MODE_FRQ_OPORA_UP_EE
		MOVWF	ee_addr
		MOVF	CLR_MODE_FRQ_OPORA_UP,W
		MOVWF	ee_data		
		CALL	SAVE_EE

		RETURN
;****************************************************************************
SAVE_R_MODE_FRQ_OPORA

		MOVLW	ADDR_R_MODE_FRQ_OPORA_ML_EE
		MOVWF	ee_addr
		MOVF	CLR_MODE_FRQ_OPORA_ML,W
		MOVWF	ee_data		
		CALL	SAVE_EE

		MOVLW	ADDR_R_MODE_FRQ_OPORA_ST_EE
		MOVWF	ee_addr
		MOVF	CLR_MODE_FRQ_OPORA_ST,W
		MOVWF	ee_data		
		CALL	SAVE_EE

		MOVLW	ADDR_R_MODE_FRQ_OPORA_UP_EE
		MOVWF	ee_addr
		MOVF	CLR_MODE_FRQ_OPORA_UP,W
		MOVWF	ee_data		
		CALL	SAVE_EE
		RETURN


;****************************************************************************
SAVE_L_MODE_FRQ_OPORA

		MOVLW	ADDR_L_MODE_FRQ_OPORA_ML_EE
		MOVWF	ee_addr
		MOVF	CLR_MODE_FRQ_OPORA_ML,W
		MOVWF	ee_data		
		CALL	SAVE_EE

		MOVLW	ADDR_L_MODE_FRQ_OPORA_ST_EE
		MOVWF	ee_addr
		MOVF	CLR_MODE_FRQ_OPORA_ST,W
		MOVWF	ee_data		
		CALL	SAVE_EE

		MOVLW	ADDR_L_MODE_FRQ_OPORA_UP_EE
		MOVWF	ee_addr
		MOVF	CLR_MODE_FRQ_OPORA_UP,W
		MOVWF	ee_data		
		CALL	SAVE_EE

		RETURN


;****************************************************************************

SAVE_C_NOMINAL_OPORA

; DEC
		MOVLW	.10
		SUBWF	CLR_NOMINAL_OPORA_ML,F
		BTFSS	STATUS,C
		DECF	CLR_NOMINAL_OPORA_ST,F
;>>>Сохраним 
		MOVLW	ADDR_C_NOMINAL_OPORA_ML_EE
		MOVWF	ee_addr
		MOVF	CLR_NOMINAL_OPORA_ML,W
		MOVWF	ee_data		
		CALL	SAVE_EE

		MOVLW	ADDR_C_NOMINAL_OPORA_ST_EE
		MOVWF	ee_addr
		MOVF	CLR_NOMINAL_OPORA_ST,W
		MOVWF	ee_data		
		CALL	SAVE_EE
		RETURN


;****************************************************************************
SAVE_R_NOMINAL_OPORA

; DEC
		MOVLW	.10
		SUBWF	CLR_NOMINAL_OPORA_ML,F
		BTFSS	STATUS,C
		DECF	CLR_NOMINAL_OPORA_ST,F
;>>>Сохраним 
		MOVLW	ADDR_R_NOMINAL_OPORA_ML_EE
		MOVWF	ee_addr
		MOVF	CLR_NOMINAL_OPORA_ML,W
		MOVWF	ee_data		
		CALL	SAVE_EE

		MOVLW	ADDR_R_NOMINAL_OPORA_ST_EE
		MOVWF	ee_addr
		MOVF	CLR_NOMINAL_OPORA_ST,W
		MOVWF	ee_data		
		CALL	SAVE_EE

		RETURN
;****************************************************************************
SAVE_L_NOMINAL_OPORA

; DEC
		MOVLW	.10
		SUBWF	CLR_NOMINAL_OPORA_ML,F
		BTFSS	STATUS,C
		DECF	CLR_NOMINAL_OPORA_ST,F
;>>>Сохраним 
		MOVLW	ADDR_L_NOMINAL_OPORA_ML_EE
		MOVWF	ee_addr
		MOVF	CLR_NOMINAL_OPORA_ML,W
		MOVWF	ee_data		
		CALL	SAVE_EE

		MOVLW	ADDR_L_NOMINAL_OPORA_ST_EE
		MOVWF	ee_addr
		MOVF	CLR_NOMINAL_OPORA_ST,W
		MOVWF	ee_data		
		CALL	SAVE_EE

		RETURN


;****************************************************************************
;****************************************************************************************** 
SET_TO_L_MODE
	BANK3
		MOVLW   B'00000011';
		MOVWF	ANSEL^180H
		MOVLW   B'00000000';
		MOVWF	ANSELH^180H	
	BANK2
	movlw	b'11110010'
	movwf	CM2CON1^100H	
	movlw	b'11110101'
	movwf	CM2CON0^100H	
	BANK1
	movlw	b'10000010'
	movwf	VRCON^80H
	BANK0
	BSF		L_MODE_ON	
	BCF		C_MODE_ON	

		MOVLW	ADDR_L_MODE_FRQ_OPORA_ML_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	CLR_MODE_FRQ_OPORA_ML

		MOVLW	ADDR_L_MODE_FRQ_OPORA_ST_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	CLR_MODE_FRQ_OPORA_ST


		MOVLW	ADDR_L_MODE_FRQ_OPORA_UP_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	CLR_MODE_FRQ_OPORA_UP


		MOVLW	ADDR_L_NOMINAL_OPORA_ML_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	CLR_NOMINAL_OPORA_ML

		MOVLW	ADDR_L_NOMINAL_OPORA_ST_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	CLR_NOMINAL_OPORA_ST

	GOTO	END_SET_TO_MODE
;****************************************************************************************** 
SET_TO_R_MODE
	BANK3
		MOVLW   B'00000011';
		MOVWF	ANSEL^180H
		MOVLW   B'00000000';
		MOVWF	ANSELH^180H	
	BANK2
	movlw	b'11110010'
	movwf	CM2CON1^100H	
	movlw	b'11110101'
	movwf	CM2CON0^100H	
	BANK1
	movlw	b'10000010'
	movwf	VRCON^80H
	BANK0
	BSF		L_MODE_ON	
	BCF		C_MODE_ON	

		MOVLW	ADDR_R_MODE_FRQ_OPORA_ML_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	CLR_MODE_FRQ_OPORA_ML

		MOVLW	ADDR_R_MODE_FRQ_OPORA_ST_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	CLR_MODE_FRQ_OPORA_ST


		MOVLW	ADDR_R_MODE_FRQ_OPORA_UP_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	CLR_MODE_FRQ_OPORA_UP


		MOVLW	ADDR_R_NOMINAL_OPORA_ML_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	CLR_NOMINAL_OPORA_ML

		MOVLW	ADDR_R_NOMINAL_OPORA_ST_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	CLR_NOMINAL_OPORA_ST
	GOTO	END_SET_TO_MODE
;****************************************************************************************** 
SET_TO_F_MODE
	BANK3
		MOVLW   B'00000011';
		MOVWF	ANSEL^180H
		MOVLW   B'00000000';
		MOVWF	ANSELH^180H	
	BANK2
	movlw	b'11110010'
	movwf	CM2CON1^100H	

	movlw	b'11110100'
	movwf	CM2CON0^100H	
	BANK1
	movlw	b'10000010'
	movwf	VRCON^80H
	BANK0
	BCF		L_MODE_ON	
	BCF		C_MODE_ON	
			RETURN
;****************************************************************************************** 
SET_TO_C_MODE
	BANK3
		MOVLW   B'00000011';
		MOVWF	ANSEL^180H
		MOVLW   B'00000000';
		MOVWF	ANSELH^180H	
	BANK2
	movlw	b'11110010'
	movwf	CM2CON1^100H	

	movlw	b'11110101'
	movwf	CM2CON0^100H	
	BANK1
	movlw	b'10000010'
	movwf	VRCON^80H
	BANK0
	BCF		L_MODE_ON	
	BSF		C_MODE_ON	


		MOVLW	ADDR_C_MODE_FRQ_OPORA_ML_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	CLR_MODE_FRQ_OPORA_ML

		MOVLW	ADDR_C_MODE_FRQ_OPORA_ST_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	CLR_MODE_FRQ_OPORA_ST


		MOVLW	ADDR_C_MODE_FRQ_OPORA_UP_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	CLR_MODE_FRQ_OPORA_UP


		MOVLW	ADDR_C_NOMINAL_OPORA_ML_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	CLR_NOMINAL_OPORA_ML

		MOVLW	ADDR_C_NOMINAL_OPORA_ST_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	CLR_NOMINAL_OPORA_ST

END_SET_TO_MODE

		CLRF	SAVE_COUNT_TIMER_1	
		CLRF	SAVE_TMR1H		
		CLRF	SAVE_TMR1L
		RETURN
;****************************************************************************
;**********************************************************************
LOAD_CONSTANT
		MOVLW	ADDR_MODE_EE 
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	MODE	

		RETURN
; *********************************************************************
; *********************************************************************
SAVE_POWER_BAT_LOW
		MOVLW	ADDR_POWER_BAT_LOW_EE 
		MOVWF	ee_addr
		MOVF	POWER_BAT_LOW,W
		MOVWF	ee_data		
		CALL	SAVE_EE
		RETURN
; *********************************************************************
SAVE_MODE_EE
		BCF		FLAG_SAVE_MODE	
		MOVLW	ADDR_MODE_EE 
		MOVWF	ee_addr
		MOVF	MODE,W
		MOVWF	ee_data		
		CALL	SAVE_EE
		RETURN
; *********************************************************************
; *********************************************************************				

;**********************************************************
LOAD_EE
LOAD_EEPROM
	movf	ee_addr, W
	BANK2
	movwf	EEADR^100
	BANK3
	bcf	EECON1^180,EEPGD
	bsf	EECON1^180,	RD
	nop
	BANK2
	MOVF	EEDATA^100,W
	BANK0	
	movwf	ee_data
	RETURN

;*********************************************
LOAD_POWER_BAT

		MOVLW	ADDR_POWER_BAT_LOW_EE
		MOVWF	ee_addr
		CALL	LOAD_EE
		MOVF	ee_data,W
		MOVWF	POWER_BAT_LOW
	RETURN

;*********************************************
; *****************************************************************************
LCD_WORK_OK	
		BSF 	SEG_1
		BSF 	SEG_2
		BSF 	SEG_3
		BSF 	SEG_4

		BCF		SEG_A
		BCF		SEG_B	
		BCF		SEG_C	
		BCF		SEG_D	
		BCF		SEG_E	
		BCF		SEG_F	
		BCF		SEG_G	
		BCF		SEG_H		

; покажем индикатор  полностью за 4 проходa
; узнаем номер прохода
ST_LCD_ON_OK		
		MOVF	cicle,W		; в W номер прохода
; табличное ветвление
		btfsc   STATUS,Z
		GOTO 	MCICLE1_OK
		
		MOVLW	.1
		XORWF	cicle,W	
		btfsc   STATUS,Z
		GOTO 	MCICLE2_OK
		
		MOVLW	.2
		XORWF	cicle,W	
		btfsc   STATUS,Z
		GOTO 	MCICLE3_OK

		MOVLW	.3
		XORWF	cicle,W	
		btfsc   STATUS,Z
		GOTO 	MCICLE4_OK

		clrf	cicle
		GOTO 	MCICLE1_OK
MCICLE1_OK
		BTFSS  	IND_1,7
		BSF		SEG_A
		BTFSS  	IND_1,6
		BSF		SEG_B	
		BTFSS  	IND_1,5
		BSF		SEG_C	
		BTFSS  	IND_1,4
		BSF		SEG_D	
		BTFSS  	IND_1,3
		BSF		SEG_E	
		BTFSS  	IND_1,2
		BSF		SEG_F	
		BTFSS  	IND_1,1
		BSF		SEG_G	
		BTFSS  	IND_1,0
		BSF		SEG_H	
; зажжем этот разряд
		BCF 	SEG_1
		NOP
		goto    ENDIND_OK
MCICLE2_OK
		BTFSS  	IND_2,7
		BSF		SEG_A
		BTFSS  	IND_2,6
		BSF		SEG_B	
		BTFSS  	IND_2,5
		BSF		SEG_C	
		BTFSS  	IND_2,4
		BSF		SEG_D	
		BTFSS  	IND_2,3
		BSF		SEG_E	
		BTFSS  	IND_2,2
		BSF		SEG_F	
		BTFSS  	IND_2,1
		BSF		SEG_G	
		BTFSS  	IND_2,0
		BSF		SEG_H	
; зажжем этот разряд
		BCF 	SEG_2
		NOP
		goto    ENDIND_OK
MCICLE3_OK
		BTFSS  	IND_3,7
		BSF		SEG_A
		BTFSS  	IND_3,6
		BSF		SEG_B	
		BTFSS  	IND_3,5
		BSF		SEG_C	
		BTFSS  	IND_3,4
		BSF		SEG_D	
		BTFSS  	IND_3,3
		BSF		SEG_E	
		BTFSS  	IND_3,2
		BSF		SEG_F	
		BTFSS  	IND_3,1
		BSF		SEG_G	
		BTFSS  	IND_3,0
		BSF		SEG_H	
; зажжем этот разряд
		BCF 	SEG_3
		NOP
		goto    ENDIND_OK
MCICLE4_OK
		BTFSS  	IND_4,7
		BSF		SEG_A
		BTFSS  	IND_4,6
		BSF		SEG_B	
		BTFSS  	IND_4,5
		BSF		SEG_C	
		BTFSS  	IND_4,4
		BSF		SEG_D	
		BTFSS  	IND_4,3
		BSF		SEG_E	
		BTFSS  	IND_4,2
		BSF		SEG_F	
		BTFSS  	IND_4,1
		BSF		SEG_G	
		BTFSS  	IND_4,0
		BSF		SEG_H	
		
		
		BTFSS	FLAG_FLASH_DP4
		GOTO	MCICLE4_1_OK
		
		BSF		SEG_H
		BTFSS	COUNT_OFF_ML,7
		BCF		SEG_H		
		
		
MCICLE4_1_OK		
; зажжем этот разряд
		BCF 	SEG_4
		NOP
		goto    ENDIND_OK	
ENDIND_OK

		INCF	cicle,F 	; Счетчик проходов увеличим	
		MOVLW	.4
		XORWF	cicle,W
		BTFSC	STATUS,Z
		CLRF	cicle
;********************************		
;	На индикаторе состояние рама
;********************************
		RETURN
;***************************************************************************************************
TEST_INDIKATOR

;>>>
	BANK1
		BSF		WPUB^80H,WPUB2		
		BSF		TRISB^80H,2

		BCF		OPTION_REG^80H ,7
	BANK0



		BCF		SEG_1


		CALL	Delay_mKSA

;		BANK3
;		BSF		ANSELH^180H,ANS8
;		BANK0		
;


;******************************

		BANK1 					; Select Bank 1
		MOVLW	b'00000000'; 	Fosc/16
		MOVWF	ADCON1^80		
		BANK0	

		MOVLW	b'11100001'
		MOVWF	ADCON0			; LEFT, Fosc/16, CH 8  , ADC EN    

    	CALL	Delay_mKSA

		
		BSF		ADCON0,GO_DONE	; START DAC
WAIT_CH2_DAC
		BTFSC	ADCON0,GO_DONE
		GOTO	WAIT_CH2_DAC	
							; DAC-OK

;		MOVF	ADRESH,W

		BSF			FLAG_INVERT_INDIKATOR

		MOVLW	.220
		SUBWF	ADRESH,W
		
		BTFSC	STATUS,C

		BCF			FLAG_INVERT_INDIKATOR
;***********************************

	BANK1
		BCF		WPUB^80H,WPUB2		
		BCF		TRISB^80H,2

		BSF		OPTION_REG^80H ,7
	BANK0

		BANK3
		BCF		ANSELH^180H,ANS8
		BANK0

;********************************************

;		BSF	FLAG_INVERT_INDIKATOR


		BTFSS	FLAG_INVERT_INDIKATOR
		GOTO	INIT_01
		

INIT_02

		BCF		SEG_A
		BCF		SEG_B	
		BCF		SEG_C	
		BCF		SEG_D	
		BCF		SEG_E	
		BCF		SEG_F	
		BCF		SEG_G	
		BCF		SEG_H

		CALL	Delay_1SA	

		clrf	COUNT_PRESS_KEY
		CLRF	COUNT_PRESS_KEY_2
		CLRF	COUNT_PRESS_KEY_ST

; ВКЛЮЧИМСЯ 

		BSF			FLAG_LCD_ON	
		BSF			POWER_ON
; заставка
		MOVLW	b'01110001' ; F
		MOVWF	IND_1

		MOVLW	b'11100011' ; L
		MOVWF	IND_2

		MOVLW	b'01100011' ; C
		MOVWF	IND_3

		MOVLW	b'11110101'	; r
		MOVWF	IND_4

		RETURN
;*****************************

INIT_01

		CALL	Delay_1SA	

		clrf	COUNT_PRESS_KEY
		CLRF	COUNT_PRESS_KEY_2
		CLRF	COUNT_PRESS_KEY_ST

; ВКЛЮЧИМСЯ 

		BSF			FLAG_LCD_ON	
		BSF			POWER_ON
; заставка
		MOVLW	b'01110001' ; F
		MOVWF	IND_1

		MOVLW	b'11100011' ; L
		MOVWF	IND_2

		MOVLW	b'01100011' ; C
		MOVWF	IND_3

		MOVLW	b'11110101'	; r
		MOVWF	IND_4

		RETURN	

;************************************************************************	
Delay_mKSA
		MOVLW	.13	
	    MOVWF  DELAY_COUNTER_1
DELAY_CIKLE2A:
        decfsz  DELAY_COUNTER_1,F
        goto    DELAY_CIKLE2A
        return 


Delay_1SA
		MOVLW 	.10
		MOVWF	DELAY_COUNTER_3
WAITS_1SA		
		CALL	Delay_100mSA	
		DECFSZ	DELAY_COUNTER_3,F
		GOTO	WAITS_1SA
		RETURN
;**********************************************************************
Delay_100mSA
		MOVLW	.100	
        MOVWF   DELAY_COUNTER_2
	    CLRF   DELAY_COUNTER_1
DELAY_CIKLE1A:
		NOP
		NOP
		NOP
		NOP
		NOP

		NOP
		NOP
		NOP
		NOP
		NOP
		
		NOP
		NOP
		NOP
		NOP
		NOP		

		NOP

        decfsz  DELAY_COUNTER_1,F
        goto    DELAY_CIKLE1A
        decfsz  DELAY_COUNTER_2,F
        goto    DELAY_CIKLE1A

        
        return 
;**********************************************************************

	
		ORG 0x1000
;************************************************************************	
		nop







;************************************************************************
;************************************************************************
;************************************************************************


	ORG	0x2100				; data EEPROM location

	DE	0x00		;	MODE    		
	DE	0x20		;	ADDR_POWER_BAT_LOW_EE	EQU     0x0E




	DE	0xA0			;ADDR_C_MODE_FRQ_OPORA_ML_EE		EQU     0x02
	DE	0x86			;ADDR_C_MODE_FRQ_OPORA_ST_EE		EQU     0x03
	DE	0x01			;ADDR_C_MODE_FRQ_OPORA_UP_EE		EQU     0x04
			;
	DE	0xFB; 			;ADDR_L_MODE_FRQ_OPORA_ML_EE		EQU     0x05
	DE	0x38; 			;ADDR_L_MODE_FRQ_OPORA_ST_EE		EQU     0x06
	DE	0x01; 			;ADDR_L_MODE_FRQ_OPORA_UP_EE		EQU     0x07
			;;
	DE	0x88			;ADDR_R_MODE_FRQ_OPORA_ML_EE		EQU     0x08
	DE	0x8A			;ADDR_R_MODE_FRQ_OPORA_ST_EE		EQU     0x09
	DE	0x01			;ADDR_R_MODE_FRQ_OPORA_UP_EE		EQU     0x0A
			;
			;
	DE	0x94			;ADDR_C_NOMINAL_OPORA_ML_EE		EQU     0x0B
	DE	0x11			;ADDR_C_NOMINAL_OPORA_ST_EE		EQU     0x0C
			;
	DE	0xA0			;ADDR_L_NOMINAL_OPORA_ML_EE		EQU     0x0D
	DE	0x02			;ADDR_L_NOMINAL_OPORA_ST_EE		EQU     0x0E
			;
	DE	0x80			;ADDR_R_NOMINAL_OPORA_ML_EE		EQU     0x0F
	DE	0x07			;ADDR_R_NOMINAL_OPORA_ST_EE		EQU     0x10
			;
	DE	0x00			;ADDR_C_KORRECTOR_KOF_ML_EE		EQU     0x11
	DE	0x00			;ADDR_C_KORRECTOR_KOF_ST_EE		EQU     0x12
			;
			;
	DE	0x00			;ADDR_L_KORRECTOR_KOF_ML_EE		EQU     0x13
	DE	0x00			;ADDR_L_KORRECTOR_KOF_ST_EE		EQU     0x14
			;
			;
	DE	0x00			;ADDR_R_KORRECTOR_KOF_ML_EE		EQU     0x15
	DE	0x00			;ADDR_R_KORRECTOR_KOF_ST_EE		EQU     0x16
;








	DE	0x00		;
	DE	0x00		;	



	DE	0x00		;	
	DE	0x00		;	
	DE	0x00		;
	DE	0x00		;	

	DE	0x00		;				 			
	DE	0x00		;							
	DE	0x00		;
	DE	0x00		;

	DE	0x00		;
	DE	0x00		;
	DE	0x00		;	
	DE	0x00		;	









	DE	1,2,3,4	

	DE	1,2,3,4	
	DE	1,2,3,4	
	DE	1,2,3,4	
	DE	1,2,3,4	


	DE "by GARMASH G.V."
	DE "31-03-2011"
	DE "VER 2.1.0"
	DE "+38-095-576-98-14"

	END                       ; directive 'end of program'

