.model tiny
.code
org 100h

Start:

	mov di, offset Frame_style
	mov si, offset String
	mov ax, 14h
	mov bp, 20h
	mov dh, 00011100b
	call Draw_Frame
	
	Exit:
	mov ax, 4c00h
	int 21h

;------------------------------------------------
; Draws a frame with centered text
; Entry: DI - frame style string, SI - string to
; 	 output, DH - frame colour, AX - height,
;	 BP - width
; Exit:  None
; Destr: BX ES CX
;------------------------------------------------

Draw_Frame	proc
		sub ax, 2h
		sub bp, 2h
		mov bx, 0b800h
		mov es, bx
		mov bx, 0b
		call Draw_Line
		inc di
		push es		 ; savinig initial value of segment
		mov bx, es
		add bx, 0ah
		mov es, bx	 ; 160 bytes - string length
		mov bx, 0b
		mov cx, 0b
	
		DF_loop_condition:
		cmp cx, ax
		jge DF_skip_loop

		push cx
		push di
		call Draw_Line
		mov bx, es
		add bx, 0ah
		mov es, bx
		mov bx, 0b
		pop di
		pop cx
		inc cx
		jmp DF_loop_condition

		DF_skip_loop:
		add di, 3h
		call Draw_Line
		pop es
		call Write_String
		ret
		endp

;------------------------------------------------

;------------------------------------------------
; Draws a line with 3 symbols
; Entry: DI - string offset with symbols, DH - colour
; Exit: None
; Destr: DI, BX, CX
;------------------------------------------------
Draw_Line	proc
		
		push ax
		mov ah, [di]
		mov es:[bx], ah
		mov es:[bx+1], dh 
		inc di
		add bx, 2h
		mov cx, 0h
		mov ah, [di]

		DL_loop_condition:
		cmp cx, bp
		jge DL_skip_loop

		mov es:[bx], ah
		mov es:[bx+1], dh
		inc cx
		add bx, 2h
		jmp DL_loop_condition
		DL_skip_loop:
		
		inc di
		mov ah, [di]
		mov es:[bx], ah
		mov es:[bx+1], dh
		pop ax
		ret
		endp
;------------------------------------------------

;------------------------------------------------
; Prints string
; Entry: SI - string offset, AX - height, BP -
;	 width, DH - colour
; Exit:  None
; Destr: AX, BX, CX, DX, BP, DI
;------------------------------------------------

Write_String	proc

		mov ch, dh
		mov dx, 0h
		mov bx, 5h	;10*16*center
		mul bx
		mov bx, es
		add ax, bx
		mov es, ax

		mov ax, bp
		mov bx, 5h
		div bx 		;1/5 - offsets
		mov bx, bp
		sub bx, ax
		push si
		call Str_Len
		pop si
		
		cmp ax, bx	; ax - real length, bx - needed lenth of line
		jg WS_line_break  ; was jg

				;No line break
		mov bx, ax
		mov ax, bp
		sub ax, bx
		mov bx, ax
		add bx, 2h
		
		WS_loop0_condition:
		cmp byte ptr [si], '$'
		je WS_loop0_skip

		mov ah, [si]
		mov es:[bx], ah
		mov es:[bx+1], ch
		add bx, 2h
		inc si

		jmp WS_loop0_condition
		WS_loop0_skip:

		jmp WS_skip		;end no line break


		WS_line_break:
		
		
		push ax
		mov ax, bp
		sub ax, bx
		mov di, ax		; counting offset neede for bx
		
		pop ax
		push di
		
		mov dx, 0h
		div bx
		mov di, ax		; inerations amount
		
		mov ax, bx
		mov dx, 2h
		mul dx
		pop bx
		add bx, 2h
		add ax, bx
		mov bp, ax
		mov dx, 0h
		WS_loop1_condition:
		cmp dx, di
		jge WS_loop1_skip

		push bx
		call Write_Line
		pop bx
		mov ax, es
		add ax, 0ah
		mov es, ax
		inc dx
		jmp WS_loop1_condition

		WS_loop1_skip:

		WS_loop2_condition:
		cmp byte ptr [si], '$'
		je WS_loop2_skip

		mov ah, [si]
		mov es:[bx], ah
		mov es:[bx+1], ch
		add bx, 2h
		inc si		
		jmp WS_loop2_condition

		WS_loop2_skip:
		WS_skip:
;		WS_line_break:
		ret
		endp
;------------------------------------------------

;------------------------------------------------
; Prints 1 line
; Entry: 
;
;
;------------------------------------------------
Write_Line	proc

		WL_loop_condition:
		cmp bx, bp
 		jge WL_skip_loop
		
		mov ah, [si]
		mov es:[bx], ah
		mov es:[bx+1], ch
		add bx, 2h
		inc si
		jmp WL_loop_condition
		
		WL_skip_loop:
		ret
		endp
;------------------------------------------------


;--------------------------------------
;I    Some Huuuuuge teeeeeextttttt    I



;------------------------------------------------
; Counts string's length
; Entry: SI - string offset
; Exit: AX - length
; Destr: AX
;------------------------------------------------

Str_Len		proc
		
		mov ax, 0h
		SL_loop_condition:
		cmp byte ptr [si], '$'
		je SL_skip
		
		inc ax
		inc si		

		jmp SL_loop_condition
		SL_skip:
		ret
		endp
;------------------------------------------------


Frame_style: db  '+-+I I\_/$'
String: db 'One Piece is REEEEAAAAALLLL!!!$'
;String: db 'A$'

end Start