global string_equals
global string_copy
global string_length
global print_newline
global print_int
global print_uint
global print_char
global print_string
global eprint_string
global parse_int
global parse_uint
global read_char
global read_word

string_equals:
    mov al, byte [rdi]
    cmp al, byte [rsi]
    jne .no
    test al, al
    jz .yes
    inc rdi
    inc rsi
    jmp string_equals
.yes:
    mov rax, 1
    ret
.no:
    xor rax, rax
    ret

; rdi <= srouce string address
; rsi <= destination buffer address
; rdx <= destination buffer length
; rax => destination address or 0
string_copy:
    push rdi
    push rsi
    push rdx
    call string_length
    pop rdx
    pop rsi
    pop rdi
    cmp rax, rdx
    jae .too_long
    push rsi
.loop:
    mov dl, byte [rdi]
    mov byte [rsi], dl
    test dl, dl
    jz .end
    inc rdi
    inc rsi
    jmp .loop
.end:
    pop rax
    ret
.too_long:
    xor rax, rax
    ret

string_length:
    xor rax, rax
.loop:
    cmp byte [rdi + rax], 0
    je .end
    inc rax
    jmp .loop
.end:
    ret

print_newline:
    mov rdi, 10
print_char:
    push rdi
    mov rdi, rsp
    call print_string
    pop rdi
    ret

print_string:
    push rdi
    call string_length
    pop rsi
    mov rdx, rax
    mov rax, 1  ; write
    mov rdi, 1  ; stdout
    syscall
    ret

print_int:
    test rdi, rdi
    jns print_uint
    push rdi
    mov rdi, '-'
    call print_char
    pop rdi
    neg rdi
print_uint:
    mov rax, rdi
    mov rdi, rsp
    push 0
    sub rsp, 16
    dec rdi
    mov r8, 10
.loop:
    xor rdx, rdx
    div r8
    or dl, 0x30
    dec rdi
    mov byte [rdi], dl
    test rax, rax
    jnz .loop
    call print_string
    add rsp, 24
    ret

eprint_string:
    push rdi
    call string_length
    pop rsi
    mov rdx, rax
    mov rax, 1  ; write
    mov rdi, 2  ; stderr
    syscall
    ret

; rax => number
; rdx => length
parse_uint:
    mov r8, 10
    xor rax, rax
    xor rcx, rcx
.loop:
    movzx r9, byte [rdi + rcx]
    cmp r9b, '0'
    jb .end
    cmp r9b, '9'
    ja .end
    xor rdx, rdx
    mul r8
    and r9b, 0x0f
    add rax, r9
    inc rcx
    jmp .loop
.end:
    mov rdx, rcx
    ret

; rax => number
; rdx => length
parse_int:
    mov al, byte [rdi]
    cmp al, '-'
    je .signed
    jmp parse_uint
.signed:
    inc rdi
    call parse_uint
    test rdx, rdx
    jz .error
    neg rax
    inc rdx
    ret
.error:
    xor rax, rax
    ret

read_char:
    push 0
    xor rax, rax        ; read
    xor rdi, rdi        ; stdin
    mov rsi, rsp
    mov rdx, 1
    syscall
    pop rax
    ret

; rdi <= buffer address
; rsi <= buffer length
; rax => start address of word or 0
; rdx => length of word if success
read_word:
    push r14
    push r15
    xor r14, r14
    mov r15, rsi
    dec r15     ; terminating nul
.trim:  ; leading white space
    push rdi
    call read_char
    pop rdi
    cmp al, 0x20        ; SP
    je .trim
    cmp al, 0x09        ; TAB
    je .trim
    cmp al, 0x0a        ; LF
    je .trim
    cmp al, 0x0d        ; CR
    je .trim
    test al, al
    jz .end
.loop:
    mov byte [rdi + r14], al
    inc r14
    push rdi
    call read_char
    pop rdi
    cmp al, 0x20        ; SP
    je .end
    cmp al, 0x09        ; TAB
    je .end
    cmp al, 0x0a        ; LF
    je .end
    cmp al, 0x0d        ; CR
    je .end
    test al, al
    jz .end
    cmp r14, r15
    je .too_long
    jmp .loop
.end:
    mov byte [rdi + r14], 0
    mov rax, rdi
    mov rdx, r14
    jmp .clean
.too_long:
    xor rax, rax
.clean:
    pop r15
    pop r14
    ret
