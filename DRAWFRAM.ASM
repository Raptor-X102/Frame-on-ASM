.model tiny
.code
org 100h
LOCALS @@
COMMAND_STR_OFFSET equ 81h
USER_FORMAT_NUM equ 0h
WINDOW_HEIGHT equ 18h
VIDEO_MEM_SEGMENT equ 0b800h
WINDOW_WIDTH equ 50h
NEW_LINE_SEG_OFFSET equ 0ah
DEC_BASE equ 0ah
OFFSET_RATIO equ 5h

Start:
		call main
		mov ax, 4c00h
		int 21h

;------------------------------------------------
; main function
; Entry: from command string
;		 input format:
;		 width(hex)
;		 height(hex)
;		 colour(hex)
;		 frame_style_format(from 0 to 9, depends on amount)
;		 if user_frame_style_format:
;		 user_frame_style(without '$')
;		 string_to_write (with '$' at the end)
;		 else: string_to_write (with '$' at the end)
; Exit:  None
;------------------------------------------------
main	proc

		mov di, COMMAND_STR_OFFSET
		call Atoi_dec	; Get width
		mov bp, ax
		call Atoi_dec	; Get height
		mov dx, ax
		call Atoi_hex	; Get colour
		mov bl, al
		call Atoi_dec	; Get frame style format

		cmp al, USER_FORMAT_NUM

		je User_format

		mov si, offset Frame_style
		sub al, 1h		; real indexes start with 0
		push ax
		call Skip_spaces
		pop ax
		push di			; to get string to write offset
		mov cl, al		; |
		shl ax, 3h		; | --> mul 10 (dec) to get frame style
		add al, cl		; |
		add al, cl		; |
		add si, ax
		mov ah, bl		; puts colour back
		call Draw_Frame
		pop si			; gets string to write offset
		jmp Skip_user_format

		User_format:

		call Skip_spaces
		mov si, di		; gets user's frame style from command string
		mov ah, bl		; puts colour back
		call Draw_Frame
		inc si			; go to next 'space' symbol
		push di
		mov di, si		; Skip_spaces needs di to work with
		call Skip_spaces
		mov si, di
		pop di

		Skip_user_format:

		call Write_String

		ret
		endp
;------------------------------------------------

;------------------------------------------------
; Draws a frame with centered text
; Entry: SI - frame style string,
; 	 	 AH - frame colour, DX - height,
;	 	 BP - width
; Exit:  None
; Destr: BX ES CX
;------------------------------------------------

Draw_Frame	proc

		mov bx, WINDOW_HEIGHT
		sub bx, dx
		mov cx, bx
		shl bx, 2h		; |
		add bx, cx		; | --> mul 5
		add bx, VIDEO_MEM_SEGMENT		; with alignment
		mov es, bx

		mov di, WINDOW_WIDTH
		sub di, bp		; puts double left border offset, but each symbol is specified by 2 bytes

		sub dx, 2h		; | amount of symbols between borders
		sub bp, 2h		; |

		push es		; saving initial value of segment
		call Draw_Line		; drawing highest border
		mov bx, es
		add bx, NEW_LINE_SEG_OFFSET
		mov es, bx	 ; 160 bytes - string length, address += 10 * 16

		mov cx, dx
@@Loop:		; drawing lines of frame between borders
		push cx		; saving counter, it uses also in Draw_Line
		push si		; saving symbols to write
		call Draw_Line
		mov bx, es
		add bx, NEW_LINE_SEG_OFFSET
		mov es, bx
		pop si
		pop cx
		loop @@Loop

		add si, 3h		; moving to the last group of symbols
		call Draw_Line		; drawing lowest border
		pop es		;get initial video mem offset
		ret
		endp

;------------------------------------------------

;------------------------------------------------
; Draws a line with 3 symbols
; Entry: SI - string offset with symbols, AH - colour,
;		 BP - width, DI - offset in video-mem segment
; Exit: None
; Destr: BX, CX, SI, AL
;------------------------------------------------
Draw_Line	proc

		mov bx, di		; saving di
		lodsb
		stosw		; printing first symbol

		mov cx, bp
@@Loop:		; printing symbol of frame between
		mov al, ds:[si]
		stosw
		loop @@Loop

		inc si
		lodsb
		stosw		; printing last symbol
		mov di, bx
		ret
		endp
;------------------------------------------------

;------------------------------------------------
; Prints a string
; Entry: SI - string offset, DX - height, BP -
;	 width, AH - colour, DI - offset in video-mem segment,
; Exit:  None
; Destr: BX, CX, DX, DI
;------------------------------------------------

Write_String	proc

		push ax
		mov ax, dx
		mov bx, ax		;
		shl ax, 2h		; |
		add ax, bx		; | --> mul 5, addr += height/2 * 160 = height * 80 = (height * 16) * 5
		mov bx, es
		add ax, bx
		mov es, ax		; es aligned to the center of window


		mov ax, bp
		mov dx, 0h
		mov bx, OFFSET_RATIO
		div bx	; |--> div 5. sum of offsets to string length ratio is 1 to 5


		mov bx, bp
		sub bx, ax		; bx now is a length of aligned line in frame
		push di
		mov di, si
		call Str_Len
		pop di
		mov dx, cx
		cmp dx, bx	; dx - real length of string
		jg @@Line_break

		mov bx, dx		;No line break
		mov ax, bp
		sub ax, bx
		mov bx, ax
		add bx, 2h
		and bx, 0feh	; mask of 11111110b to make di even
		add di, bx		; offset to video mem to align string

		pop ax			; get back colour

		@@Loop0_condition:		; Loop printing string until '$' symbol
		cmp byte ptr [si], '$'
		je @@Loop0_skip

		lodsb
		stosw

		jmp @@Loop0_condition
		@@Loop0_skip:

		jmp @@Skip		;end No line break


		@@Line_break:

		mov ax, dx
		mov dx, 0h
		div bx			; (amount of full lines to write) = real length of string / aligned size of line
		mov cx, ax		; (amount of lines to write) - 1
		mov ax, bp
		sub ax, bx
		add ax, 4h
		and ax, 0feh	; mask of 11111110b to make di even
		dec bx
		add di, ax	; counting offset needed for di
		pop ax

@@Loop1:
		push di
		call Write_Line
		pop di
		mov dx, es
		add dx, 0ah
		mov es, dx
		loop @@Loop1

		@@Loop2_condition:		;printing remaining part of string
		cmp byte ptr [si], '$'
		je @@Loop2_skip

		lodsb
		stosw
		jmp @@Loop2_condition

		@@Loop2_skip:
		@@Skip:

		ret
		endp
;------------------------------------------------



;------------------------------------------------
; Prints 1 line
; Entry: SI - string offset, BX - aligned size of string
;	     AH - colour, DI - offset in video-mem segment,
; Exit:
; Destr: SI, DI
;------------------------------------------------
Write_Line	proc

		push cx
		mov cx, bx
WL_loop:
		lodsb
		stosw
		loop WL_loop

		pop cx
		ret
		endp
;------------------------------------------------



;------------------------------------------------
; Counts string's length
; Entry: DI - string offset
; Exit: CX - length
; Destr: AL, CX, DI
;------------------------------------------------

Str_Len		proc

		CLD
		mov cx, ds
		push es
		mov es, cx
		mov al, '$'
		mov cx, 0ffffh
		repne scasb
		neg cx
		dec cx
		pop es
		ret
		endp
;------------------------------------------------



;------------------------------------------------
; Atoi_dec
; Entry: DI - string with number offset
; Exit: AX - number
; Destr: AX, DI, BH
;------------------------------------------------

Atoi_dec	proc

			call Skip_spaces
			mov al, [di]
			sub al, '0'		; gets first symbol
			inc di
			@@cond:		; gets symbols until 'space'
			cmp byte ptr [di], ' '
			je @@skip_loop

			mov bh, DEC_BASE
			mul bh
			add al, [di]
			sub al, '0'
			inc di
			jmp @@cond

			@@skip_loop:
			ret
			endp
;------------------------------------------------

;------------------------------------------------
; Atoi_hex
; Entry: DI - string with number offset
; Exit: AX - number
; Destr: AX, DI, BH
;------------------------------------------------

Atoi_hex	proc


			call Skip_spaces
			mov ax, 0h
			mov al, [di]
			sub al, '0'		; gets first symbol
			inc di
			@@cond:
			cmp byte ptr [di], ' '
			je @@skip_loop

			cmp byte ptr [di], 'a'		; checks digit or letter

			shl ax, 4h		; mul 16 = HEX_BASE
			add al, [di]
			inc di

			jge @@let_2_cond

			sub al, '0'
			jmp @@cond

			@@let_2_cond:

			sub al, 'W'		; <=> sub ax, ('a' - 10d)
			jmp @@cond

			@@skip_loop:
			ret
			endp
;------------------------------------------------

;------------------------------------------------
; Skips spaces
; Entry: DI - string to skip offset
; Exit: None
; Destr: AL, CX
;------------------------------------------------

Skip_spaces		proc

			mov cx, ds
			push es
			mov es, cx
			mov cx, 0ffffh
			mov al, ' '
			repe scasb
			sub di, 1h		; IDK why repe scasb does 1 extra iteration
			pop es
			ret
			endp
;------------------------------------------------



Frame_style: db '+-+I I\_/$'
			 db 3h, 3h, 3h, 3h, ' ', 3h, 3h, 3h, 3h, '$'
String: db 'One Piece is REEEEEEEAAAAALLLLL!!!$'
;String: db 'A$'

end Start
