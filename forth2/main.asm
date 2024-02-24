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
msg_hello:
    db "Hello, world!", 10, 0

section .text
_start:
    jmp impl_init
next:
    mov w, [pc]
    add pc, 8
    jmp [w]
