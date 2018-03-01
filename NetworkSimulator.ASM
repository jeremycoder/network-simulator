INCLUDE C:\Irvine\Irvine32.inc		;Irvine 32 library functions
INCLUDELIB C:\Irvine\Irvine32.lib		;Location may differ from system to system
INCLUDE C:\Irvine\macros.inc

.386

.STACK 4096					;stack size is 4096

ExitProcess PROTO,dwExitCode:DWORD 
HeapAlloc PROTO, hHeap:HANDLE, dwFlags:DWORD, dwBytes:DWORD
FILE_BUFFER_SIZE = 50000

.DATA
max_nodes EQU 26	;Maximum is 26 to allow for nodes named A~Z

ptr_table DWORD (max_nodes*max_nodes) DUP(0)			;ptr_table stores addresses of nodes, as well as connections

my_heap HANDLE 0
dwFlags DWORD HEAP_ZERO_MEMORY

echo_flag DWORD 100		; 0 for no echo, non-zero for echo
start_node DWORD 0
end_node DWORD 0

node_count DWORD 5

message_size EQU 24						;size in BYTES
buffer_size = message_size
queue_count = 25
queue_size DWORD message_size*queue_count	;Size in BYTES

total_hops DWORD 0

;message structure
;
;{prev} @20
;{time to live} @16
;{time received} @12
;{dest} @8
;{origin} @4
;{status} @0


buffer_message_count DWORD 0
queue_message_count DWORD 0

mesages_received_by_destination DWORD 0

system_time DWORD 0

total_messages_generated DWORD 0
current_cycle_message_count DWORD 0
node_messages_count DWORD 0

debug_address DWORD 0
;File variables
;==============
file_buffer BYTE FILE_BUFFER_SIZE DUP(?)
file_name BYTE 80 DUP(0)
file_handle HANDLE ?
file_size DWORD 0
char BYTE ?,0
error_not_number BYTE 09,10,"File Read Error: First line not a number. Quitting.",10,0
error_number_too_low BYTE 09,10,"File Error: Node count too low. Low is 2. Quitting.",10,0
error_number_too_high BYTE 09,10,"File Error: Node count too high. Max is 26. Quitting.",10,0
error_out_of_bounds BYTE 09,10,"File Error: Node out of bounds. Quitting.",10,0
h_index BYTE ?
v_index BYTE ?
temp_counter1 DWORD ?
temp_counter2 DWORD ?
error_same_connection BYTE 09,10,"File Error: Cannot be connected to self. Quitting.",10,0
saveEAX DWORD ?
saveEBX DWORD ?
saveEDX DWORD ?
note_line_complete BYTE 09,10,"Line complete.",10,0
line_count DWORD 0							;counts number of lines in a file
mainNode BYTE ?
connNode BYTE ?

time_to_live DWORD 10
prev_node DWORD 0

temp_message BYTE message_size DUP(0)

address_size DWORD 4

temp_address0 DWORD 0
temp_address1 DWORD 0
temp_address2 DWORD 0

count0 DWORD 0
count1 DWORD 0
count2 DWORD 0

prompt_connection_text0 BYTE "Please enter the name of the node you want to connect to node '", 0
prompt_connection_text1 BYTE "-Enter nothing to finish adding connections to this node",0
prompt_connection_text2 BYTE "-Enter ESC to stop adding connections",0

prompt_start_node_text BYTE "Enter the node where your message will originate:",0
prompt_end_node_text BYTE "Enter the node where you would like your message to reach",0

processing_buffer_text BYTE "Processing buffer ",0


self_connection_text BYTE "ERROR: Node cannot connect to itself",0
out_of_bounds_text BYTE "ERROR: Out of Bounds",0
existing_connection_text BYTE "ERROR: Connection Already Exists",0

connection_established_text BYTE " connection established", 0

dashes BYTE "---------------------",10,0





.CODE
;program starts here
main PROC
		INVOKE HeapCreate, 0, 2000000,400000000
		MOV my_heap, EAX

		;code that prompts user for number of nodes goes here
		;;we need to calculate ttl

		;code that asks for echo_flag goes here
		;;

		CALL initialize_table_p	;allocate memory for nodes
		CALL add_connection_p	;allocate memory for connections

		Call get_start_p
		CALL get_end_p

		CALL Crlf


		MOV ECX, OFFSET temp_message
		;initialize the first message as temp_message
		MOV EAX, 255		;status = not empty
		MOV 0[ECX], EAX
		MOV EAX, start_node	;origin = start_node
		MOV 4[ECX], EAX
		MOV EAX, end_node	;dest = end_node
		MOV 8[ECX], EAX
		MOV EAX, 0		;time_received = 0
		MOV 12[ECX], EAX
		MOV EAX, time_to_live	;time_to_live = time to live
		MOV 16[ECX], EAX
		MOV EAX, start_node		;
		MOV 20[ECX], EAX

		MOV EAX, start_node
		MOV EBX, start_node
		CALL get_pointer_p
		MOV EDI, EDX
		MOV ESI, OFFSET temp_message
		;INC queue_message_count


		;before ok
		;CALL queue_p
		;after, the last node is overwritten


		call simulate_p

		INVOKE HeapDestroy, my_heap
done:
		CALL WaitMsg
		INVOKE exitprocess,0
main ENDP

my_debug PROC
	PUSHAD
		
		MOV EAX, node_count
		DEC EAX
		DEC EAX
		MOV EBX, EAX
		CALL get_pointer_p
		MOV EAX, 0[EDX]
		CALL WriteHex
		CALL Crlf

		MOV temp_address0, EAX
	POPAD
		RET
my_debug ENDP

add_connection_p PROC
	MOV count0, 0				;count0 has the index of the node we want to add connections to
						
node_loop:					;check if we have a node that we can add connections to
	MOV EAX, count0
	CMP EAX, node_count
	JGE done_prompting

prompt_for_connections:
	MOV EAX, count0
	PUSH EAX
	CALL display_connections_p
	POP EAX
	MOV count0, EAX

	MOV EDX, OFFSET prompt_connection_text0
	CALL WriteString

	;print out current node name
	MOV EAX, count0
	ADD AL, 'A'			;of current node's name
	CALL WriteChar
	MOV AL, "'"
	CALL WriteChar
	CALL Crlf

	MOV EDX, OFFSET prompt_connection_text1
	CALL WriteString
	CALL Crlf
	MOV EDX, OFFSET prompt_connection_text2
	CALL WriteString
	CALL Crlf

	MOV EAX, 0				;Clear EAX
	CALL ReadChar				;read in user input into AL
	CALL Crlf
	CALL Crlf


	CMP AL, '='
	jne noprint
		call dump_mem
	JMP prompt_for_connections
	
	noprint:

	CMP AL, 13d				;check if user wants to go to next node 
	JE next_node				;13d = 'CR'

	CMP AL, 0				;check if user wants to go to next node 
	JE next_node				;13d = 'CR'

	CMP AL, 27d				;27d = 'ESC'
	JE done_prompting

	AND AL, (0ffh-20h)			;convert to upper case

	CMP AL, 'A'					;check if out of bounds
	JL out_of_bounds			;

	MOV EDX, node_count			;
	ADD DL, 'A'						;
	CMP AL, DL						;
	JGE out_of_bounds				;


	MOV EBX, count0
	SUB AL, 65d					;convert to an index					
	CMP AL, BL
	JE self_connection


	;at this point, index is guaranteed to be within bounds
	
	;code to check "if connection already exists" goes here
	MOVZX EAX, AL
	MOVZX EBX, BL		;set up eax and ebx for existing_connection
	MOV temp_address0, EAX
	MOV temp_address1, EBX
	

	CALL get_pointer_p
	MOV temp_address2, EDX
	MOV ESI, 0[EDX]

	CMP ESI, 0
	JNE existing_connection


	;else connection does not exist, then we create a new connection

	INVOKE HeapAlloc, my_heap, dwFlags, buffer_size
	MOV EDX, temp_address2
	MOV [EDX], EAX

	MOV EAX, temp_address1
	MOV EBX, temp_address0
	
	ADD AL, 65d
	CALL WriteChar
	MOV AL, BL
	ADD AL, 65d
	CALL WriteChar
	MOV EDX, OFFSET connection_established_text
	CALL WriteString
	CALL Crlf
	Call Crlf

	

	JMP prompt_for_connections			;get ready for next connection

existing_connection:
	MOV EDX, OFFSET existing_connection_text
	CALL WriteString
	CALL Crlf
	CALL Crlf
	CALL Crlf
	JMP prompt_for_connections


self_connection:
	MOV EDX, OFFSET self_connection_text
	CALL WriteString
	CALL Crlf
	CALL Crlf
	CALL Crlf
	JMP prompt_for_connections

out_of_bounds:
	MOV EDX, OFFSET out_of_bounds_text
	CALL WriteString
	CALL Crlf
	CALL Crlf
	CALL Crlf
	JMP prompt_for_connections
next_node:
	CALL Crlf
	INC count0
	JMP node_loop



;check for reflections
done_prompting:
	MOV count0, 0			;count0 and count1 are iteration variables

rloop1:
	MOV EAX, count0
	CMP EAX, node_count
	JGE done
	MOV count1, 0
rloop2:
	MOV EAX, count1
	CMP EAX, node_count
	JGE rloop2_end

	MOV EAX, count0
	MOV EBX, count1
	CALL get_pointer_p
	MOV ESI, EDX
	
	MOV EAX, count1
	MOV EBX, count0
	CALL get_pointer_p
	MOV EDI, EDX

	;check if reflection 
	MOV ECX, [ESI]
	MOV EDX, [EDI]


	CMP ECX, 0
	JE ecx_z
ecx_nz:
	CMP EDX, 0
	JNZ next_	;jump over if both exist
	MOV temp_address0, EDI
	INVOKE HeapAlloc, my_heap, dwFlags, buffer_size
	MOV EDI, temp_address0
	MOV [EDI],EAX
	JMP next_
ecx_z:
	CMP EDX, 0
	JE next_	;jump over if both zero
	MOV temp_address0, ESI
	INVOKE HeapAlloc, my_heap, dwFlags, buffer_size
	MOV ESI, temp_address0
	MOV [ESI],EAX
next_:
	INC count1
	JMP rloop2
rloop2_end:
	INC count0
	JMP rloop1
done:
	PUSHAD
	CALL display_connections_p
	CALL  crlf
	call dump_mem
	POPAD

	RET
add_connection_p ENDP


;precondition: EAX has row index (where transmit from)
;precondition: EBX has col index (Where transmit to)
;
;returns the address of specified table element into in EDX
get_pointer_p PROC USES ESI EDI
	PUSH EAX
	PUSH EBX

	MOV EDX, OFFSET ptr_table

	MOV ESI, 4
	
	MOV EDI, node_count
	ADD EDI, EDI
	ADD EDI, EDI

loop0:
	CMP EAX, 0
	JLE loop1
	ADD EDX, EDI
	DEC EAX
	JMP loop0
loop1:
	CMP EBX, 0
	JLE out1
	ADD EDX, ESI
	DEC EBX
	JMP loop1
out1:
	POP EBX
	POP EAX
	RET
get_pointer_p ENDP

dump_mem PROC
	MOV count1, 0
	MOV count2, 0
loop1:
	MOV EAX, count1
	CMP EAX, node_count		;check outerloop
	JGE loop1_end			;end of function
	MOV count2, 0			;if not done, init innerloop
loop2:
	MOV EAX, count2			;check if inner loop is done
	CMP EAX, node_count
	JGE loop2_end

	MOV AL, '('
	CALL WriteChar

	MOV EAX, count1
	MOV EBX, count2
	CALL get_pointer_p

	MOV ESI, 0[EDX]
	MOV EDX, ESI
	MOV EAX, EDX				;
	CALL WriteHex				;

	MOV AL, ')'
	CALL WriteChar
	MOV AL, ' '
	CALL WriteChar

	INC count2
	JMP loop2
loop2_end:
	INC count1
	CALL Crlf
	JMP loop1

loop1_end:
	CALL Crlf
	RET
dump_mem ENDP


display_connections_p PROC USES EAX
	MOV count0, 0
loop1:
	MOV EAX, count0
	CMP EAX, node_count			;check outerloop
	JGE loop1_end			;end of function

	MOV count1, 0		;if not done, init innerloop
loop2:
	MOV EAX,  count1
	CMP EAX, node_count			;check if inner loop is done
	JGE loop2_end

	MOV AL, '{'
	CALL WriteChar

	MOV EAX, count0
	MOV EBX, count1
	CALL get_pointer_p
	MOV ESI, 0[EDX]
	MOV EDX, ESI
	CMP EDX, 0
	JE is_node

	MOV EAX, count1
	ADD AL, 65d
	CALL WriteChar
	
	MOV EAX, count1
	CMP EAX, count0
	JE is_node


	MOV AL, '-'
	CALL WriteChar
	MOV AL, '>'
	CALL WriteChar
	MOV EAX, count0
	ADD EAX, 65d
	Call WriteChar
is_node:
	MOV AL, '}'
	CALL WriteChar
	MOV AL, ' '
	CALL WriteChar
nothing:
	INC count1
	JMP loop2
loop2_end:
	INC count0
	CALL Crlf
	JMP loop1

loop1_end:
	CALL Crlf
	RET
display_connections_p ENDP



;create an nxn table that contains pointers to nodes
;stores node addresses in diagonal
;connection buffers are initialized to 0
initialize_table_p PROC USES EAX EBX EDI ESI
	MOV EAX, 0		;initialize counter
	MOV count0, EAX	;
loop1:
	MOV EBX, count0		;check if done
	CMP EBX, node_count
	JGE done

	MOV ESI, queue_size		;get size of node
	ADD ESI, 8			;which is queue size + 2 ptrs
	MOV count1, ESI
	;allocate a node
	INVOKE HeapAlloc, my_heap, dwFlags, count1
	;EAX has address of node
	MOV temp_address0, EAX		;temp_address0 has address of node

	MOV EAX, count0
	MOV EBX, count0
	CALL get_pointer_p
	MOV temp_address1, EDX		;temp_address1 has table element address

	MOV EAX, temp_address0		;mov node address into eax

	MOV 0[EDX], EAX	;mov eax into table
	
	;initialize in and out pointers
	MOV EAX, temp_address0	;EAX has address of node
	MOV EBX, EAX
	ADD EBX, 8
	MOV EDX, temp_address0
	MOV [EDX], EBX
	MOV 4[EDX], EBX


	;update count
	INC count0	

	JMP loop1

done:
	RET
initialize_table_p ENDP

;procedure to get node user wants to transmit from
get_start_p PROC USES EAX EDX

JMP skip

loop1:
	MOV EDX, OFFSET out_of_bounds_text
	CALL WriteString
	CALL Crlf

skip:
	CALL Crlf
	MOV EDX, OFFSET prompt_start_node_text
	CALL WriteString
	CALL Crlf
	
	CALL ReadChar				;read in user input into AL
	
	CALL Crlf
	

	AND AL, (0ffh-20h)			;convert to upper case
	
	CMP AL, 'A'				;check if out of bounds
	JL loop1			;

	MOV EDX, node_count		;
	ADD DL, 'A'			;
	CMP AL, DL			;
	JGE loop1				;

	Call Crlf

	CALL WriteChar
	CALL WriteChar
	CALL WriteChar
	CALL WriteChar
	CALL WriteChar
	CALL WriteChar
	CALL WriteChar

	SUB AL, 65d
	MOVZX EAX, AL
	MOV start_node, EAX

	CALL Crlf
	RET
get_start_p ENDP
	

;procedure to get node user wants to transmit to
get_end_p PROC USES EAX EDX

JMP skip

loop1:
	MOV EDX, OFFSET out_of_bounds_text
	CALL WriteString
	CALL Crlf

skip:
	CALL Crlf
	MOV EDX, OFFSET prompt_end_node_text
	CALL WriteString
	CALL Crlf
	
	CALL ReadChar				;read in user input into AL
	
	CALL Crlf
	

	AND AL, (0ffh-20h)			;convert to upper case
	
	CMP AL, 'A'				;check if out of bounds
	JL loop1			;

	MOV EDX, node_count		;
	ADD DL, 'A'			;
	CMP AL, DL			;
	JGE loop1				;

	Call Crlf

	CALL WriteChar
	CALL WriteChar
	CALL WriteChar
	CALL WriteChar
	CALL WriteChar
	CALL WriteChar
	CALL WriteChar

	SUB AL, 65d
	MOVZX EAX, AL
	MOV start_node, EAX

	CALL Crlf
	RET
get_end_p ENDP





;Precondition: ESI has address of message we want to queue
;Precondition: EDI has address of queue
;
;
;Postcondition: inptr field of the queue is updated
;Postcondition: Memory block pointed to by ESI is copied into the queue 
;Postcondition: EAX will become some non-zero vaue if queue is not full
;Postcondition: EAX will be 0 if queue is full
queue_p PROC USES EBX ECX
	
.data
	msg_address_var DWORD 0
	queue_address_var DWORD 0
.code
	MOV msg_address_var, ESI
	MOV queue_address_var, EDI

	;set up EBX to hold the next availible address
	MOV EBX, 0[ESI]		;move message's inptr to ebx
	ADD EBX, message_size	;add the size of one message to EBX
	;EBX holds next availible address without accounting for wrap-around


	;set ECX as the first address that requires a wrap-around
	MOV ECX, EDI			;EDI has the address of the queue
	ADD ECX, 8			;8 to account for space for inptr & outptr
	ADD ECX, queue_size		;
	;ECX has the first address that requires a wrap-around

	CMP EBX, ECX			;check if wrap around
	JGE wrap				

	;there was no wrap, so we go directly to test if there is
	;enough space to add another element
	JMP test_overflow

wrap:
	MOV EBX, EDI			;if wrap around, 
	ADD EBX, 8			;set EBX to wrap-around location

	;at this point, EBX has the next availible address, if we
	;assume there is enough room in the queue to add 

test_overflow:
	;this tests to see if there is enough room in the queue to add a new element
	;
	;EBX has the test address

	CMP EBX, 4[EDI]		;check if next availible address is equal to outptr
	JE full				;if they are equal, then queue is full
						;and no queueing happens

	;otherwise, we can queue


	MOV queue_address_var, EDI
	


	MOV ESI, msg_address_var				;ESI has address of message block
	MOV EDI, 0[queue_address_var]			;EDI has inptr

	MOV ECX, message_size	;ECX has the number of bytes per message
	CLD
	REP MOVSB				;copy message ocer

	;restore source and dest
	MOV ESI, msg_address_var
	MOV EDI, queue_address_var

	;;;;whaaaaaaaaaaatttttt...........................
	MOV ECX, queue_address_var
	MOV 0[queue_address_var], EBX		;then update inptr to EBX

	MOV ECX, 0			;set ecx
	MOV 0[ESI], ECX		;and clear buffer's status

	MOV EAX, EBX			
	JMP done
full:
	MOV EAX, 0			;set EAX to error code 0
done:
	RET
queue_p ENDP




;Precondition: ESI has address of the queue
;Precondition: EDI has address of memory block to store result
;
;
;
;Postcondition: outptr is updated
;Postcondition: Message is copied to address block at EDI
;Postcondition: EAX is 0 if we can't dequeue
dequeue_p PROC USES EBX ECX EDX
	MOV EBX, 4[ESI]		;EBX has outptr
	MOV EAX, EBX			;EAX also has outptr

	CMP EBX, 0[ESI]		;check if queue is empty if outptr == intpr
	JE empty
						
						;otherwise not empty
	ADD EBX, message_size	;so we update EBX to next address
						
	MOV ECX, ESI			;set ECX up for wrap test
	ADD ECX, 8			;
	ADD ECX, queue_size		;ECX has out of bounds address

	CMP EBX, ECX			;check for wrap_around
	JGE wrap				;jump if wrap
	
	MOV temp_address0, EBX	;save new out ptr
	JMP move
wrap:
	MOV EBX, ESI
	ADD EBX, 8
	MOV temp_address0, EBX

move:
	PUSH EDI
	MOV EDX, 4[ESI]
	MOV ESI, 	EDX	;esi has old outptr
						;edi is already set 
	MOV ECX, message_size	;set up ecx
	CLD
	rep MOVSB				;move

	MOV EAX, temp_address0
	MOV 4[ESI], EAX		;update new outptr
	POP EDI
	MOV EAX, EDI
	JMP done
empty:
	MOV EAX, 0
done:
	RET
dequeue_p ENDP


;=================
fileReader_p PROC

;Let user input a file name
	mWrite	"Please enter an input file name: "
	mov edx, OFFSET file_name
	mov ecx, SIZEOF file_name
	call ReadString

;Open the file for input
	mov edx, OFFSET file_name
	call OpenInputFile
	mov file_handle, eax

;Check for errors
	cmp eax, INVALID_HANDLE_VALUE			; error opening file?
	jne file_ok								; no: skip
	mWrite <"Cannot open file",0dh,0ah>
	jmp quit								; and quit

file_ok:

;Read the file into a buffer
	mov edx, OFFSET file_buffer
	mov ECX, OFFSET FILE_BUFFER_SIZE
	call ReadFromFile
	jnc check_buffer_size					; error reading?
	mWrite "Error reading file. "			; yes: show error message
	call WriteWindowsMsg
	jmp close_file

check_buffer_size:
	cmp eax, FILE_BUFFER_SIZE				;buffer large enough?
	jb buf_size_ok							;yes
	mWrite	<"Error: Buffer too small for the file",0dh,0ah>
	jmp quit

buf_size_ok:
	mov file_buffer[eax], 0						;insert null terminator
	mWrite "File size: "
	call WriteDec							;display file size
	mov file_size, eax						;store size (length) of file
	call Crlf
	
;Display the buffer
	mWrite <"File oontents:",0dh,0ah,0dh,0ah>
	mov edx, OFFSET file_buffer					; display the buffer
	call WriteString
	call Crlf
	
;Parse file and get data

;Read until [ENTER]

mov ebx, 0										;use as counter
	mov edx, offset file_buffer
	mov eax, [edx+ebx]
	mov ecx, 4									;4 bytes for ParseInteger32
	
	call ParseInteger32							;convert character to integer
	jo not_number_error							;skip if not a valid number
	
	call Crlf
	call WriteDec								;display node count
	mov node_count, eax
	
	cmp eax, 2
	jl number_too_low_error
	
	cmp eax, 26
	jg number_too_high_error	
	
	jmp read_conn_char
	
	not_number_error:
		mov edx, offset error_not_number
		call WriteString
		jmp quit
		
	number_too_low_error:
		mov edx, offset error_number_too_low
		call WriteString
		jmp quit
		
	number_too_high_error:
		mov edx, offset error_number_too_high
		call WriteString
		jmp quit
		
;Read main connection character
read_conn_char:
call Crlf
mov line_count, 0
;Loop until first valid character, get main connection
L1:
	mov eax, 0
	inc ebx											;move to next character
	mov temp_counter1, ebx							;save ebx
	mov al, byte ptr [edx+ebx]
	call WriteChar
	mov mainNode, al								;save main node
	
	cmp al, 'A'										;avoid any character less than "A"
	jl L1
	
	cmp al, 'Z'										;avoid any character greater than "Z"
	jg L1
	
	mov char, al									;save the character
	mov ecx, node_count					
	mov al, 'A'										;move "A into" AL						
	add al, cl										;add node count to AL
	cmp char, al									;check if char is out of bounds
	jge out_of_bounds_error
	
	;If all is well, convert char to index
	mov ebx, 0
	mov bl, char									;move char into bl for processing
	sub bl, 'A'										;check difference from "A", convert to index
	mov h_index, bl									;move bl to h_index
	mov ebx, temp_counter1							;restore ebx
	
	;Loop until ';' character, converting each character into v_index, and  placing pointers
	mov eax, 0
	L2:
		inc ebx
		mov temp_counter2, ebx						;save ebx
		mov al, byte ptr [edx+ebx]
		call WriteChar								;print the character
		mWrite " "									;print some space
		cmp al, mainNode
		je same_connection_error
		
		
		push edx									;Save registers
		push ebx									;Save registers
		
		cmp al, ';'									;semicolon terminates line of nodes connected to
		je line_complete
		
		cmp al, 'A'									;avoid any character less than "A"
		jl L2
		
		cmp al, 'Z'    				   				;avoid any character greater than "Z"
		jg L2
		
		;Test if character is out of bounds
		mov char, al									;save the character
		mov ecx, node_count					
		mov al, 'A'										;move "A into" AL						
		add al, cl										;add node count to AL
		cmp char, al									;check if char is out of bounds
		jge out_of_bounds_error
		
		;If all is well, convert char to index
		mov ebx, 0
		mov bl, char									;move char into bl for processing
		sub bl, 'A'										;check difference from "A", convert to index
		mov v_index, bl									;move bl to v_index
		mov ebx, temp_counter2							;restore ebx
		
		;Save registers
		mov saveEAX, eax								
		mov saveEBX, ebx
		mov saveEDX, edx
		
		;CREATE CONNECTION
		;Convert h_index -> EAX, and v_index -> EBX into a pointer
		
			;Move h_index and v_index into registers for conversion
			movzx eax, h_index
			movzx ebx, v_index
			
			CALL get_pointer_p
			MOV temp_address2, EDX
			MOV ESI, 0[EDX]

			;CMP ESI, 0 - file should not need this code
			;JNE existing_connection - file should not need this

			;else connection does not exist, then we create a new connection

			INVOKE HeapAlloc, my_heap, dwFlags, buffer_size
			MOV EDX, temp_address2
			MOV [EDX], EAX

			MOVZX EBX, h_index
			MOVZX EAX, v_index			

			ADD AL, 65d
			CALL WriteChar
			MOV AL, BL
			ADD AL, 65d
			mWrite "->"
			CALL WriteChar
			MOV EDX, OFFSET connection_established_text
			CALL WriteString
			CALL Crlf
			Call Crlf	
			Call Display_connections_p
		
		;CREATE CONNECTION COMPLETE
		;Restore registers
		mov eax, saveEAX
		mov ebx, saveEBX
		mov edx, saveEDX
		
	jmp L2
		
		
	
	
	jmp quit
	;AL has only A to Z
	
	;call WriteChar
	same_connection_error:
		mov edx, offset error_same_connection
		call WriteString
		jmp close_file
	
	out_of_bounds_error:
		mov edx, offset error_out_of_bounds
		call WriteString
		jmp close_file
	
	line_complete:
		mov edx, offset note_line_complete
		inc line_count									   ;counts number of lines, which must equal node_count
		call WriteString
		mov eax, line_count
		cmp eax, node_count
		je close_file
		pop ebx
		pop edx
		jmp L1		
		
		
		
		jmp close_file
		
	
	


	call Crlf
	call Crlf
close_file:
	mov eax, file_handle
	call CloseFile

quit:
	exit

	ret
fileReader_p ENDP
;
;=================



simulate_p PROC

.data
	previous_text0 BYTE "Previous node is: ",0
	time_arrived_text BYTE "Time arrived at this buffer: ", 0
	connection_text BYTE "Connection: ", 0
	nmc_text BYTE "This node generated: ",0
	msg_txt BYTE " message(s)",0

.code

still_have_active:
	MOV EAX, 0
	MOV current_cycle_message_count, EAX		;clears the count for this cycle



	MOV count0, 0			;count0 iterates nodes
	MOV count1, 0			;count1 iterates connections per node
	;queue to buffer
for_each_node0:
	MOV EAX, count0			;check if we are done
	CMP EAX, node_count			;
	JGE end_for_each_node0		;

	;block that gets node address
	MOV EAX, count0			;set up eax
	MOV EBX, count0			;and ebx to
	CALL get_pointer_p			;get ptr to node address
	MOV EAX, [EDX]				;ESI has node address
	MOV temp_address0, EAX		;temp_address0 has node address 


	MOV EDX, OFFSET system_time_text0
	CALL WriteString
	MOV EAX, system_time
	CALL WriteDec
	CALL CRLF


	MOV EDX, OFFSET current_node_text
	CALL WriteString
	MOV EAX, count0
	ADD EAX, 65d
	CALL WriteChar
	CALL CRLF

	;check if node has messages
	;by checking if inptr == outptr
	MOV ECX, temp_address0
	MOV EAX, 0[ECX]
	MOV EBX, 4[ECX]
	CMP EAX, EBX
	JE next_node0	;skip to next node if current node is empty

	;otherwise, current node has something in it
	
	MOV ESI, temp_address0			;move node address into esi

	MOV EDI, OFFSET temp_message		;move address of temp message into edi
	CALL dequeue_p					;read out the queue message into temp_message!!!!!!!!!!!!!!!!!!!!!!!!
	;temp_message has the message we dequeued
	;the message has been removed from queue, but not yet put in buffer


	MOV EAX, OFFSET temp_message		;
	MOV ESI, 20[EAX]				;load message's prev into esi
	MOV EAX, ESI					;mov prev index into eax

	MOV EDX, OFFSET previous_text0	;display previous
	CALL WriteString				;text
	ADD EAX, 65d					;and
	CALL WriteChar					;char

	CALL Crlf
	
	MOV EDX, OFFSET time_arrived_text	;display time arrived
	CALL WriteString				;
	MOV EDX, temp_address0
	MOV EAX, 12[EDX]		;
	CALL WriteDec					;

	;update the message's previous field to current node
	MOV EAX, count0				;
	MOV EDX, temp_address0
	MOV 20[EDX], EAX		;


	;print "for which node the message was generated and sent"............

	MOV node_messages_count, 0

	DEC queue_message_count

	;cycle through each buffer
	MOV count1, 0						
buffer_loop0:			;iterated with count1
	MOV EAX, count1
	CMP EAX, node_count
	;call WriteInt
	;call WaitMsg
	call Crlf
	JL end_buffer_loop0

	;access each buffer
	MOV EAX, count0
	MOV EBX, count1

	CMP EAX, EBX			;check for it is a node
	JE end_buffer_loop0		;and skip if is a node

	CALL get_pointer_p	;set up edx as address pointer
	MOV ESI, 0[EDX]	;load esi, 
	MOV EDX, ESI		;edx wtih address of buffer
	CMP EDX, 0		;check if buffer exists at all
	JE end_buffer_loop0	;if buffer doesn't exist, skip

	;otherwise, buffer exists
	call crlf

	MOV EAX, count1		;print connection
	ADD EAX, 65d
	CALL WriteChar

	MOV AL, '-'
	CALL WriteChar

	MOV AL, '>'
	CALL writechar

	MOV EAX, count0
	ADD EAX, 65d
	CALL WriteChar

	CALL Crlf


	MOV EAX, echo_flag			;if echo is 0, then we
	CMP EAX, 0
	JE message_into_buffer		;always send because we don't have to worry about echo
	
	;otherwise, get echo node, so we know which buffer to skip
	MOV EAX, OFFSET temp_message		;
	MOV EBX, 20[EAX]				;ebx has prev index
	CMP EBX, count1
	JE end_buffer_loop0
	
message_into_buffer:
	;print message sent on this connection

	;set status to non-zero
	MOV EAX, OFFSET temp_message
	MOV EBX, 255
	MOV 0[EAX], EBX

	;access  buffer
	MOV EAX, count0
	MOV EBX, count1
	CALL get_pointer_p

	MOV ESI, OFFSET temp_message	;mov message address into esi
	MOV EDI, EDX				;move buffer address into edi
	MOV ECX, message_size
	CLD
	rep MOVSB				;transfer message into buffer
	;;WARNING error?
	INC buffer_message_count

	INC node_messages_count
	INC total_messages_generated
	INC current_cycle_message_count

end_buffer_loop0:
	INC count1
	MOV EAX, count1
	CMP EAX, node_count
	JGE done_with_node
	JMP buffer_loop0
	
done_with_node:

	MOV EDX, OFFSET nmc_text
	CALL WriteString
	MOV EAX, node_messages_count
	CALL WRiteDec
	MOV EDX, OFFSET msg_txt
	Call WriteString
	CAll crlf


next_node0:
	MOV count1, 0
	INC count0
	MOV EAX, count0
	;CALL WriteInt
	CALL Crlf
	JMP for_each_node0
	
end_for_each_node0:

;--QUEUE TO BUFFER DONE ABOVE-- --RIGHT NOW WORKING FINE

INC system_time

;--BUFFER TO QUEUE SECTION--   --WORKING ON THIS SECTION NOW


.data
	current_node_text BYTE "The current NODE being processed is: ", 0
	b_q_current_buffer_text BYTE "The current BUFFER being processed is: ", 0
	system_time_text0 BYTE "The current time is: ", 0
	msg_arrived_at_dest_text BYTE "Message arrived at ", 0
	msg_died_text BYTE "Message died",0
.code

	
	MOV EAX, 0
	MOV count0, EAX
b_to_q_for_each_node:				;count0 has node index
	
	MOV EAX, count0				;compare to see if we have
	CMP EAX, node_count				;check every node
	JGE done_b_to_q				;if we have, exit the b_to_q loop

	MOV EDX, OFFSET current_node_text	;print out the current
	CALL WriteString					;node that we are proccessing
	MOV EAX, count0					;
	ADD AL, 65						;
	CALL WriteChar						;
	CALL Crlf							;

								;set up inner loop to process
								;each buffer that the
								;current node has
								;
	MOV count1, 0					;count1 has buffer index
b_to_q_for_each_buffer:
	MOV EAX, count1				;check if we have processed
	CMP EAX, node_count				;all of node's connections
	JGE b_to_q_get_next_node			;

	MOV EAX, count0				;check for if we dealing with
	CMP EAX, count1				;a node in this loop
	JE b_to_q_get_next_buffer		;so we skip
	


	MOV EAX, count1				;check if connection exists
	MOV EBX, count0				;
	CALL get_pointer_p				;
	MOV ECX, 0[EDX]				;get the connection pointer
	MOV temp_address0, ECX			;save buffer address in temp_address0

	CMP ECX, 0					;if connection pointer is 0
	JE b_to_q_get_next_buffer		;then connection does not exist
								;and we should get the next buffer


	MOV EDX, OFFSET b_q_current_buffer_text	;print out the current
	CALL WriteString					;buffer that we are proccessing
	MOV EAX, count0					;check index
	ADD AL, 65						;
	CALL WriteChar						;
	MOV EAX, count1					;check index
	ADD AL, 65						;
	CALL WriteChar						;
	CALL Crlf							;

	MOV EDX, OFFSET system_time_text0	;print out current time
	CALL WriteString					;that we are processing the current buffer
	MOV EAX, system_time
	CALL WriteDec
	CALL Crlf

	MOV EDX, temp_address0
	MOV EAX, 0[EDX]				;get buffer status
									;
	CMP EAX, 0	 					;check if buffer is empty
	JE b_to_q_get_next_buffer				;if so, don't transmit and skip to next buffer


	DEC buffer_message_count
	
	;check if message is going to be sent to destination
	MOV EAX, count0
	CMP EAX, end_node
	JE is_dest

	;dec ttl
	MOV EDX, temp_address0
	MOV EAX, 16[EDX]	;load ttl into register
	DEC EAX					;update ttl
	MOV 16[EDX], EAX	;store result back in memory

	CMP EAX, 0
	JG still_alive
	;otherwise dead
	;so we dont' send

	MOV EDX, OFFSET msg_died_text
	CALL WriteString
	CALL Crlf
	JMP b_to_q_get_next_buffer
still_alive:
	INC queue_message_count		;

	MOV EDX, temp_address0
	MOV EAX, system_time		;update time received
	MOV 12[EDX], EAX	;

	MOV EDX, temp_address0
	MOV EAX, count0					;update prev
	MOV 12[EDX], EAX

	MOV EAX, count0				;get node address
	MOV EBX, count0				;
	CALL get_pointer_p				;
	MOV ESI, 0[EDX]
	MOV EDX, ESI			;

	MOV EDI, EDX					;EDX has queue address
	MOV ESI, temp_address0			;temp_address0 is buffer address
	CALL queue_p
	
	PUSH EDX
	MOV EDX, temp_address0
	MOV EAX, 0					;clear buffer
	MOV 0[EDX], EAX		;by zeroing status
	POP EDX

	JMP b_to_q_get_next_buffer
is_dest:
	MOV EDX, OFFSET msg_arrived_at_dest_text
	CALL WriteString
	MOV EAX, count1
	ADD EAX, 65d
	CALL WriteChar
	CALL Crlf
	INC mesages_received_by_destination
	JMP b_to_q_get_next_buffer

b_to_q_get_next_buffer:
	INC count1				;count1 has buffer index
	JMP b_to_q_for_each_buffer
b_to_q_get_next_node:
	INC count0				;count0 has node index
	JMP b_to_q_for_each_node

done_b_to_q:
	MOV EAX, buffer_message_count
	ADD EAX, queue_message_count
	;EAX has total active packets
	CMP EAX, 0
	JG still_have_active

.data
	total_messages_text BYTE "Total messagess generated: ", 0
	final_time_text BYTE "Final time: ", 0
	dest_recieved_text BYTE "Number of packets received at destination: ", 0


	
.code
	MOV EDX, OFFSET total_messages_text
	CALL WriteString
	MOV EAX, total_messages_generated
	CALL WriteDec
	CALL Crlf
	CALL Crlf

	MOV EDX, OFFSET final_time_text
	CALL WriteString
	MOV EAX, system_time
	CALL WriteDec
	CALL Crlf
	CALL Crlf

	MOV EDX, OFFSET mesages_received_by_destination
	CALL WriteString
	MOV EAX, mesages_received_by_destination
	CALL WriteDec
	CALL Crlf
	CALL Crlf

	
	;final prints
	;print average hops
	ret

	;QUEUE to buffer done -- Now increment time and work on buffer to queue
simulate_p ENDP

END 