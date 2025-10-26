; bootloader.asm - 512 bytes
BITS 16
ORG 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Set 80x25 text mode
    mov ah, 0x00
    mov al, 0x03
    int 0x10

    ; Print loading message
    mov si, load_msg
    call print
    call newline

    ; Load kernel from floppy (sector 2 and onward) into 0x0800
    mov ah, 0x02       ; read sectors
    mov al, 4          ; number of sectors to read (adjust as needed)
    mov ch, 0          ; cylinder
    mov cl, 2          ; sector 2
    mov dh, 0          ; head
    mov dl, 0x00       ; drive 0 (first floppy)
    mov bx, 0x0800     ; destination in memory
    int 0x13
    jc load_fail       ; jump if error

    ; Jump to kernel
    jmp 0x0000:0x0800

load_fail:
    mov si, fail_msg
    call print
    cli
    hlt
    jmp $

; -----------------------
; Print helpers
; -----------------------
print:
.print_loop:
    lodsb
    cmp al, 0
    je .ret
    mov ah, 0x0E
    int 0x10
    jmp .print_loop
.ret:
    ret

newline:
    mov al, 0x0D
    mov ah, 0x0E
    int 0x10
    mov al, 0x0A
    int 0x10
    ret

; -----------------------
; Messages
; -----------------------
load_msg db "Loading kernel...",0x0D,0x0A
        db "tudifyBootloader 0.5",0
fail_msg db "Failed to load kernel!",0

; Fill bootloader to 512 bytes
times 510-($-$$) db 0
dw 0xAA55