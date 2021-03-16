*-----------------------------------------------------------
* Title      : 
* Written by : Logan and Victor  
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000
START:                  ; first instruction of program 

stack   EQU     $000A0000
shift   EQU     $C
task1   EQU     $01
task2   EQU     $02
task5   EQU     $05
task13  EQU     $0D
task14  EQU     $0E
input_Y EQU     $59
input_yl EQU     $79
input_N EQU     $4E
input_nl EQU     $4E
linesOnScreen   EQU     29
bufferSize   EQU      64   
right12     EQU     12      ; Extract op code
right8      EQU     8       ; Extract 2nd nibble
right6      EQU     6       ; Extract dest mode
right4      EQU     4       ; Extract 3rd Nibble
right3      EQU     3       ; Extract the scr mode

nibble2     EQU     $0F00   ; Extract 2nd nibble
nibble3     EQU     $00F0   ; Extract 3rd nibble
destmode    EQU     $01C0   ; Extract the dest mode
srcmode     EQU     $0038   ; Extract the scr mode
size        EQU     $00C0   ; Extract the size

MAIN:
        LEA     stack, SP
WELCOME: 
        LEA     WELCOME_MESS, A1
        MOVE.B  #task14,D0
        TRAP    #15             Display  Openning Message 

; ----------------------------------------------------------------------------
;   User Interface 
; ----------------------------------------------------------------------------  
USER_INPUT:
        JMP     START_ADDR
        
RESTART_PROGRAM: 
        MOVEQ   #0,D1
        MOVEA.L #$0, A1
        MOVEA.L #$0, A3
        MOVEA.L #$0, A5
        MOVEA.L #$0, A6
        MOVEQ   #0,D3       
        MOVEQ   #0,D0
        MOVEQ   #0,D2
        JSR     CLEAR_SCREEN
        
START_ADDR:
        MOVEQ   #0,D2
        ; Prompt a start address
        LEA     START_MESS, A1
        MOVE.B  #task14,D0
        TRAP    #15           Display  Start_Addr Message

        MOVEA.L #$0, A1 
        ; read a start address 
        MOVE.B  #task2,D0     Gets input from the user
        TRAP    #15
        
        JSR     ATOI
        
        ; Validate start address       
        MOVEQ   #0,D1
        CMP.L   #-1,D3
        BEQ     ERROR_START_ADDR
        
                        
        ROR.L   #1, D3          ; Checks for odd number
        BCS     ERROR_START_ADDR
        ROL.L   #1, D3
        MOVEA.L D3,A5           ; A5 = start address
        ADDQ    #2,D2        
END_ADDR:         
        ; Prompt end address
        MOVEQ   #0,D3       ; Reset D3 Register
        MOVEQ   #0,D1
        
        LEA     END_MESS, A1
        MOVE.B  #task14,D0
        TRAP    #15           Display  END_Addr Message
        
        MOVEA.L #$0, A1 
        MOVE.B  #task2,D0     Gets input from the user
        TRAP    #15
        
        ; Read the end address
        JSR     ATOI
        MOVEQ   #0,D1
        CMP.L   #-1,D3
        BEQ     ERROR_END_ADDR
        
        ; Validate end address & check if its greater than start
        ROR.L   #1, D3
        BCS     ERROR_START_ADDR
        ROL.L   #1, D3
        
        CMP.L   #$000FFFFFF, D3 
        BGE     ERROR_END_ADDR
        
        MOVEQ   #2, D1
        CMP.L   D3, A5 
        BGE     ERROR_END_ADDR
        MOVEA.L D3,A6       ; A6 = end address
        ADDQ    #2,D2
        JMP     DECODE_LOOP
      
; ----------------------------------------------------------------------------
;   OP Code Start
; ----------------------------------------------------------------------------          
DECODE_START: 
        CLR.L   D2      ; D2 = Screen line counter
           
DECODE_LOOP:
        ; Decoding the current address
        MOVEA.L A3, A4      ; Save the current start address of the string we are printing 
        JSR     OP_START
        
        MOVE.B  #$00, (A3)+
        MOVEA.L A4, A1      
        MOVE.B  #task13, D0     ; Printing out decoded instruction 
        TRAP    #15
        
        ; Check if a decode finished
        CMP.L   A5, A6          ; Checks if the program is done
        BLE     REPEAT_PROGRAM
        
        ; Check if the screen filled
        ADDQ.B  #1,D2           ; Adds one to the total # of lines on the screen 
        CMP.B   #linesOnScreen, D2  ; Check if it exceds the max 
        BEQ     DECODE_PAUSE

        BRA     DECODE_LOOP
        
DECODE_PAUSE:   
        LEA     MAX_SCREEN_OUTPUT,  A1
        MOVE.B  #task14, D0     ; Display the input that it exceeds 
        TRAP    #15 
        
        MOVE.B  #task5, D0      ; Ask for the user to input to continue 
        TRAP    #15
        
        ; Branch b/c user enter any key 
        JSR     CLEAR_SCREEN
        ; Program is is ready to continue the program
        BRA     DECODE_START
        
CLEAR_SCREEN: 
        ; Clear output for the screen 
        CLR.L   D2
        LEA     BLANK,  A1
        MOVE.B  #task13, D0     ; Display the input that it exceeds 
        TRAP    #15 
        RTS
           
OP_START: 
        MOVEM.L  D2/A6, -(SP)    ; D2 (Screen line), A6 Ending Address
        
        JSR     OP_DATA_CLR
        ; LEA     A3, buffer    ; Loads the message in 
        
        LEA      OP_JMP_TABLE, A0
        CLR.L    D0
        CLR.L    D1
        MOVE.W   (A5)+,D0       ; Loads current word instruction to D0
        
        ; Load long address into D7 
        MOVE.L   (A5)+,D7
        
        ; Back it up 32 bits 
        SUB.L    #$4, A5
        
        MOVE.L   D0,D1          ; Move word instruct to D1
        MOVE.B   #right12, D2   
        LSR.W    D2, D1         ; D1 = op code
        MULU     #6,D1          ; Computing jmp displacement
        JMP      0(A0,D1)       ; 
       
OP_FINISH: 
        MOVEM.L (SP)+,D2/A6,
        JSR     OP_MOVECALC 
        RTS

OP_MOVECALC: 
        CMP.B   #4, D4      ; Move 32 bits of data
        BEQ     OP_MOVE32

        CMP.B   #1, D4      ; Move 32 bits of data
        BEQ     OP_MOVE32
       
        CMP.B   #2, D4       ; Move 16 bits of data
        BEQ     OP_MOVE16
        RTS                 ; Move 0 bits of data
        
OP_MOVE32:                  ; #2
        ADD.L   #$4, A5
        RTS
        
OP_MOVE16:                  ; #1
        ADD.L   #$2, A5
        RTS
         
;-------------------------------------------
    ;According to instructions, need to 
    ;clear buffer before decoding questions 
;-------------------------------------------
OP_DATA_CLR: 
        CLR.L   D3
        MOVE.B  #bufferSize ,D3
        LEA     buffer,A3
        
        JSR     OP_DATA_CLR_LOOP
        
        MOVEA.L A3, A4      ; Save the start of the address  
        RTS
        
OP_DATA_CLR_LOOP:
        MOVEA.L $0, A3
        MOVE.B  #0,(A3)+
        SUBI    #1,D3
        BGT     OP_DATA_CLR_LOOP
        RTS
        
REPEAT_PROGRAM: 
        ; Output text to continue 
        LEA     REPEAT_MESS, A1
        MOVE.B  #task14,D0
        TRAP    #15           Display  message asking to repeat 
        
        CLR.L   D1
        ; Ask for input 
        MOVEA.L #$0, A1 
        ; read a start address 
        MOVE.B  #task5,D0     Gets input from the user
        TRAP    #15
        ; If y = go to user input
        CMP.W   #input_Y, D1
        BEQ     RESTART_PROGRAM_START

        CMP.W   #input_yl, D1
        BEQ     RESTART_PROGRAM_START        
        ; if n = stop program. 
        
        CMP.W   #input_N, D1
        BEQ     END_PROGRAM
        
        CMP.W   #input_nl, D1
        BEQ     END_PROGRAM
        
        ; Error Retry: 
        MOVEA.L #$0, A1 
        LEA     INVALID_MESS, A1
        MOVE.B  #task14,D0
        TRAP    #15           Display  Error Message
        
        JMP     REPEAT_PROGRAM
        
RESTART_PROGRAM_START: 
        JSR     CLEAR_SCREEN
        JMP     RESTART_PROGRAM
        
END_PROGRAM: 
       JMP      DONE 
    
OP_JMP_TABLE:
        JMP     INDEX0000        ; ORI
        JMP     INDEX0001        ; MOVE BYTE
        JMP     INDEX0010        ; MOVE WORD / MOVEA
        JMP     INDEX0011        ; MOVE LONG / MOVEA
        JMP     INDEX0100        ; NOP, MOVEM, LEA
        JMP     INDEX0101        ; ADDQ
        JMP     INDEX0110        ; BRA, BSR
        JMP     INDEX0111        ; MOVEQ
        JMP     INDEX1000        ; DIVU
        JMP     INDEX1001        ; SUB
        JMP     INDEX1010
        JMP     INDEX1011        ; CMP 
        JMP     INDEX1100        ; MULU
        JMP     INDEX1101        ; ADD, ADDA
        JMP     INDEX1110        ; ASL, ASR
        JMP     INDEX1111        ; Unsupported    

; ------------------------------------
;   OP ORI 
; ------------------------------------        
INDEX0000: 
        LEA   OP_0000_TABLE, A0  
        CLR.L   D1
        CLR.L   D2
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #nibble2,D1         ; Extract 2nd nibble
        MOVE.B  #right8, D2         
        LSR.W   D2,D1               ; D1 = 2nd nibble
        MULU    #6,D1               
        JMP      0(A0,D1)
        
; ------------------------------------
;   OP MOVE.B 
; ------------------------------------
INDEX0001: 
        CLR.L   D3
        MOVE.B   #1, D3        ; byte size
        MOVE.B  #'M', (A3)+
        MOVE.B  #'O', (A3)+
        MOVE.B  #'V', (A3)+    
        MOVE.B  #'E', (A3)+
        MOVE.B  #'.', (A3)+ 
        MOVE.B  #'B', (A3)+
        
        ; Call MOVE EA 
        JSR     MOVEA_EA
        JMP     OP_FINISH
        
; ------------------------------------
;   OP MOVEA / MOVE long
; ------------------------------------
INDEX0010:
        CLR.L   D3
        CLR.L   D2
        MOVE.B   #4, D3        ; Long  size
        
        MOVE.B  #'M', (A3)+
        MOVE.B  #'O', (A3)+
        MOVE.B  #'V', (A3)+
        MOVE.B  #'E', (A3)+
        
        CLR.L   D1
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #destmode,D1         ; Extract dest mode
        MOVE.B  #right6, D2         
        LSR.W   D2,D1 

        CMP.B   #1, D1
        BEQ     OP_MOVEAL               

        MOVE.B  #'.', (A3)+
        MOVE.B  #'L', (A3)+
        
        ; Call MOVE EA
        JSR     MOVEA_EA
        JMP     OP_FINISH
        
; ------------------------------------
;   OP MOVEA / MOVE word  
; ------------------------------------
INDEX0011:
        CLR.L   D3
        CLR.L   D1
        CLR.L   D2
        MOVE.B   #2, D3        ; word 
        
        MOVE.B  #'M', (A3)+
        MOVE.B  #'O', (A3)+
        MOVE.B  #'V', (A3)+
        MOVE.B  #'E', (A3)+
        
        MOVE.L  D0,D1                ; Current instruct word
        ANDI.W  #destmode,D1         ; Extract dest mode
        MOVE.B  #right6, D2         
        LSR.W   D2,D1 
        
        CMP.B   #1, D1
        BEQ     OP_MOVEAW
        
        MOVE.B  #'.', (A3)+
        MOVE.B  #'W', (A3)+
        
        ; Call MOVE EA
        JSR     MOVEA_EA
        JMP     OP_FINISH
        
; ------------------------------------
;   OP  NOP, MOVEM, LEA 
; ------------------------------------ 
INDEX0100: 
        CLR.L   D1
        CLR.L   D2
        LEA     OP_01000_TABLE, A0
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #nibble2,D1         ; Extract 2nd nibble
        MOVE.B  #right8, D2         
        LSR.W   D2,D1               ; D1 = 2nd nibble
        MULU    #6,D1               
        JMP      0(A0,D1)           ; JMP to table

; -------------------------------
;   OP ADDQ / SUBQ  
; --------------------------------
INDEX0101:
        CLR.L   D1 
        CLR.L   D2
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #nibble2,D1         ; Extract 2nd nibble
        MOVE.B  #right8, D2         
        LSR.W   D2,D1               ; D1 = 2nd nibble
    
        ANDI.B  #1, D1
        BEQ     OP_SUBQ             ; If last bit = 1 --> SUBQ 
        BNE     OP_ADDQ             ; If lat bit = 0 --> ADDQ
        
        
; ------------------------------------
;   OP BRA,BSR  
; ------------------------------------
INDEX0110: 
        LEA     OP_0110_TABLE, A0
        
        CLR.L   D2
        CLR.L   D1
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #nibble2,D1         ; Extract 2nd nibble
        MOVE.B  #right8, D2         
        LSR.W   D2,D1               ; D1 = 2nd nibble
        MULU    #6,D1               
        JMP     0(A0,D1)

; ------------------------------------
;   OP MOVEQ --> DONE
; ------------------------------------
INDEX0111: 
        CLR.L   D3
        MOVE.B   #4, D3        ; long 
        
        JSR     MOVEQ_EA
        JMP     OP_FINISH

; ----------------------------------------------------------
;   OP DIVU, DIVS   -->  DONE
; ---------------------------------------------------------
INDEX1000: 
        CLR.L   D3
        MOVE.B   #2, D3        ; word
        
        CLR.L   D1
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #$0100,D1         ; Extract 2nd nibble
        MOVE.B  #right8, D2         
        LSR.W   D2,D1               ; D1 = 2nd nibble

        CMP.B  #1, D1
        BEQ     OP_DIVS           ; If last bit = 1 --> DIVS 
        BNE     OP_DIVU            ; If lat bit = 0 --> DIVU
                
; ------------------------------------
;   OP SUB --> Need to Implement
; ------------------------------------ 
INDEX1001: 
        MOVE.B  #'S', (A3)+
        MOVE.B  #'U', (A3)+
        MOVE.B  #'B', (A3)+  
        MOVE.B  #'.', (A3)+   

        JMP     OP_SUB

; ------------------------------------
;   OP Code not supported 
; ------------------------------------         
INDEX1010: 
        JMP     OP_UNSUPPORTED
        
; ------------------------------------
;   OP CMP --> Forgot to do this one lol 
; ------------------------------------         
INDEX1011: 
        MOVE.B  #'C', (A3)+
        MOVE.B  #'M', (A3)+
        MOVE.B  #'P', (A3)+
        MOVE.B  #'.', (A3)+
        
        CLR.L   D1 
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #size,D1         ; Extract 2nd nibble
        MOVE.B  #right8, D2         
        LSR.W   D2,D1               ; D1 = 2nd nibble
        
        JMP     OP_CMP
        
; ------------------------------------
;   OP MULU --> Done
; ------------------------------------ 
INDEX1100: 
        MOVE.B  #'M', (A3)+
        MOVE.B  #'U', (A3)+
        MOVE.B  #'L', (A3)+    
        
        CLR.L   D3
        MOVE.B   #2, D3

        CLR.L   D1
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #$100,D1         ; Extract 2nd nibble
        MOVE.B  #right8, D2         
        LSR.W   D2,D1               ; 
        
        CMP.B   #1, D1
        BEQ     OP_MULS  
        BNE     OP_MULU
        
; ------------------------------------
;   OP ADD,ADDA     --> Needs a lot of work 
; ------------------------------------
INDEX1101:
        CLR.L   D1 
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #size,D1         ; Extract dest mode
        MOVE.B  #right6, D2         
        LSR.W   D2,D1
    
        CMP.B   #3,D1
        BEQ     OP_ADDA
        BNE     OP_ADD
        
; ------------------------------------
;   OP ASL,ASR    --> Figure out Rotation 
; ------------------------------------ 
INDEX1110:       

        ; Extract the size (7 -8 )
        CLR.L   D1 
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #size,D1         ; Extract 2nd nibble
        MOVE.B  #right6, D2             
        LSR.W   D2,D1               ; 
        
        CLR.L   D3
        MOVE.B   D1, D3 

        CMP.B #3, D3 
        BEQ     INDEX1110_MEM

        JMP     OP_ROTATION_CHECK
INDEX1110_MEM:
        ; Memory Register Shift 11  
        LEA     OP_1110_TABLE, A0  
        CLR.L   D1
        CLR.L   D2
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #nibble2,D1         ; Extract 2nd nibble
        MOVE.B  #right8, D2         
        LSR.W   D2,D1               ; D1 = 2nd nibble
        MULU    #6,D1               
        JMP     0(A0,D1)
; ------------------------------------
;   OP Code not supported 
; ------------------------------------         
INDEX1111:
        JMP     OP_UNSUPPORTED
        
; ------------------------------------
;   JUMP Tables for OP codes 
; ------------------------------------         
OP_0000_TABLE: 
        JMP     OP_ORI              ; 0: ORI
        JMP     OP_UNSUPPORTED      ; 1: Not supported  
        JMP     OP_UNSUPPORTED      ; 2: Not supported      ANDI
        JMP     OP_UNSUPPORTED      ; 3: Not supported      
        JMP     OP_UNSUPPORTED      ; 4: Not supported      SUBI
        JMP     OP_UNSUPPORTED      ; 5: Not supported
        JMP     OP_UNSUPPORTED      ; 6: Not supported      ADDI
        JMP     OP_UNSUPPORTED      ; 7: Not supported
        JMP     OP_UNSUPPORTED      ; 8: Not supported
        JMP     OP_UNSUPPORTED      ; 9: Not supported
        JMP     OP_UNSUPPORTED      ; A: Not supported      EORI
        JMP     OP_UNSUPPORTED      ; B: Not supported
        JMP     OP_UNSUPPORTED      ; C: Not supported      CMPI
        JMP     OP_UNSUPPORTED      ; D: Not supported
        JMP     OP_ERROR            ; E: Not supported      INVALID
        JMP     OP_UNSUPPORTED      ; F: Not supported  

OP_01000_TABLE: 
        JMP     OP_UNSUPPORTED      ; 0: Not supported      MOVE to SR , NEGX
        JMP     OP_LEA              ; 1: LEA An = 0   
        JMP     OP_UNSUPPORTED      ; 2: Not supported      CLR
        JMP     OP_LEA              ; 3: LEA An = 1      
        JMP     OP_UNSUPPORTED      ; 4: Not supported      NEG , MOVE to CCR    
        JMP     OP_LEA              ; 5: LEA An = 2     
        JMP     OP_UNSUPPORTED      ; 6: Not supported      NOT      
        JMP     OP_LEA              ; 7: LEA An = 3
        JMP     OP_MOVEM0           ; 8: MOVEM D = 0     
        JMP     OP_LEA              ; 9: LEA An = 4
        JMP     OP_UNSUPPORTED      ; A: Not supported      
        JMP     OP_LEA              ; B: LEA An = 5
        JMP     OP_MOVEM1           ; C: MOVEM D = 1      
        JMP     OP_LEA              ; D: LEA An = 6
        JMP     OP_NOP_RTS_RTE      ; E: NOP, RTE,RTS, STOP    
        JMP     OP_LEA              ; F: LEA An = 7
    
OP_0110_TABLE: 
        JMP     OP_BRA              ; 0: BRA
        JMP     OP_BSR              ; 1: BSR  
        JMP     OP_UNSUPPORTED      ; 2: Not supported      BHI
        JMP     OP_UNSUPPORTED      ; 3: Not supported      BLS
        JMP     OP_UNSUPPORTED      ; 4: Not supported      BCC
        JMP     OP_UNSUPPORTED      ; 5: Not supported      BCS
        JMP     OP_UNSUPPORTED      ; 6: Not supported      BNE
        JMP     OP_UNSUPPORTED      ; 7: Not supported      BEQ
        JMP     OP_UNSUPPORTED      ; 8: Not supported      BVC
        JMP     OP_UNSUPPORTED      ; 9: Not supported      BVS
        JMP     OP_UNSUPPORTED      ; A: Not supported      BPL
        JMP     OP_UNSUPPORTED      ; B: Not supported      BMI
        JMP     OP_UNSUPPORTED      ; C: Not supported      BGE
        JMP     OP_UNSUPPORTED      ; D: Not supported      BLT
        JMP     OP_UNSUPPORTED      ; E: Not supported      BGT
        JMP     OP_UNSUPPORTED      ; F: Not supported      BLE
        
OP_1110_TABLE: 
        JMP     OP_ASR_M              ; 0: ASR
        JMP     OP_ASL_M              ; 1: ASL  
        JMP     OP_UNSUPPORTED      ; 2: Not Supported      LSR     
        JMP     OP_UNSUPPORTED      ; 3: Not Supported      LSL      
        JMP     OP_UNSUPPORTED      ; 4: Not Supported      ROXR     
        JMP     OP_UNSUPPORTED      ; 5: Not supported      ROXL      
        JMP     OP_UNSUPPORTED      ; 6: Not supported      ROR
        JMP     OP_UNSUPPORTED      ; 7: Not supported      ROL
        JMP     OP_ERROR            ; 8: Error     
        JMP     OP_ERROR            ; 9: Error       
        JMP     OP_ERROR            ; A: Error       
        JMP     OP_ERROR            ; B: Error        
        JMP     OP_ERROR            ; C: Error        
        JMP     OP_ERROR            ; D: Error        
        JMP     OP_ERROR            ; E: Error        
        JMP     OP_ERROR            ; F: Error        

;---------------------------------------------------
; ORI. Gathering instruct size and calling EA
;-------------------------------------------------      
OP_ORI:
        CLR.L   D1
        MOVE.B  #'O', (A3)+
        MOVE.B  #'R', (A3)+
        MOVE.B  #'I', (A3)+
        MOVE.B  #'.', (A3)+
        
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #size,D1         ; Extract 2nd nibble
        MOVE.B  #right6, D2         
        LSR.W   D2,D1               ; D1 = 2nd nibble

        CMP.B   #0,D1       
        BEQ     HELPER_ORIB             ;--> BYTE
        
        CMP.B   #1, D1      ;--> Word
        BEQ     HELPER_ORIW
        
        CMP.B   #2, D1      ; --> Long
        BEQ     HELPER_ORIL
        
        
HELPER_ORIB:
        CLR.L   D3
        MOVE.B   #1, D3
        MOVE.B  #'B', (A3)+
             
        JSR     IMMEDIATE_EA  
        JMP     OP_FINISH
    
HELPER_ORIW:
        CLR.L   D3
        MOVE.B   #2, D3
        MOVE.B  #'W', (A3)+
    
        JSR     IMMEDIATE_EA   
        JMP     OP_FINISH
        
HELPER_ORIL:
        CLR.L   D3
        MOVE.B   #4, D3
        MOVE.B  #'L', (A3)+
    
        JSR     IMMEDIATE_EA     
        JMP     OP_FINISH
;---------------------------------------------------
; MOVEA . calling EA
;-------------------------------------------------         
OP_MOVEAW: 
        MOVE.B  #'A', (A3)+
        MOVE.B  #'.', (A3)+
        MOVE.B  #'W', (A3)+

        JSR     MOVEA_EA
        JMP     OP_FINISH
        
OP_MOVEAL: 
        MOVE.B  #'A', (A3)+
        MOVE.B  #'.', (A3)+
        MOVE.B  #'L', (A3)+

        ; Call EA for MOVEA
        JSR     MOVEA_EA
        JMP     OP_FINISH
   
;---------------------------------------------------
; LEA . calling EA
;-------------------------------------------------        
OP_LEA: 
        MOVE.B  #'L', (A3)+
        MOVE.B  #'E', (A3)+
        MOVE.B  #'A', (A3)+
    
        ; Long Size 
        CLR.L   D3
        MOVE.B   #4, D3
       
        ; Call EA for LEA 
        JSR     LEA_EA
        JMP     OP_FINISH
        
;---------------------------------------------------
; MOVEM . calling EA and calculating instruct SIZE
;-------------------------------------------------      
OP_MOVEM1: 
        MOVE.B  #'M', (A3)+
        MOVE.B  #'O', (A3)+
        MOVE.B  #'V', (A3)+
        MOVE.B  #'E', (A3)+
        MOVE.B  #'M', (A3)+
        MOVE.B  #'.', (A3)+
        
        CLR.L   D4
        MOVE.B   #1, D4
        
        BRA     MOVEM_SIZE_CALC 
OP_MOVEM0: 
        MOVE.B  #'M', (A3)+
        MOVE.B  #'O', (A3)+
        MOVE.B  #'V', (A3)+
        MOVE.B  #'E', (A3)+
        MOVE.B  #'M', (A3)+
        MOVE.B  #'.', (A3)+    
        
        CLR.L   D4
        MOVE.B   #0, D4
        
        BRA     MOVEM_SIZE_CALC  

MOVEM_SIZE_CALC: 
        CLR.L   D1
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #$0040,D1         ; Extract S 
        MOVE.B  #right6, D2         
        LSR.W   D2,D1               ; 
        
        CMP.B   #0, D1
        BEQ     MOVEM_W
        
        CMP.B   #1, D1
        BEQ     MOVEM_L
        
MOVEM_W: 
        MOVE.B  #'W', (A3)+
        CLR.L   D3 
        MOVE.B   #2,D3 
        
        ; CALL MOVEM EA
        JSR     MOVEM_EA
        JMP     OP_FINISH
        
MOVEM_L: 
        MOVE.B  #'L', (A3)+
        CLR.L   D3 
        MOVE.B   #4,D3 
        
        ; CALL MOVEM EA 
        JSR     MOVEM_EA
        JMP     OP_FINISH       
;---------------------------------------------------
; NOP, RTS, RTE, STOP
;-------------------------------------------------      
OP_NOP_RTS_RTE: 
        CLR.L   D1
        MOVE.L  D0,D1               ; Current instruct word
        
        ; Check third 3 nibble for 0111 if not error 
        ANDI.W  #$0FF0, D1
        MOVE.B  #right4, D2         
        LSR.W   D2,D1               ; D1 = 2nd nibble
        
        CMP.W   #$E70, D1
        BEQ     OP_ERROR
        
        CLR.L   D1
        MOVE.L  D0,D1               ; Current instruct word
        
        ; Check last 4 bits 
        ANDI.W  #$000F, D1

        CMP.B   #1, D1       NOP --> 0001 
        BEQ     OP_NOP

        CMP.B   #2, D1       NOP --> 0001 
        BEQ     OP_STOP
        
        CMP.B   #3, D1      RTE --> 0011 
        BEQ     OP_RTE

        CMP.B   #5, D1      RTS --> 0101
        BEQ     OP_RTS       

        JMP     OP_ERROR    ERROR CODE

OP_NOP: 
        MOVE.B  #'N', (A3)+
        MOVE.B  #'O', (A3)+
        MOVE.B  #'P', (A3)+
        
        ; Loop back into OP Decode
        JMP     OP_FINISH
OP_STOP: 
        MOVE.B  #'S', (A3)+
        MOVE.B  #'T', (A3)+
        MOVE.B  #'O', (A3)+
        MOVE.B  #'P', (A3)+     

        JMP     OP_FINISH   
OP_RTE: 
        MOVE.B  #'R', (A3)+
        MOVE.B  #'T', (A3)+
        MOVE.B  #'E', (A3)+
        
        JMP     OP_FINISH
OP_RTS: 
        MOVE.B  #'R', (A3)+
        MOVE.B  #'T', (A3)+
        MOVE.B  #'S', (A3)+
        
        JMP     OP_FINISH
        
;---------------------------------------------------
; SUBQ and ADDQ. Gathering instruct size and calling EA
;-------------------------------------------------        
OP_SUBQ: 
        MOVE.B  #'S', (A3)+
        MOVE.B  #'U', (A3)+
        MOVE.B  #'B', (A3)+
        MOVE.B  #'Q', (A3)+
        MOVE.B  #'.', (A3)+         
        JMP     HELPER__ADDSUBQ_SIZE_CAL      
        
        
OP_ADDQ:    
        MOVE.B  #'A', (A3)+
        MOVE.B  #'D', (A3)+
        MOVE.B  #'D', (A3)+
        MOVE.B  #'Q', (A3)+
        MOVE.B  #'.', (A3)+         
        JMP     HELPER__ADDSUBQ_SIZE_CAL

HELPER__ADDSUBQ_SIZE_CAL:
        CLR.L   D1 
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #size,D1         ; Extract 2nd nibble
        MOVE.B  #right6, D2         
        LSR.W   D2,D1               ; D1 = 2nd nibble
        
        CLR.L   D3
        MOVE.B   D1, D3  

        CMP.B   #2, D3
        BEQ     HELPER_ADDSUBQ_CONVERT_L
        
        CMP.B   #1, D3
        BEQ     HELPER_ADDSUBQ_CONVERT_W
        
        CMP.B   #0, D3   
        BEQ     HELPER_ADDSUBQ_CONVERT_B
        
HELPER_ADDSUBQ_CONVERT_L: 
        CLR.L   D3
        MOVE.B  #4, D3 
        MOVE.B  #'L', (A3)+   
        
        ; CALL EA 
        JSR     ADDQ_EA
        JMP     OP_FINISH
        
HELPER_ADDSUBQ_CONVERT_W: 
        CLR.L   D3
        MOVE.B  #2, D3 
        MOVE.B  #'W', (A3)+   
        
        ; CALL EA
        JSR     ADDQ_EA
        JMP     OP_FINISH  
      
HELPER_ADDSUBQ_CONVERT_B: 
        CLR.L   D3
        MOVE.B  #1, D3 
        MOVE.B  #'B', (A3)+ 
        
        ; CALL EA  
        JSR     ADDQ_EA
        JMP     OP_FINISH
;---------------------------------------------------
; SUB. Gathering instruct size and calling EA
;-------------------------------------------------  
OP_SUB:
        JMP     HELPER_SUB_SIZE_CAL

HELPER_SUB_SIZE_CAL:
        CLR.L   D1 
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #size,D1         ; Extract 2nd nibble
        MOVE.B  #right6, D2         
        LSR.W   D2,D1               ; D1 = 2nd nibble
        
        CLR.L   D3
        MOVE.B   D1, D3  

        CMP.B   #2, D3
        BEQ     HELPER_SUB_CONVERT_L
        
        CMP.B   #1, D3
        BEQ     HELPER_SUB_CONVERT_W
        
        CMP.B   #0, D3   
        BEQ     HELPER_SUB_CONVERT_B
        
HELPER_SUB_CONVERT_L: 
        CLR.L   D3
        MOVE.B  #4, D3 
        MOVE.B  #'L', (A3)+   

        ; CALL EA  
        JSR     SUB_EA
        JMP     OP_FINISH  
        
HELPER_SUB_CONVERT_W: 
        CLR.L   D3
        MOVE.B  #2, D3 
        MOVE.B  #'W', (A3)+   

        ; CALL EA
        JSR     SUB_EA
        JMP     OP_FINISH  
        
HELPER_SUB_CONVERT_B: 
        CLR.L   D3
        MOVE.B  #1, D3 
        MOVE.B  #'B', (A3)+   

        ; CALL EA
        JSR     SUB_EA
        JMP     OP_FINISH    
      
;---------------------------------------------------
; ADDA. Gathering instruct size and calling EA
;-------------------------------------------------       
OP_ADDA: 
        MOVE.B  #'A', (A3)+
        MOVE.B  #'D', (A3)+
        MOVE.B  #'D', (A3)+
        MOVE.B  #'A', (A3)+
        MOVE.B  #'.', (A3)+
        
        ; Calculate instruct size
        CLR.L   D1
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #$100,D1         ; Extract 2nd nibble
        MOVE.B  #right8, D2         
        LSR.W   D2,D1               ; 
        
        CMP.B   #1, D1
        BEQ     HELPER_ADDA_L
        BNE     HELPER_ADDA_W
        ; EA Calculator 
HELPER_ADDA_L: 
        CLR.L   D3
        MOVE.B   #4, D3 
        MOVE.B   #'L', (A3)+
        
        ;CALL EA
        JSR     ADDA_EA
        JMP     OP_FINISH 
        
HELPER_ADDA_W: 
        CLR.L   D3
        MOVE.B  #2, D3 
        MOVE.B  #'W', (A3)+

        ;CALL EA
        JSR     ADDA_EA
        JMP     OP_FINISH 
;---------------------------------------------------
; ADD. Gathering instruct size and calling EA
;-------------------------------------------------       
OP_ADD: 
        MOVE.B  #'A', (A3)+
        MOVE.B  #'D', (A3)+
        MOVE.B  #'D', (A3)+
        MOVE.B  #'.', (A3)+
        
        ; Calculate instruct size
        
HELPER_ADD_SIZE_CAL:
        CLR.L   D1 
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #size,D1         ; Extract 2nd nibble
        MOVE.B  #right6, D2         
        LSR.W   D2,D1               ; 
        
        CLR.L   D3
        MOVE.B   D1, D3  

        CMP.B   #2, D3
        BEQ     HELPER_ADD_CONVERT_L
        
        CMP.B   #1, D3
        BEQ     HELPER_ADD_CONVERT_W
        
        CMP.B   #0, D3   
        BEQ     HELPER_ADD_CONVERT_B
                
HELPER_ADD_CONVERT_L: 
        CLR.L   D3
        MOVE.B  #4, D3 
        MOVE.B  #'L', (A3)+   

        ; CALL EA  
        JSR     ADD_EA
        JMP     OP_FINISH 
        
HELPER_ADD_CONVERT_W: 
        CLR.L   D3
        MOVE.B  #2, D3 
        MOVE.B  #'W', (A3)+   

        ; CALL EA
        JSR     ADD_EA
        JMP     OP_FINISH
        
HELPER_ADD_CONVERT_B: 
        CLR.L   D3
        MOVE.B  #1, D3 
        MOVE.B  #'B', (A3)+   

        ; CALL EA
        JSR     ADD_EA
        JMP     OP_FINISH             
;---------------------------------------------------
; BSR. Gathering instruct size and calling EA
;-------------------------------------------------         
OP_BSR:    
        MOVE.B  #'B', (A3)+
        MOVE.B  #'S', (A3)+
        MOVE.B  #'R', (A3)+
 
        JSR     BSR_EA
        JMP     OP_FINISH
        
;---------------------------------------------------
; BRA   Check. Gathering instruct size and calling EA
;------------------------------------------------- 
OP_BRA:    
        MOVE.B  #'B', (A3)+
        MOVE.B  #'R', (A3)+
        MOVE.B  #'A', (A3)+
     
        ; Call BRA EA 
        JSR     BRA_EA
        JMP     OP_FINISH
        
;---------------------------------------------------
; MULU  calling EA
;------------------------------------------------- 
OP_MULU: 
        MOVE.B  #'U', (A3)+

        ; Call EA
        JSR     MULU_EA
        JMP     OP_FINISH

;---------------------------------------------------
; MULS  calling EA
;------------------------------------------------- 
OP_MULS: 
        MOVE.B  #'S', (A3)+

        ; Call EA
        JSR     MULU_EA
        JMP     OP_FINISH        
        
;---------------------------------------------------
; DIVS   calling EA
;------------------------------------------------- 
OP_DIVS: 
        MOVE.B  #'D', (A3)+
        MOVE.B  #'I', (A3)+
        MOVE.B  #'V', (A3)+
        MOVE.B  #'S', (A3)+
        
        ; Call EA
        JSR     DIVS_EA
        JMP     OP_FINISH
;---------------------------------------------------
; DIVU   calling EA
;------------------------------------------------- 
OP_DIVU:
        MOVE.B  #'D', (A3)+
        MOVE.B  #'I', (A3)+
        MOVE.B  #'V', (A3)+
        MOVE.B  #'U', (A3)+
        
        ; Call EA
        JSR     DIVU_EA
        JMP     OP_FINISH
;------------------------------------------------
; CMP   calling EA and finding size
;------------------------------------------------ 
OP_CMP: 
      JMP   HELPER_CMP_SIZE_CAL   
     
HELPER_CMP_SIZE_CAL:         
        CLR.L   D3
        MOVE.B   D1, D3  

        CMP.B   #2, D3
        BEQ     HELPER_CMP_CONVERT_L
        
        CMP.B   #1, D3
        BEQ     HELPER_CMP_CONVERT_W
        
        CMP.B   #0, D3   
        BEQ     HELPER_CMP_CONVERT_B
        
HELPER_CMP_CONVERT_L: 
        CLR.L   D3
        MOVE.B  #4, D3 
        MOVE.B  #'L', (A3)+   
        ; CALL EA   
        JSR     CMP_EA
        JMP     OP_FINISH
        
HELPER_CMP_CONVERT_W: 
        CLR.L   D3
        MOVE.B  #2, D3 
        MOVE.B  #'W', (A3)+   
        ; CALL EA
        JSR     CMP_EA
        JMP     OP_FINISH
        
HELPER_CMP_CONVERT_B: 
        CLR.L   D3
        MOVE.B  #1, D3 
        MOVE.B  #'B', (A3)+ 
  
        ; CALL EA
        JSR     CMP_EA
        JMP     OP_FINISH

;---------------------------------------------------
; ASL   Memory Shift only word size 
;-------------------------------------------------             
OP_ASL_M: 
        MOVE.B  #'A', (A3)+
        MOVE.B  #'S', (A3)+
        MOVE.B  #'L', (A3)+ 
        CLR.L   D3
        MOVE.B  #2, D3 
        ; Get ready to call Mode 7 subclass 1
        
;---------------------------------------------------
; ASR    Memory Shift only word size 
;------------------------------------------------- 
OP_ASR_M: 
        MOVE.B  #'A', (A3)+
        MOVE.B  #'S', (A3)+
        MOVE.B  #'R', (A3)+ 
        
        CLR.L   D3
        MOVE.B  #2, D3 
        ; Get ready to call Mode 7 subclass 1
        
*-------------------------------------------------
*  Rotation Checker, Mainly looking for ASL/ASR
*------------------------------------------------        
OP_ROTATION_CHECK: 
       ; Check the 4 - 5 bit for 00 
        CLR.L   D1 
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #$18,D1         ; Extract 2nd nibble
        MOVE.B  #3, D2         
        LSR.W   D2,D1    
        
        CMP.B   #0, D1      ; AS
        BEQ     OP_ROTATION_HELP
        
        CMP.B   #1, D1      ; LS
        BEQ     OP_UNSUPPORTED

        CMP.B   #2, D1      ; ROXd
        BEQ     OP_UNSUPPORTED
        
        CMP.B   #3, D1      ; ROXd
        BEQ     OP_UNSUPPORTED   
 
OP_ROTATION_HELP: 
        ; Find the Rotation 
        ; Extract the size 
        CLR.L   D1 
        MOVE.L  D0,D1               ; Current instruct word
        ANDI.W  #$100,D1         ; Extract 2nd nibble
        MOVE.B  #right8, D2             
        LSR.W   D2,D1  

        CMP.B   #0, D1      ; Right Rotation 
        BEQ     OP_ASR_ADDER
        
        CMP.B   #1, D1      ; Left rotation
        BEQ     OP_ASL_ADDER
        
OP_ROTATION_SIZE_HELP:        
        ; Check the size 
        CMP.B   #2, D3
        BEQ     OP_ROTATION_SIZE_L    
        
        CMP.B   #1, D3
        BEQ     OP_ROTATION_SIZE_W   
        
        CMP.B   #0, D3
        BEQ     OP_ROTATION_SIZE_B 
        
        
OP_ROTATION_SIZE_B: 
        CLR.L   D3
        MOVE.B  #1, D3     
        MOVE.B  #'.', (A3)+
        MOVE.B  #'B', (A3)+
        
        JSR     ASL_EA
        JMP     OP_FINISH
        
OP_ROTATION_SIZE_W: 
        CLR.L   D3
        MOVE.B  #2, D3 
        MOVE.B  #'.', (A3)+
        MOVE.B  #'W', (A3)+
        
        JSR     ASL_EA
        JMP     OP_FINISH
        
OP_ROTATION_SIZE_L:
        CLR.L   D3
        MOVE.B  #4, D3  
        MOVE.B  #'.', (A3)+
        MOVE.B  #'L', (A3)+
        
        JSR     ASL_EA
        JMP     OP_FINISH
        
OP_ASL_ADDER: 
        MOVE.B  #'A', (A3)+
        MOVE.B  #'S', (A3)+
        MOVE.B  #'L', (A3)+    
        
        JMP     OP_ROTATION_SIZE_HELP 
        
OP_ASR_ADDER: 
        MOVE.B  #'A', (A3)+
        MOVE.B  #'S', (A3)+
        MOVE.B  #'R', (A3)+    
        
        JMP     OP_ROTATION_SIZE_HELP  
;--------------------------------------------------
; Error Handling    
;------------------------------------------------- 
OP_UNSUPPORTED: 
        LEA     DECODE_OP_UNSUPPORT, A1
        MOVE.B  #task14,D0
        TRAP    #15           Display  Error Message
        JMP     OP_FINISH
        
OP_ERROR: 
        LEA     DECODE_OP_ERROR, A1
        MOVE.B  #task14,D0
        TRAP    #15           Display  Error Message
        JMP     OP_FINISH
              
;--------------------------------------------------
; Effective Address Start   
;------------------------------------------------- 

;----------------------------------------------
;IMMEDIATE_EA for ORI,ANDI,SUBI,ADDI
    *D1 = # of ITOA Loop ITERATION
    *D3 = size of instruct
    *D0 = Shift Data
    *D5 = Mode
    *D6 = Register
    *D7 = current immediate data
;----------------------------------------------    
IMMEDIATE_EA
        ; Extract dst mode and register
        JSR     MOVE_IMM_DATA
        
        MOVE.L D0, D6       ; Register    
        
        MOVE.B  D3, D0
        CLR.L   D6
        ANDI.W  #$7,D6
        
        CLR.L   D5
        MOVE.L  D0,D5               ; Current instruct word
        ANDI.W  #$38,D5              
        MOVE.B  #$3, D0            
        LSR.W   D0,D5               ; Extract the Mode      
         
        CMP.B   #1, D5          ; Check for valid dst 
        BEQ     DATA_ERROR    
        
        MOVE.B  D3,D1
        MULU    #2, D3          ; Iteration Byte = 2 ITOA Loops, Word = 4 ITOA Loops, Long = 8 Loops 
 
        MOVE.B  #' ', (A3)+
        MOVE.B  #'#', (A3)+
        MOVE.B  #'$', (A3)+
        
        ; Call ITOA 
        JSR     ITOA
        
        MOVE.B  #',', (A3)+
        MOVE.B  #' ', (A3)+
        
        JSR     EA_DECODER
        RTS
        
MOVE_IMM_DATA: 
        CLR.L   D4
        CMP.B   #2, D3
        BEQ     SHIFT16
        
        CMP.B   #1, D3
        BEQ     SHIFT24 
        
        MOVE.B  #4, D4
        RTS
        
SHIFT16: 
        LSR.L   #8,D7
        LSR.L   #8,D7
        MOVE.B  #2, D4
        RTS

SHIFT24
        LSR.L   #8,D7
        LSR.L   #8,D7
        MOVE.B  #4, D4  
        RTS
        
MOVEA_EA
        ;This is the same as MOVE, just that first operand is for sure an address.
        JMP MOVE_EA

MOVE_EA
        MOVE.L D0, D5
        MOVE.L D0, D6
        
        ;and off mode
        ANDI #56, D5
        ASR.L #3, D5
        ;and off data
        ANDI #7, D6
        JSR EA_DECODER
    
        MOVE.B #',', (A3)+
    
        ; Grab the other mode
        MOVE.L D0, D5
        MOVE.L D0, D6
    
        ;and off mode
        ANDI #448, D5
        ASR.L #6, D5
        ;and off data
        ANDI #3584, D6
        ASR.L #8, D6
        ASR.L #1, D6
        JSR EA_DECODER
    
        RTS

MOVEM_EA
        ;check if we're reading from or writing to memory.
        MOVE.W D0, D5
        ANDI #1024, D5
        CMP #0, D5
        BEQ MOVEM_EA_TO_MEM
        CMP #1024, D5
        BEQ MOVEM_EA_TO_MEM
    
        ;Error-handling return
        RTS
    
MOVEM_EA_TO_MEM

MOVEM_EA_FROM_MEM


MOVEQ_EA
        MOVE.L D0, D5
        MOVE.L D0, D6
    
        ;set mode to immediate
        MOVE #7, D0
        ;and off data
        ANDI #255, D7
        JSR EA_DECODER
    
        MOVE.B #',', (A3)+

        MOVE.L D0, D5
        MOVE.L D0, D6
    
        ;set mode to data register
        CLR.L D5
        ;and off data
        ANDI #3584, D6
        ASR.L #8, D6
        ASR.L #1, D6
        JSR EA_DECODER
    
        RTS

LEA_EA
        MOVE.L D0, D5
        MOVE.L D0, D6
    
        ;and off mode
        ANDI #448, D5
        ASR.L #6, D5
        ;and off data
        ANDI #3584, D6
        ASR.L #8, D6
        ASR.L #1, D6
        JSR EA_DECODER
    
        MOVE.B #',', (A3)+
    
        ; Grab the other mode
        MOVE.L D0, D5
        MOVE.L D0, D6
    
        ;and off mode
        ANDI #56, D5
        ASR.L #3, D5
        ;and off data
        ANDI #7, D6
        JSR EA_DECODER
    
        RTS
    
BRA_EA
        ;Effectively the same as BRA
        JMP BSR_EA

BSR_EA
        ;Its some form of move 7
        MOVE #7, D5
        CLR.L D6
    
        MOVE D0, D7
        ANDI #255, D7
        CMP #$FF, D7
        BEQ BSR_EA_32

        JSR EA_DECODER
    
        RTS

BSR_EA_32
        MOVE #1, D6
        RTS
    
DIVU_EA
        ;Practically the same as DIVS
        JMP DIVS_EA

DIVS_EA
        MOVE.L D0, D5
        MOVE.L D0, D6
    
        ;and off mode
        ANDI #448, D5
        ASR.L #6, D5
        ;and off data
        ANDI #3584, D6
        ASR.L #8, D6
        ASR.L #1, D6
        JSR EA_DECODER
    
        MOVE.B #',', (A3)+
    
        ; Grab the other mode
        MOVE.L D0, D5
        MOVE.L D0, D6
    
        ;and off mode
        ANDI #56, D5
        ASR.L #3, D5
        ;and off data
        ANDI #7, D6
        JSR EA_DECODER
    
        RTS

SUB_EA
        MOVE.L D0, D5
        MOVE.L D0, D6
    
        ;and off mode
        ANDI #56, D5
        ;and off data
        ANDI #7, D6
        JSR EA_DECODER
        MOVE.L D0, D6
    
        MOVE.B #',', (A3)+
    
        ;sub only works on data registers, so we set mode to data
        CLR.L D5
        ;and off data
        ANDI #3584, D6
        JSR EA_DECODER

        RTS

ADDQ_EA
        ;For EA effectively SUBQ
        JMP SUBQ_EA

SUBQ_EA
        MOVE.L D0, D5
        MOVE.L D0, D7
    
        ;set mode immediate
        CLR.L D5
        ;and off data for immediate
        ANDI #3584, D7
        ASR.L #8, D6
        ASR.L #1, D6
        JSR EA_DECODER
    
        MOVE.B #',', (A3)+
    
        MOVE.L D0, D5
        MOVE.L D0, D6
    
        ;and off mode
        ANDI #56, D5
        ASR.L #3, D5
        ;and off data
        ANDI #7, D6
        JSR EA_DECODER
    
        RTS

CMP_EA
        MOVE.L D0, D5
        MOVE.L D0, D6
    
        ;and off mode
        ANDI #56, D5
        ;and off data
        ANDI #7, D6
        JSR EA_DECODER
            
        MOVE.B #',', (A3)+
    
        ;Do other part of the EA
        MOVE.L D0, D5
        MOVE.L D0, D6
    
        ;set mode to data register
        CLR.L D5
        ;and off data
        ANDI #3584, D6
        ASR.L #8, D6
        ASR.L #1, D6
        JSR EA_DECODER

        RTS

MULU_EA
        MOVE.L D0, D5
        MOVE.L D0, D7
    
        ;Get mode
        ANDI #56, D5
        ASR.L #3, D5
        ;and off data
        ANDI #7, D6
        JSR EA_DECODER
   
        MOVE.B #',', (A3)+
    
        MOVE.L D0, D5
        MOVE.L D0, D6
    
        ;set mode data register
        CLR.L D5
        ;and off data for immediate
        ANDI #3584, D7
        ASR.L #8, D6
        ASR.L #1, D6
        JSR EA_DECODER
    
        MOVE.L D0, D5
        MOVE.L D0, D6


ADD_EA
        ;Effective the same as ADD
        JMP ADDA_EA

ADDA_EA
        MOVE.L D0, D5
        MOVE.L D0, D6
    
        ;and off mode
        ANDI #448, D5
        ASR.L #8, D5
        ;and off data
        ANDI #3584, D6
        ASR.L #8, D6
        ASR.L #1, D6
        JSR EA_DECODER
    
        MOVE.B #',', (A3)+
    
        ; Grab the other mode
        MOVE.L D0, D5
        MOVE.L D0, D6
    
        ;and off mode
        ANDI #56, D5
        ASR.L #3, D5
        ;and off data
        ANDI #7, D6
        JSR EA_DECODER
    
        RTS

ASL_EA
        ;Practically the same as DIVS
        JMP ASR_EA

ASR_EA
        ;Check bit 5 to see if its a register or count.
        MOVE D0, D5
        ANDI #32, D5
        ASR.L #5, D5
        CMP #0, D5
        BEQ ASR_EA_NUM
        CMP #1, D5
        BEQ ASR_EA_REG
    
        ;Error-handling return
        RTS
    
ASR_EA_NUM
        ;Set to immediate data;
        MOVE #7, D5
        ;Missing something here.
        JSR EA_DECODER
    
        MOVE.B #',', (A3)+
    
        ;Set to data register
        CLR.L D5
        MOVE D0, D6
        AND #7, D6
        JSR EA_DECODER    

ASR_EA_REG
        ;Set to data register
        CLR.L D5
        MOVE D0, D6
        AND #3584, D6
        ASR.L #8, D6
        ASR.L #1, D6
        JSR EA_DECODER  
    
        MOVE.B #',', (A3)+
    
        ;Set to data register
        CLR.L D5
        MOVE D0, D6
        AND #7, D6
        JSR EA_DECODER    


EA_DECODER:
        ;Add space.
        MOVE.B #' ', (A3)+
        ;Jump to the Mode given.
        LEA EAJUMPTABLE, A0
        MULU #6, D5
        JMP 0(A0,D5)
        
    ;   This is a jump table that will jump to certain sub-functions based on what the mode is.
EAJUMPTABLE
        JMP MODE0       
        JMP MODE1      
        JMP MODE2       
        JMP MODE3       
        JMP MODE4       
        JMP MODE5       
        JMP MODE6       
        JMP MODE7      
    
MODE0
        ;Implement ITOA
        
        
        ; Figure the  that relate to it op codes 
        
        CMP #0, D6
        BEQ APPEND_D0
    
        CMP #1, D6
        BEQ APPEND_D1
    
        CMP #2, D6
        BEQ APPEND_D2
    
        CMP #3, D6
        BEQ APPEND_D3
    
        CMP #4, D6
        BEQ APPEND_D4
        
        CMP #5, D6
        BEQ APPEND_D5
    
        CMP #6, D6
        BEQ APPEND_D6
    
        CMP #7, D6
        BEQ APPEND_D7
    
        ;Return
        RTS

MODE1
        CMP #0, D6
        BEQ APPEND_A0
    
        CMP #1, D6
        BEQ APPEND_A1
    
        CMP #2, D6
        BEQ APPEND_A2
    
        CMP #3, D6
        BEQ APPEND_A3
    
        CMP #4, D6
        BEQ APPEND_A4
    
        CMP #5, D6
        BEQ APPEND_A5
    
        CMP #6, D6
        BEQ APPEND_A6
    
        CMP #7, D6
        BEQ APPEND_A7
    
        ;Return
        RTS

MODE2
        CMP #0, D6
        BEQ APPEND_A0
    
        CMP #1, D6
        BEQ APPEND_A1
    
        CMP #2, D6
        BEQ APPEND_A2
    
        CMP #3, D6
        BEQ APPEND_A3
    
        CMP #4, D6
        BEQ APPEND_A4
    
        CMP #5, D6
        BEQ APPEND_A5
    
        CMP #6, D6
        BEQ APPEND_A6
    
        CMP #7, D6
        BEQ APPEND_A7
    
        ;Return
        RTS

MODE3
        MOVE.B #'(', (A3)+

        CMP #0, D6
        BEQ APPEND_A0
    
        CMP #1, D6
        BEQ APPEND_A1
    
        CMP #2, D6
        BEQ APPEND_A2
    
        CMP #3, D6
        BEQ APPEND_A3
    
        CMP #4, D6
        BEQ APPEND_A4
    
        CMP #5, D6
        BEQ APPEND_A5
    
        CMP #6, D6
        BEQ APPEND_A6
    
        CMP #7, D6
        BEQ APPEND_A7
    
        MOVE.B ')', (A3)+
    
        ;Return
        RTS

MODE4
        MOVE.B ')', (A3)+

        CMP #0, D6
        BEQ APPEND_A0
    
        CMP #1, D6
        BEQ APPEND_A1
    
        CMP #2, D6
        BEQ APPEND_A2
    
        CMP #3, D6
        BEQ APPEND_A3
    
        CMP #4, D6
        BEQ APPEND_A4
    
        CMP #5, D6
        BEQ APPEND_A5
    
        CMP #6, D6
        BEQ APPEND_A6
    
        CMP #7, D6
        BEQ APPEND_A7
    
        MOVE.B #')', (A3)+
        MOVE.B #'+', (A3)+
    
        ;Return
        RTS

MODE5
        ;Error-handling mode.
        RTS
    
MODE6
        ;Error-handling mode.
        RTS
    
MODE7
        CMP #0, D6
        BEQ MODE_7_SHORT
    
        CMP #1, D6
        BEQ MODE_7_LONG
    
        CMP #4, D6
        BEQ MODE_7_IMM
    
        RTS

MODE_7_SHORT
        MOVE.B #'%', (A3)+
        ROR #8, D7
        MOVE #16, D5
    
        RTS
    
MODE_7_LONG
        MOVE.B #'%', (A3)+
        MOVE #32, D5
        RTS

MODE_7_IMM
        MOVE.B #'#',(A3)+
        MOVE #16, D5
    
        RTS

APPEND_D0
        MOVE.B  #'D', (A3)+
        MOVE.B  #'0', (A3)+
        RTS

APPEND_D1
        MOVE.B  #'D', (A3)+
        MOVE.B  #'1', (A3)+
        RTS

APPEND_D2
        MOVE.B  #'D', (A3)+
        MOVE.B  #'2', (A3)+
        RTS

APPEND_D3
        MOVE.B  #'D', (A3)+
        MOVE.B  #'3', (A3)+
        RTS

APPEND_D4
        MOVE.B  #'D', (A3)+
        MOVE.B  #'4', (A3)+
        RTS

APPEND_D5
        MOVE.B  #'D', (A3)+
        MOVE.B  #'5', (A3)+
        RTS

APPEND_D6
        MOVE.B  #'D', (A3)+
        MOVE.B  #'6', (A3)+
        RTS

APPEND_D7
        MOVE.B  #'D', (A3)+
        MOVE.B  #'7', (A3)+
        RTS
    
APPEND_A0
        MOVE.B  #'A', (A3)+
        MOVE.B  #'0', (A3)+
        RTS

APPEND_A1
        MOVE.B  #'A', (A3)+
        MOVE.B  #'1', (A3)+
        RTS

APPEND_A2
        MOVE.B  #'A', (A3)+
        MOVE.B  #'2', (A3)+
        RTS

APPEND_A3
        MOVE.B  #'A', (A3)+
        MOVE.B  #'3', (A3)+
        RTS

APPEND_A4
        MOVE.B  #'A', (A3)+
        MOVE.B  #'4', (A3)+
        RTS

APPEND_A5
        MOVE.B  #'A', (A3)+
        MOVE.B  #'5', (A3)+
        RTS

APPEND_A6
        MOVE.B  #'A', (A3)+
        MOVE.B  #'6', (A3)+
        RTS
    
APPEND_A7
        MOVE.B  #'A', (A3)+
        MOVE.B  #'7', (A3)+
        RTS

        
; -------------------------------------------------------------
;   ERROR when Data has incorrect Addressing MODE
; -------------------------------------------------------------          
DATA_ERROR:      
        

 
*-------------------------------------------------------------------        
    * ITOA CONVERT for IMMEDIATE DATA
    ;Iteration Byte = 2 ITOA Loops, Word = 4 ITOA Loops, Long = 8 Loops 
    *D3 = # of ITOA Loop ITERATION
    *D7 = immediate address 
    *D6 = LSR Moving count
    *D0 = Data that is shifted
*-------------------------------------------------------------------   
ITOA:                       ; Converts hex string into int 
        ; D7 has the immediate address  
        JSR     ITOA_LOOP
        RTS
        
ITOA_LOOP:
        CLR.L   D0 
        CLR.L   D6
        
        SUB.B   #1, D3  
        MOVE.L  D7, D0
        MOVE.B  D3, D6

        MULU    #4, D6      ; The amount that we shift 
        LSR.L   D6, D0       ; Shift D0 with iteration Loop * 4
        
        ANDI.L  #$F, D0          ; Last 4 bits in hex 
        
        ; Convert Hex into ASCII 
        JSR     ITOA_CONVERT
        
        ; ADD to A3 Counter 
        JSR     ITOA_ADD_CHAR                  
        ; Checks if counter is empty, ITOA is completed 
        CMP.B   #0,D3
        BEQ     ITOA_DONE
        
        JMP     ITOA_LOOP   ; Continue Reading more bits from immediate data         
                       
ITOA_DONE:          
        RTS         ; Returns back to last JSR 

ITOA_CONVERT: 
        CMP.B       #9,D0
        BLS         ITOA_CONVERT_N
        
        ADDI.W      #$37, D0
        RTS 
        
ITOA_CONVERT_N
        ADDI.W     #$30,D0
        RTS
        
ITOA_ADD_CHAR: 
        CMP.B   #$30, D0
        BEQ     CHAR_0
        
        CMP.B   #$31, D0
        BEQ     CHAR_1
        
        CMP.B   #$32, D0
        BEQ     CHAR_2
        
        CMP.B   #$33, D0
        BEQ     CHAR_3
        
        CMP.B   #$34, D0
        BEQ     CHAR_4
        
        CMP.B   #$35, D0
        BEQ     CHAR_5
        
        CMP.B   #$36, D0
        BEQ     CHAR_6
        
        CMP.B   #$37, D0
        BEQ     CHAR_7
        
        CMP.B   #$38, D0
        BEQ     CHAR_8
        
        CMP.B   #$39, D0
        BEQ     CHAR_9
        
        CMP.B   #$41, D0
        BEQ     CHAR_A
        
        CMP.B   #$42, D0
        BEQ     CHAR_B        
        
        CMP.B   #$43, D0
        BEQ     CHAR_C
        
        CMP.B   #$44, D0
        BEQ     CHAR_D
        
        CMP.B   #$45, D0
        BEQ     CHAR_E
        
        CMP.B   #$46, D0
        BEQ     CHAR_F  
        
CHAR_0:
        MOVE.B  #'0', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE        
CHAR_1:
        MOVE.B  #'1', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE
CHAR_2:
        MOVE.B  #'2', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE
CHAR_3:
        MOVE.B  #'3', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE
CHAR_4:
        MOVE.B  #'4', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE
CHAR_5:
        MOVE.B  #'5', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE
CHAR_6:
        MOVE.B  #'6', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE
CHAR_7:
        MOVE.B  #'7', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE
CHAR_8:
        MOVE.B  #'8', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE
CHAR_9:
        MOVE.B  #'9', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE
CHAR_A:
        MOVE.B  #'A', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE
CHAR_B:
        MOVE.B  #'B', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE
CHAR_C:
        MOVE.B  #'C', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE
CHAR_D:
        MOVE.B  #'D', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE
CHAR_E:
        MOVE.B  #'E', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE
CHAR_F:
        MOVE.B  #'F', (A3)+ 
        JMP     ITOA_ADD_CHAR_DONE
        
ITOA_ADD_CHAR_DONE:
        RTS                
; -------------------------------------------------------------
;   Converts User string input into HEX 
; -------------------------------------------------------------         
ATOI:                       ; Converts hex string into int 
        JSR     ATOI_LOOP
        RTS
        
ATOI_LOOP: 
        MOVE.B  (A1)+, D1
        
        ; Checks if it is 00/ NULL, Reading is done
        CMP.B   #0,D1
        BEQ     ATOI_DONE
        
        CMP.B   #$30, D1         ; Error / non valid input
        BLT.B    ATOI_ERROR
        
        CMP.B   #$40,D1          ; Checks for value in range of num (0 - 9) 
        BLT.B   ATOI_NUM_VALUE
        
        CMP.B   #$41, D1         ; Error / non valid input
        BLT     ATOI_ERROR                
        
        CMP.B   #$47, D1          
        BLT     ATOI_CAP_LETTR_VALUE   ; Checks for value in range of A-F
        
        JMP     ATOI_ERROR      ;Error if it reaches all the way to the end
                
ATOI_NUM_VALUE: 
        LSL.L   #$4, D3          ; Shift 4 bits to the left for D3
        SUBI.B  #$30, D1        ; ASCI Value subtracts 30 
        ADD.L   D1, D3          ; Add  Hex value into D1 into D3 
        JMP     ATOI_LOOP
        

ATOI_CAP_LETTR_VALUE: 
        LSL.L   #$4, D3          ; Shift 4 bits to the left for D3
        SUBI.B  #$37, D1        ; ASCI Value subtracts 30 
        ADD.L   D1, D3          ; Add  Hex value into D1 into D3 
        JMP     ATOI_LOOP
                
ATOI_ERROR: 
        LEA     ATOI_MESS_ERROR, A1
        MOVE.B  #task14,D0
        TRAP    #15           Display  Error Message
        JMP     USER_INPUT
        
ATOI_DONE: 
        RTS
       
ERROR_START_ADDR:   
        LEA     START_ADDR_ERROR , A1
        MOVE.B  #task14,D0
        TRAP    #15           Display  Error Message
        JMP     USER_INPUT
        
ERROR_END_ADDR:   
        LEA     END_ADDR_ERROR , A1
        MOVE.B  #task14,D0
        TRAP    #15           Display  Error Message
        JMP     USER_INPUT        
                
DONE:
        MOVE.B  #9, D0
        TRAP    #15             Halt Simulator   
        
        
* Put variables and constants here
CR      EQU     $0D
LF      EQU     $0A
BLANK                   DC.B    '',CR,LF,0
WELCOME_MESS            DC.B    'Welcome to the disassembler program',CR,LF,0
START_MESS              DC.B    'Enter a start address',CR,LF,0
REPEAT_MESS             DC.B    'Enter Y to disassemble another program, N to quit',CR,LF,0
INVALID_MESS            DC.B    'Wrong Input, Try again', CR,LF,0
END_MESS                DC.B    'Enter the end address',CR,LF,0
ATOI_MESS_ERROR         DC.B    'Invalid inputs for HEX values, Please try again',CR,LF,LF,0
START_ADDR_ERROR        DC.B    'Invalid start address, Please try again',CR,LF,LF,0
END_ADDR_ERROR          DC.B    'Invalid end address, Please try again',CR,LF,LF,0
buffer                  DS.B    bufferSize
MAX_SCREEN_OUTPUT       DC.B    'Press enter any key to continue the program',CR,LF,0
DECODE_OP_ERROR         DC.B    'Error in reading the instruction. Invalid Op code readings', CR, LF,0
DECODE_OP_UNSUPPORT     DC.B    'Unsupported Op code readings', CR, LF,0
        END    START        ; last line of source




*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
