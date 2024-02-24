global _start

%define INTERPRETER_MODE 0
%define COMPILER_MODE 1

%define BUF_LEN 1024

%include "lib.inc"
%include "macro.inc"

%define pc      r15
%define w       r14
%define rstack  r13

section .text
%include "words.inc"

section .bss
    resq 1023
rstack_start:
    resq 1
input_buf:
    resb BUF_LEN
user_dict:
    resq 65536
user_mem:
    resq 65536

section .data
state:
    dq INTERPRETER_MODE
last_word:
    dq _lw
here:
    dq user_dict
stack_base:
    dq 0        ; stores the data stack base

section .rodata
interpreter_stub:
    dq xt_interpreter
msg_no_word:
    db ": no such word", 10, 0

section .text
_start:
    jmp impl_init
next:
    mov w, [pc]
    add pc, 8
    jmp [w]

find_word:
    push rdi
    mov rsi, [last_word]
.loop:
    mov rdi, [rsp]
    push rsi
    add rsi, 8
    call string_equals
    pop rsi
    test rax, rax
    jnz .found
    mov rsi, [rsi]
    test rsi, rsi
    jnz .loop
.not_found:
    mov qword [rsp], 0
    pop rax
    ret
.found:
    mov [rsp], rsi
    pop rax
    ret

; code from address
cfa:
    push rdi
    pop rsi
    add rsi, 8
.loop:
    mov al, [rsi]
    test al, al
    jz .end
    inc rsi
    jmp .loop
.end:
    add rsi, 2
    push rsi
    pop rax
    ret

section .data
xt_interpreter:
    dq impl_interpreter

section .text
impl_interpreter:
.start:
    mov rdi, input_buf
    mov rsi, BUF_LEN
    call read_word
    test rax, rax
    jz .err
    test rdx, rdx
    jz .end

    mov rdi, rax
    call find_word
    test rax, rax
    jz .number

    mov rdi, rax
    call cfa
    cmp qword [state], COMPILER_MODE
    je .compile_xt

.execute:
    mov pc, interpreter_stub
    mov w, rax
    jmp [rax]

.number:
    mov rdi, input_buf
    call parse_int
    test rdx, rdx
    jz .no_word
    cmp qword [state], COMPILER_MODE
    je .compile_num

    push rax
    jmp .start

.no_word:
    mov rdi, input_buf
    call eprint_string
    mov rdi, msg_no_word
    call eprint_string
    jmp .start

.end:   ; xt_bye
    mov rdx, SYS_EXIT
    mov rdi, EXIT_SUCCESS
    syscall
.err:   ; xt_fatal
    mov rdx, SYS_EXIT
    mov rdi, EXIT_FAILURE
    syscall

.compile_xt:
    cmp byte [rax - 1], IMMEDIATE_FLAG
    je .execute
    mov rdx, [here]
    mov [rdx], rax
    add qword [here], 8
    jmp .start

.compile_num:
    mov rdx, [here]
    cmp qword [rdx - 8], xt_branch
    je .skip_lit
    cmp qword [rdx - 8], xt_branch0
    je .skip_lit
    mov qword [rdx], xt_lit
    add rdx, 8
.skip_lit:
    mov [rdx], rax
    add rdx, 8
    mov [here], rdx
    jmp .start
