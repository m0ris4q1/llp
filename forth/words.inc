%define NO_FLAG 0
%define IMMEDIATE_FLAG 1

%define SYS_EXIT 60
%define EXIT_SUCCESS 0
%define EXIT_FAILURE 1

native "init", init
    mov qword [state], INTERPRETER_MODE
    mov rstack, rstack_start
    mov pc, interpreter_stub
    cmp qword [stack_base], 0
    je .first
    mov rsp, [stack_base]
    jmp next
.first:
    mov [stack_base], rsp
    jmp next

native "bye", bye
    mov rax, SYS_EXIT
    mov rdi, EXIT_SUCCESS
    syscall

native "fatal", fatal
    mov rax, SYS_EXIT
    mov rdi, EXIT_FAILURE
    syscall

;---------------------------------------
; colon-related operations
;---------------------------------------

; Enter colon word
native "docol", docol
    rpush pc
    add w, 8
    mov pc, w
    jmp next

; Exits from colon word
native "exit", exit
    rpop pc
    jmp next

;---------------------------------------
; stack operations
;---------------------------------------

; Shows stack contents.
native ".S", show_stack
    mov rcx, [stack_base]
    cmp rcx, rsp
    jbe .empty
.loop:
    sub rcx, 8
    mov rdi, [rcx]
    push rcx
    call print_int
    pop rcx
    cmp rcx, rsp
    jbe .end
    push rcx
    mov rdi, ' '
    call print_char
    pop rcx
    jmp .loop
.end:
    call print_newline
.empty:
    jmp next

; (a b c -- b c a)
native "rot", rot
    pop rcx
    pop rdx
    pop rax
    push rdx
    push rcx
    push rax
    jmp next

; (a b -- b a)
native "swap", swap
    pop rdx
    pop rax
    push rdx
    push rax
    jmp next

; (a -- a a)
native "dup", dup
    push qword [rsp]
    jmp next

; (a -- )
native "drop", drop
    add rsp, 8
    jmp next

; ( -- mem_addr)
native "mem", mem
    push user_mem
    jmp next

; Drops element from stack and sends it to stdout
; (a -- )
native ".", dot
    pop rdi
    call print_int
    call print_newline
    jmp next

; Inputs a single character from stdin
; ( -- c)
native "key", key
    call read_char
    push rax
    jmp next

; Outputs a single character to stdout
; (c -- )
native "emit", emit
    pop rdi
    call print_char
    jmp next

;---------------------------------------
; memory operations
;---------------------------------------

; Stores value by address
; (addr data -- )
native "!", write
    pop rax
    pop rdx
    mov [rdx], rax
    jmp next

; Stores one byte by address
; (addr char -- )
native "c!", write_char
    pop rax
    pop rdx
    mov [rdx], al
    jmp next

; Fetches value from memory
; (addr -- data)
native "@", fetch
    pop rax
    push qword [rax]
    jmp next

; Fetches one byte from memory
; (addr -- char)
native "c@", fetch_char
    pop rax
    movzx rax, byte [rax]
    push rax
    jmp next

;---------------------------------------
; arithmetic operations
;---------------------------------------

; (x y -- s) where s = x + y
native "+", plus
    pop rax
    add [rsp], rax
    jmp next

; (x y -- d) where d = x - y
native "-", minus
    pop rax
    sub [rsp], rax
    jmp next

; (x y -- p) where p = x * y
native "*", mul
    pop rax
    pop rdx
    imul rdx
    push rax
    jmp next

; (x y -- q) where q = x / y
native "/", div
    pop rcx
    pop rax
    cqo
    idiv rcx
    push rax
    jmp next

; (x y -- r) where r = x % y
native "%", mod
    pop rcx
    pop rax
    cqo
    idiv rcx
    push rdx
    jmp next

; (x y -- b) where b = 1 | 0
native "=", equals
    pop rdx
    pop rax
    cmp rax, rdx
    sete al
    movzx rax, al
    push rax
    jmp next

; (x y -- b) where b = 1 | 0
native "<", less
    pop rdx
    pop rax
    cmp rax, rdx
    setl al
    movzx rax, al
    push rax
    jmp next

; (x y -- b) whre b = 1 | 0
colon ">", greater
    dq xt_swap
    dq xt_less
    dq xt_exit

;---------------------------------------
; logical operations
;---------------------------------------

; (x y -- b) where b = 1 | 0
native "and", and
    pop rdx
    pop rax
    test rax, rax
    jz .false
    test rdx, rdx
    jz .false
    push qword 1
    jmp next
.false:
    push qword 0
    jmp next

; (x y -- b) where b = 1 | 0
native "not", not
    pop rax
    test rax, rax
    setz al
    movzx rax, al
    push rax
    jmp next

; (x y -- b) where b = 1 | 0
colon "or", or
    dq xt_not
    dq xt_swap
    dq xt_not
    dq xt_and
    dq xt_not
    dq xt_exit

;---------------------------------------
; operations for compiler
;---------------------------------------

; Reads word from stdin and start defining it
colon ":", colon
.restart:
    dq xt_word
    branch0 .restart
    dq xt_lit, NO_FLAG, xt_inbuf, xt_create
    dq xt_state, xt_lit, COMPILER_MODE, xt_write
    dq xt_lit, impl_docol, xt_comma
    dq xt_exit

; Ends the current word definition
colon ";", semicolon, IMMEDIATE_FLAG
    dq xt_state, xt_lit, INTERPRETER_MODE, xt_write
    dq xt_lit, xt_exit, xt_comma
    dq xt_exit

; Jumps to location
; Location is an offset relative to the argument end
native "branch", branch
    add pc, [pc]
    add pc, 8
    jmp next

; Jumps to location if ToS = 0
; Location is an offset relative to the argument end
native "branch0", branch0
    pop rax
    test rax, rax
    jnz .skip
    add pc, [pc]
.skip:
    add pc, 8
    jmp next

; Pushes a value immediately following this XT
native "lit", lit
    push qword [pc]
    add pc, 8
    jmp next

; ( -- num_read)
native "word", word
    mov rdi, input_buf
    mov rsi, BUF_LEN
    call read_word
    push rdx
    jmp next

; ( -- buf_addr)
native "inbuf", inbuf
    push qword input_buf
    jmp next

; ( -- state_addr)
native "state", state
    push qword state
    jmp next

; Create an entry in the dictionary
; (flags name -- )
native "create", create
.link:
    mov rcx, [last_word]
    mov rsi, [here]
    mov [rsi], rcx
    mov [last_word], rsi
    add rsi, 8
.name:
    pop rdi
    push rsi
    mov rdx, BUF_LEN
    call string_copy
    pop rsi
    mov rdi, rsi
    push rsi
    call string_length
    inc rax;
    pop rsi
    add rsi, rax
.flags:
    pop rax
    mov [rsi], al
    inc rsi
.end:
    mov [here], rsi
    jmp next

; Add x to the word being defined
; (x -- )
native ",", comma
    mov rax, [here]
    pop qword [rax]
    add qword [here], 8
    jmp next

;---------------------------------------
; debug
;---------------------------------------

native "last_word", last_word
    push qword last_word
    jmp next

native "word_name", word_name
    pop rdi
    push rdi
    add rdi, 8
    call print_string
    call print_newline
    jmp next

native "next_word", next_word
    pop rax
    push qword [rax]
    jmp next
