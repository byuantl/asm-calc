$MODDE0CV

	CSEG at 0
	ljmp main_code

	DSEG at 30H
x:        ds 4   ; math32 working variable
y:        ds 4   ; math32 working variable
bcd:      ds 5   ; packed BCD output
operand1: ds 4   ; saved first operand in binary
op_code:  ds 1   ; current operator key code
state:    ds 1   ; state machine state 0-3
neg_flag: ds 1   ; 0=positive, 1=negative result
err_flag: ds 1   ; nonzero = error displayed
temp1:    ds 4   ; temp storage for triangle/sqrt

	BSEG
mf:       dbit 1 ; math32 overflow flag

$include(math32.asm)

	CSEG

; Look-up table for 7-seg displays
myLUT:
    DB 0xC0, 0xF9, 0xA4, 0xB0, 0x99        ; 0 TO 4
    DB 0x92, 0x82, 0xF8, 0x80, 0x90        ; 5 TO 9
    DB 0x88, 0x83, 0xC6, 0xA1, 0x86, 0x8E  ; A to F

showBCD MAC
	; Display LSD
    mov A, %0
    anl a, #0fh
    movc A, @A+dptr
    mov %1, A
	; Display MSD
    mov A, %0
    swap a
    anl a, #0fh
    movc A, @A+dptr
    mov %2, A
ENDMAC

Display:
	mov dptr, #myLUT

	; Show negative flag on LEDRA.0
	mov a, neg_flag
	jz Display_pos
	setb LEDRA.0
	sjmp Display_L1
Display_pos:
	clr LEDRA.0
Display_L1:

	; Non-zero high digits alert on LEDRA.7
	mov a, bcd+3
	orl a, bcd+4
	jz Display_L2
	setb LEDRA.7
	sjmp Display_L3
Display_L2:
	clr LEDRA.7
Display_L3:

	; KEY3 or SW2 shows high digits
	jnb key.3, Display_high_digits
	jb SWA.2, Display_high_digits
	showBCD(bcd+0, HEX0, HEX1)
	showBCD(bcd+1, HEX2, HEX3)
	showBCD(bcd+2, HEX4, HEX5)
	sjmp Display_end

Display_high_digits:
	showBCD(bcd+3, HEX0, HEX1)
	showBCD(bcd+4, HEX2, HEX3)
	mov HEX4, #0xff
	mov HEX5, #0xff

Display_end:
    ret

MYRLC MAC
	mov a, %0
	rlc a
	mov %0, a
ENDMAC

Shift_Digits_Left:
	mov R0, #4 ; shift left four bits
Shift_Digits_Left_L0:
	clr c
	MYRLC(bcd+0)
	MYRLC(bcd+1)
	MYRLC(bcd+2)
	MYRLC(bcd+3)
	MYRLC(bcd+4)
	djnz R0, Shift_Digits_Left_L0
	; R7 has the new bcd digit
	mov a, R7
	orl a, bcd+0
	mov bcd+0, a
	ret

MYRRC MAC
	mov a, %0
	rrc a
	mov %0, a
ENDMAC

Shift_Digits_Right:
	mov R0, #4 ; shift right four bits
Shift_Digits_Right_L0:
	clr c
	MYRRC(bcd+4)
	MYRRC(bcd+3)
	MYRRC(bcd+2)
	MYRRC(bcd+1)
	MYRRC(bcd+0)
	djnz R0, Shift_Digits_Right_L0
	ret

Wait50ms:
;33.33MHz, 1 clk per cycle: 0.03us
	mov R0, #90
L3: mov R1, #74
L2: mov R2, #250
L1: djnz R2, L1 ;3*250*0.03us=22.5us
    djnz R1, L2 ;74*22.5us=1.665ms
    djnz R0, L3 ;1.665ms*30=50ms
    ret

CHECK_COLUMN MAC
	jb %0, CHECK_COL_%M
	mov R7, %1
	jnb %0, $ ; wait for key release
	setb c
	ret
CHECK_COL_%M:
ENDMAC

Configure_Keypad_Pins:
	; Configure the row pins as output and the column pins as inputs
	orl P1MOD, #0b_01010100 ; P1.6, P1.4, P1.2 output
	orl P2MOD, #0b_00000001 ; P2.0 output
	anl P2MOD, #0b_10101011 ; P2.6, P2.4, P2.2 input
	anl P3MOD, #0b_11111110 ; P3.0 input
	ret

; These are the pins used for the keypad in this program:
ROW1 EQU P1.2
ROW2 EQU P1.4
ROW3 EQU P1.6
ROw4 EQU P2.0
COL1 EQU P2.2
COL2 EQU P2.4
COL3 EQU P2.6
COL4 EQU P3.0

; This subroutine scans a 4x4 keypad.  If a key is pressed sets the carry
; to one and returns the key code in register R7.
Keypad:
	; First check the backspace/correction pushbutton.  We use KEY1 for this function.
	jb KEY.1, keypad_L0
	lcall Wait50ms ; debounce
	jb KEY.1, keypad_L0
	jnb KEY.1, $ ; The key was pressed, wait for release
	lcall Shift_Digits_Right
	clr c
	ret

keypad_L0:
	; Make all the rows zero.  If any column is zero then a key is pressed.
	clr ROW1
	clr ROW2
	clr ROW3
	clr ROW4
	mov c, COL1
	anl c, COL2
	anl c, COL3
	anl c, COL4
	jnc Keypad_Debounce
	clr c
	ret

Keypad_Debounce:
	; A key maybe pressed.  Wait and check again to discard bounces.
	lcall Wait50ms ; debounce
	mov c, COL1
	anl c, COL2
	anl c, COL3
	anl c, COL4
	jnc Keypad_Key_Code
	clr c
	ret

Keypad_Key_Code:
	; A key is pressed.  Find out which one.
	setb ROW1
	setb ROW2
	setb ROW3
	setb ROW4

	jnb SWA.0, keypad_default
	ljmp keypad_90deg

	; This check section is for an un-modified keypad
keypad_default:
	; Check row 1
	clr ROW1
	CHECK_COLUMN(COL1, #01H)
	CHECK_COLUMN(COL2, #02H)
	CHECK_COLUMN(COL3, #03H)
	CHECK_COLUMN(COL4, #0AH)
	setb ROW1

	; Check row 2
	clr ROW2
	CHECK_COLUMN(COL1, #04H)
	CHECK_COLUMN(COL2, #05H)
	CHECK_COLUMN(COL3, #06H)
	CHECK_COLUMN(COL4, #0BH)
	setb ROW2

	; Check row 3
	clr ROW3
	CHECK_COLUMN(COL1, #07H)
	CHECK_COLUMN(COL2, #08H)
	CHECK_COLUMN(COL3, #09H)
	CHECK_COLUMN(COL4, #0CH)
	setb ROW3

	; Check row 4
	clr ROW4
	CHECK_COLUMN(COL1, #0EH)
	CHECK_COLUMN(COL2, #00H)
	CHECK_COLUMN(COL3, #0FH)
	CHECK_COLUMN(COL4, #0DH)
	setb ROW4

	clr c
	ret

	; This check section is for a keypad with the labels rotated 90 deg ccw
keypad_90deg:
	; Check row 1
	clr ROW1
	CHECK_COLUMN(COL1, #0AH)
	CHECK_COLUMN(COL2, #0BH)
	CHECK_COLUMN(COL3, #0CH)
	CHECK_COLUMN(COL4, #0DH)
	setb ROW1

	; Check row 2
	clr ROW2
	CHECK_COLUMN(COL1, #03H)
	CHECK_COLUMN(COL2, #06H)
	CHECK_COLUMN(COL3, #09H)
	CHECK_COLUMN(COL4, #0FH)
	setb ROW2

	; Check row 3
	clr ROW3
	CHECK_COLUMN(COL1, #02H)
	CHECK_COLUMN(COL2, #05H)
	CHECK_COLUMN(COL3, #08H)
	CHECK_COLUMN(COL4, #00H)
	setb ROW3

	; Check row 4
	clr ROW4
	CHECK_COLUMN(COL1, #01H)
	CHECK_COLUMN(COL2, #04H)
	CHECK_COLUMN(COL3, #07H)
	CHECK_COLUMN(COL4, #0EH)
	setb ROW4

	clr c
	ret

;----------------------------------------------------
; Clear BCD display to all zeros
;----------------------------------------------------
Clear_BCD:
	clr a
	mov bcd+0, a
	mov bcd+1, a
	mov bcd+2, a
	mov bcd+3, a
	mov bcd+4, a
	ret

;----------------------------------------------------
; Show_Error: displays "Error " on HEX5-HEX0
; E=86h, r=AFh, o=A3h, blank=FFh
;----------------------------------------------------
Show_Error:
	mov HEX5, #086h ; E
	mov HEX4, #0AFh ; r
	mov HEX3, #0AFh ; r
	mov HEX2, #0A3h ; o
	mov HEX1, #0AFh ; r
	mov HEX0, #0FFh ; blank
	mov err_flag, #1
	ret

;----------------------------------------------------
; Save operand1 from x (4 bytes)
;----------------------------------------------------
Save_Operand1:
	mov operand1+0, x+0
	mov operand1+1, x+1
	mov operand1+2, x+2
	mov operand1+3, x+3
	ret

;----------------------------------------------------
; Load operand1 into x
;----------------------------------------------------
Load_Operand1_to_X:
	mov x+0, operand1+0
	mov x+1, operand1+1
	mov x+2, operand1+2
	mov x+3, operand1+3
	ret

;----------------------------------------------------
; Load temp1 into y
;----------------------------------------------------
Load_Temp1_to_Y:
	mov y+0, temp1+0
	mov y+1, temp1+1
	mov y+2, temp1+2
	mov y+3, temp1+3
	ret

;----------------------------------------------------
; Save x to temp1
;----------------------------------------------------
Save_X_to_Temp1:
	mov temp1+0, x+0
	mov temp1+1, x+1
	mov temp1+2, x+2
	mov temp1+3, x+3
	ret

;----------------------------------------------------
; isqrt: Integer square root using Heron's method
; Input: value in x
; Output: floor(sqrt(x)) in x
;----------------------------------------------------
isqrt:
	push acc
	push psw
	push AR0
	push AR1
	push AR2
	push AR3
	push AR4
	push AR5

	; Special case: if x == 0, return 0
	mov a, x+0
	orl a, x+1
	orl a, x+2
	orl a, x+3
	jnz isqrt_start
	ljmp isqrt_done

isqrt_start:
	; Save n (the input value) to temp1
	lcall Save_X_to_Temp1

	; Initial guess = n (x already has n)
	; We'll iterate: new_guess = (guess + n/guess) / 2

isqrt_loop:
	; Save current guess (x) to operand1 temporarily
	; We need: old_guess in operand1, n in temp1
	lcall Save_Operand1  ; operand1 = current guess

	; Compute n / guess: x = n, y = guess
	lcall copy_xy        ; y = current guess
	; Load n into x
	mov x+0, temp1+0
	mov x+1, temp1+1
	mov x+2, temp1+2
	mov x+3, temp1+3
	lcall div32          ; x = n / guess

	; x = n/guess, now add guess to it
	; y = old guess (operand1)
	mov y+0, operand1+0
	mov y+1, operand1+1
	mov y+2, operand1+2
	mov y+3, operand1+3
	lcall add32          ; x = (n/guess) + guess

	; Divide by 2 (right shift x by 1)
	clr c
	mov a, x+3
	rrc a
	mov x+3, a
	mov a, x+2
	rrc a
	mov x+2, a
	mov a, x+1
	rrc a
	mov x+1, a
	mov a, x+0
	rrc a
	mov x+0, a

	; new_guess is now in x
	; Compare new_guess (x) with old_guess (operand1 -> y)
	mov y+0, operand1+0
	mov y+1, operand1+1
	mov y+2, operand1+2
	mov y+3, operand1+3
	lcall x_gteq_y      ; mf=1 if new_guess >= old_guess
	jb mf, isqrt_converged

	; new_guess < old_guess, keep iterating with new_guess in x
	sjmp isqrt_loop

isqrt_converged:
	; Return old_guess (in operand1) as the result
	lcall Load_Operand1_to_X

isqrt_done:
	pop AR5
	pop AR4
	pop AR3
	pop AR2
	pop AR1
	pop AR0
	pop psw
	pop acc
	ret

;----------------------------------------------------
; do_subtract: Handles A - B with sign detection
; x = operand1 (A), y = second operand (B)
; Expects x=A, y=B already loaded
;----------------------------------------------------
do_subtract:
	; Check if A < B
	lcall x_lt_y
	jnb mf, do_sub_normal
	; A < B: swap, compute B-A, set negative
	lcall xchg_xy
	lcall sub32
	mov neg_flag, #1
	ret
do_sub_normal:
	lcall sub32
	mov neg_flag, #0
	ret

;----------------------------------------------------
; do_triangle: Right triangle solver
; x = operand1 (A), second number in bcd (B)
; SWA.1=0: hypotenuse = sqrt(A^2 + B^2)
; SWA.1=1: side = sqrt(C^2 - B^2), error if C^2 < B^2
;----------------------------------------------------
do_triangle:
	; First convert bcd to binary for B
	lcall bcd2hex        ; x = B (binary)
	jb mf, do_tri_error

	; Save B to temp1
	lcall Save_X_to_Temp1

	; Compute B^2: x = B, y = B
	lcall copy_xy        ; y = B
	lcall mul32          ; x = B^2
	jb mf, do_tri_error

	; Save B^2 to stack area (reuse operand1 temporarily as scratch)
	; Actually save B^2 where we can get it: push to operand1 area
	push x+0
	push x+1
	push x+2
	push x+3

	; Now compute A^2: load A from operand1
	lcall Load_Operand1_to_X
	lcall copy_xy        ; y = A
	lcall mul32          ; x = A^2
	jb mf, do_tri_error_pop

	; Now x = A^2, need B^2 in y
	pop y+3
	pop y+2
	pop y+1
	pop y+0

	; Check SWA.1 for mode
	jb SWA.1, do_tri_subtract
	; SWA.1=0: hypotenuse = sqrt(A^2 + B^2)
	lcall add32          ; x = A^2 + B^2
	jb mf, do_tri_error
	lcall isqrt          ; x = sqrt(A^2 + B^2)
	clr mf               ; clear mf so caller doesn't see it as error
	ret

do_tri_subtract:
	; SWA.1=1: side = sqrt(C^2 - B^2) where C=A input, B=B input
	; x = C^2 (A^2), y = B^2
	; Check if C^2 < B^2
	lcall x_lt_y
	jb mf, do_tri_error
	lcall sub32          ; x = C^2 - B^2
	lcall isqrt          ; x = sqrt(C^2 - B^2)
	clr mf               ; clear mf so caller doesn't see it as error
	ret

do_tri_error_pop:
	; Clean up stack from the 4 pushed bytes
	pop acc
	pop acc
	pop acc
	pop acc
do_tri_error:
	lcall Show_Error
	; Set mf to indicate error to caller
	setb mf
	ret

;----------------------------------------------------
; handle_equals: Compute result based on op_code
; operand1 = A (binary), bcd = B (BCD from display)
; op_code: 0Ah=add, 0Bh=sub, 0Eh=mul, 0Dh=div, 0Ch=triangle
;----------------------------------------------------
handle_equals:
	mov neg_flag, #0

	; Check for triangle first (special handling)
	mov a, op_code
	cjne a, #0Ch, heq_not_triangle
	ljmp heq_triangle
heq_not_triangle:

	; Convert displayed BCD to binary -> x = B
	lcall bcd2hex
	jb mf, heq_error

	; x = B, save it to y, then load A into x
	lcall copy_xy        ; y = B
	lcall Load_Operand1_to_X  ; x = A

	; Dispatch based on op_code
	mov a, op_code

	cjne a, #0Ah, heq_not_add
	; Addition
	lcall add32
	jb mf, heq_error
	sjmp heq_show_result
heq_not_add:

	cjne a, #0Bh, heq_not_sub
	; Subtraction
	lcall do_subtract
	sjmp heq_show_result
heq_not_sub:

	cjne a, #0Eh, heq_not_mul
	; Multiplication
	lcall mul32
	jb mf, heq_error
	sjmp heq_show_result
heq_not_mul:

	cjne a, #0Dh, heq_error
	; Division
	; Check for divide by zero (y == 0)
	mov a, y+0
	orl a, y+1
	orl a, y+2
	orl a, y+3
	jz heq_error
	lcall div32
	jb mf, heq_error
	sjmp heq_show_result

heq_triangle:
	; x = operand1 (A), bcd has B
	lcall do_triangle
	jb mf, heq_done_err  ; error already shown
	sjmp heq_show_result

heq_show_result:
	; Result is in x, convert to BCD for display
	lcall hex2bcd
	; Save result as new operand1 for chaining
	lcall Save_Operand1
	mov state, #3
	ret

heq_error:
	lcall Show_Error
heq_done_err:
	mov state, #3
	ret

;============================================================
; Main code
;============================================================
main_code:
	mov SP, #7FH
	clr a
	mov LEDRA, a
	mov LEDRB, a
	lcall Clear_BCD
	mov state, #0
	mov op_code, #0
	mov neg_flag, #0
	mov err_flag, #0
	mov operand1+0, #0
	mov operand1+1, #0
	mov operand1+2, #0
	mov operand1+3, #0
	lcall Configure_Keypad_Pins

forever:
	lcall Keypad
	jc forever_key_pressed
	ljmp forever_display   ; No key pressed
forever_key_pressed:

	; A key was pressed (key code in R7)
	; If error is displayed, any key clears it
	mov a, err_flag
	jz forever_no_err
	mov err_flag, #0
	mov neg_flag, #0
	clr LEDRA.0
	lcall Clear_BCD
	mov state, #0
	ljmp forever_display
forever_no_err:

	; Classify key: 0-9 = digit, 0A-0E = operator, 0F = equals (#)
	mov a, R7
	clr c
	subb a, #0Ah
	jnc forever_not_digit
	; --- Digit key (0-9) ---
	ljmp handle_digit
forever_not_digit:
	mov a, R7
	cjne a, #0Fh, forever_not_equals
	; --- Equals key (0Fh = '#') ---
	ljmp handle_eq_entry
forever_not_equals:
	; --- Operator key (0A-0E) ---
	ljmp handle_op_entry

;----------------------------------------------------
; handle_digit: Process digit key based on state
; R7 = digit value 0-9
;----------------------------------------------------
handle_digit:
	mov a, state

	cjne a, #0, hd_not_s0
	; State 0: entering first number
	sjmp hd_shift_in
hd_not_s0:
	cjne a, #1, hd_not_s1
	; State 1: operator received, first digit of second number
	mov state, #2
	sjmp hd_shift_in
hd_not_s1:
	cjne a, #2, hd_not_s2
	; State 2: entering second number
	sjmp hd_shift_in
hd_not_s2:
	; State 3: result displayed, start fresh number
	lcall Clear_BCD
	mov neg_flag, #0
	clr LEDRA.0
	mov state, #0
	sjmp hd_shift_in

hd_shift_in:
	; Check if display is full (10 digits)
	; bcd+4 high nibble nonzero means 10 digits used
	mov a, bcd+4
	anl a, #0F0h
	jz hd_not_full
	lcall Show_Error
	ljmp forever
hd_not_full:
	lcall Shift_Digits_Left
	ljmp forever

;----------------------------------------------------
; handle_op_entry: Process operator key based on state
; R7 = operator code (0Ah-0Eh)
;----------------------------------------------------
handle_op_entry:
	mov a, state

	cjne a, #0, ho_not_s0
	; State 0: save current number as operand1, record operator
	lcall bcd2hex          ; convert display to binary in x
	jb mf, ho_error
	lcall Save_Operand1    ; operand1 = x
	mov op_code, R7
	lcall Clear_BCD
	mov neg_flag, #0
	clr LEDRA.0
	mov state, #1
	ljmp forever
ho_not_s0:

	cjne a, #1, ho_not_s1
	; State 1: change operator (overwrite)
	mov op_code, R7
	ljmp forever
ho_not_s1:

	cjne a, #2, ho_not_s2
	; State 2: chain operation - compute current result, use as new operand1
	lcall handle_equals
	; If error occurred, skip
	mov a, err_flag
	jnz ho_chain_done
	; Result is now in operand1, clear display for next input
	mov op_code, R7
	lcall Clear_BCD
	mov neg_flag, #0
	clr LEDRA.0
	mov state, #1
ho_chain_done:
	ljmp forever
ho_not_s2:

	; State 3: use result as operand1, record operator
	; operand1 already has the result from handle_equals
	mov op_code, R7
	lcall Clear_BCD
	mov neg_flag, #0
	clr LEDRA.0
	mov state, #1
	ljmp forever

ho_error:
	lcall Show_Error
	ljmp forever

;----------------------------------------------------
; handle_eq_entry: Process equals key based on state
;----------------------------------------------------
handle_eq_entry:
	mov a, state

	cjne a, #2, heqe_not_s2
	; State 2: compute result
	lcall handle_equals
	ljmp forever
heqe_not_s2:
	; States 0, 1, 3: ignore equals
	ljmp forever

;----------------------------------------------------
; Display update (called every loop iteration)
;----------------------------------------------------
forever_display:
	mov a, err_flag
	jnz forever_skip_display
	lcall Display
forever_skip_display:
	ljmp forever

end
