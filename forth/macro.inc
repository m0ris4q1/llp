%define _lw 0

; native identifier label flag
%macro native 3
 section .data
 wh_%2:
    dq _lw
 %define _lw wh_%2
    db %1, 0
    db %3
 xt_%2:
    dq impl_%2
 section .text
 impl_%2:
%endmacro

; native identifier label
%macro native 2
 native %1, %2, 0
%endmacro

; colon identifier label flag
%macro colon 3
 section .data
 wh_%2:
    dq _lw
 %define _lw wh_%2
    db %1, 0
    db %3
 xt_%2:
    dq impl_docol
%endmacro

; colon identifier label
%macro colon 2
 colon %1, %2, 0
%endmacro

%macro rpush 1
    sub rstack, 8
    mov qword [rstack], %1
%endmacro

%macro rpop 1
    mov %1, qword [rstack]
    add rstack, 8
%endmacro

%macro branch 1
    dq xt_branch
    dq %1 - $ - 8
%endmacro

%macro branch0 1
    dq xt_branch0
    dq %1 - $ - 8
%endmacro
