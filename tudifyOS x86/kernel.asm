; kernel.asm - fully patched mini OS kernel (with password + lock support)
BITS 16
ORG 0x0800

start_kernel:
    xor ax, ax
    mov ss, ax
    mov sp, 0x7C00

    mov si, welcome_msg
    call print
    call newline

    mov si, login_msg
    call print
    call newline
    call read_line
    mov si, cmd_buf
    mov di, user_name
    call strcpy

    mov si, setpass_boot_prompt
    call print
    call newline
    call read_line
    mov si, cmd_buf
    lodsb
    cmp al,'y'
    je .do_set_at_boot
    cmp al,'Y'
    jne .boot_done
.do_set_at_boot:
    call set_password
.boot_done:

kernel_loop:
    mov si, user_name
    call print
    mov si, prompt_suffix
    call print

    call read_line
    mov si, cmd_buf

    ; --- Easter Egg 1 - only fire ---
    mov di, onlyfire_str
    call cmd_starts_with
    cmp al,0
    je do_onlyfire

    ; --- learn your gods ---
    mov di, credits_str
    call cmd_starts_with
    cmp al,0
    je do_credits

    ; --- shutdown ---
    mov di, shutdown_str
    call cmd_starts_with
    cmp al,0
    je do_shutdown

    ; --- help ---
    mov di, help_str
    call cmd_starts_with
    cmp al,0
    je do_help

    ; --- echo ---
    mov di, echo_str
    call cmd_starts_with
    cmp al,0
    je do_echo

    ; --- time ---
    mov di, time_str
    call cmd_starts_with
    cmp al,0
    je do_time

    ; --- cls ---
    mov di, cls_str
    call cmd_starts_with
    cmp al,0
    je do_cls

    ; --- info ---
    mov di, info_str
    call cmd_starts_with
    cmp al,0
    je do_info

    ; --- ls ---
    mov di, ls_str
    call cmd_starts_with
    cmp al,0
    je do_ls

    ; --- cat ---
    mov di, cat_str
    call cmd_starts_with
    cmp al,0
    je do_cat

    ; --- run ---
    mov di, run_str
    call cmd_starts_with
    cmp al,0
    je do_run

    ; --- touch ---
    mov di, touch_str
    call cmd_starts_with
    cmp al,0
    je do_touch

    ; --- rm ---
    mov di, rm_str
    call cmd_starts_with
    cmp al,0
    je do_rm

    ; --- setuser ---
    mov di, setuser_str
    call cmd_starts_with
    cmp al,0
    je do_setuser

    ; --- setpass ---
    mov di, setpass_str
    call cmd_starts_with
    cmp al,0
    je do_setpass

    ; --- lock ---
    mov di, lock_str
    call cmd_starts_with
    cmp al,0
    je do_lock

    ; Unknown command
    mov si, unk_msg
    call print
    call newline
    jmp kernel_loop

; -----------------------
; Command Handlers
; -----------------------
do_shutdown:
    mov si, shutting_msg
    call print
    call newline
    cli
.halt:
    hlt
    jmp .halt

do_help:
    mov si, help_msg
    call print
    call newline
    jmp kernel_loop

do_echo:
    mov si, cmd_buf
    call skip_word
    call print
    call newline
    jmp kernel_loop

do_time:
    mov si, time_msg
    call print
    call newline
    jmp kernel_loop

do_cls:
    mov cx,100*80
.clear_loop:
    mov al,' '
    mov ah,0x0E
    int 0x10
    loop .clear_loop
    jmp kernel_loop

do_onlyfire:
    mov si, onlyfire_msg
    call print
    call newline
    jmp kernel_loop

do_credits:
    mov si, credits_msg
    call print
    call newline
    jmp kernel_loop

do_info:
    mov si, info_msg
    call print
    call newline
    jmp kernel_loop

do_ls:
    mov si, fs_files
.ls_loop:
    lodsb
    cmp al,0
    je .ls_done
    dec si
    mov cx,8
.print_name:
    lodsb
    cmp al,0
    je .next_file
    mov ah,0x0E
    int 0x10
    loop .print_name
.next_file:
    call newline
    add si,16
    jmp .ls_loop
.ls_done:
    jmp kernel_loop

do_cat:
    mov si, cmd_buf
    call skip_word
    call run_file      ; same as run
    jmp kernel_loop

do_run:
    mov si, cmd_buf      ; SI -> user input
    call skip_word       ; skip "run "
    mov di, fs_files     ; DI -> start of file list
.next_file:
    mov bx, si           ; save pointer to filename argument
    push di
    push si
    call strcmp_filename ; compare input with current file name
    pop si
    pop di
    cmp al,0
    je .found_file
    add di,16            ; move to next file entry (8 bytes filename + 8 bytes content)
    mov al,[di]
    cmp al,0
    jne .next_file
    ; no file found
    mov si, unk_msg
    call print
    call newline
    jmp kernel_loop
.found_file:
    lea si,[di+8]        ; content starts after 8-byte filename
    call print
    call newline
    jmp kernel_loop

; Compare null-terminated strings: SI = user input, DI = file name
; AL = 0 if equal, 1 if not
strcmp_filename:
.cmp_loop:
    mov al,[si]
    mov bl,[di]
    cmp al,bl
    jne .not_equal
    cmp al,0
    je .equal
    inc si
    inc di
    jmp .cmp_loop
.not_equal:
    mov al,1
    ret
.equal:
    xor al,al
    ret
do_touch:
    mov si, cmd_buf
    call skip_word
    call create_file
    jmp kernel_loop

do_rm:
    mov si, cmd_buf
    call skip_word
    call delete_file
    jmp kernel_loop

do_setuser:
    mov si, change_user_msg
    call print
    call newline
    call read_line
    mov si, cmd_buf
    mov di, user_name
    call strcpy
    jmp kernel_loop

do_setpass:
    call set_password
    jmp kernel_loop

do_lock:
    mov al,[password_set]
    cmp al,0
    jne .locked
    mov si, no_pass_msg
    call print
    call newline
    jmp kernel_loop
.locked:
    mov cx,100*80
.clear_for_lock:
    mov al,' '
    mov ah,0x0E
    int 0x10
    loop .clear_for_lock

    mov si, locked_msg
    call print
    call newline

.lock_loop:
    mov si, enter_pass_prompt
    call print
    call newline
    call read_password
    mov si, cmd_buf
    mov di, password_buf
    call strcmp
    cmp al,0
    je .unlocked
    mov si, bad_pass_msg
    call print
    call newline
    mov ah,0x0E
    mov al,7
    int 0x10
    jmp .lock_loop
.unlocked:
    mov si, unlocked_msg
    call print
    call newline
    jmp kernel_loop

; -----------------------
; File helpers
; -----------------------
run_file:
    mov di, fs_files   ; start of fs_files
.search_loop:
    lodsb               ; load file name char
    cmp al,0            ; end of files?
    je .not_found
    dec si              ; restore pointer for strcmp
    mov bx, si          ; save pointer to argument
    mov si, bx
    mov dx, di          ; save pointer to file name
    call strcmp         ; compare file name to argument
    cmp al,0
    je .found
    ; skip to next file (16 bytes per entry)
    add di,16
    jmp .search_loop
.found:
    ; DI points to file name, content starts at DI+8
    lea si,[di+8]
    call print
    call newline
    ret
.not_found:
    mov si, unk_msg
    call print
    call newline
    ret

create_file:
    mov si, cmd_buf
    mov di, fs_files
    mov byte [di],'?' ; placeholder
    ret

delete_file:
    mov si, cmd_buf
    mov di, fs_files
    mov byte [di],0
    ret

; -----------------------
; Command helpers
; -----------------------
skip_word:
    mov cx,0
.sw_loop:
    cmp byte [si],' '
    je .done_skip
    cmp byte [si],0
    je .done_skip
    inc si
    inc cx
    cmp cx,32
    ja .done_skip
    jmp .sw_loop
.done_skip:
    cmp byte [si],' '
    jne .done
    inc si
.done:
    ret

cmd_starts_with:
    push si
.next_char:
    mov al,[di]
    cmp al,0
    je .matched      ; end of command in DI, matched so far
    mov bl,[si]
    cmp bl,al
    jne .no_match
    inc di
    inc si
    jmp .next_char
.matched:
    ; make sure the next char in SI is space or null
    mov al,[si]
    cmp al,' '
    je .ok
    cmp al,0
    je .ok
    jmp .no_match
.ok:
    xor al,al
    pop si
    ret
.no_match:
    mov al,1
    pop si
    ret

print:
.print_loop:
    lodsb
    cmp al,0
    je .ret
    mov ah,0x0E
    int 0x10
    jmp .print_loop
.ret:
    ret

newline:
    mov al,0x0D
    mov ah,0x0E
    int 0x10
    mov al,0x0A
    int 0x10
    ret

read_line:
    mov di, cmd_buf
    xor cx,cx
.rl_loop:
    mov ah,0x00
    int 0x16
    cmp al,0x0D
    je .done_read
    cmp al,0x08
    je .handle_bs
    cmp al,0x00
    je .rl_loop
    cmp al,0x20
    jb .rl_loop
    cmp cx,31
    jae .beep
    mov [di],al
    inc di
    inc cx
    mov ah,0x0E
    int 0x10
    jmp .rl_loop
.handle_bs:
    cmp cx,0
    je .rl_loop
    dec di
    dec cx
    mov ah,0x0E
    mov al,0x08
    int 0x10
    mov al,' '
    int 0x10
    mov al,0x08
    int 0x10
    jmp .rl_loop
.beep:
    mov ah,0x0E
    mov al,7
    int 0x10
    jmp .rl_loop
.done_read:
    mov byte [di],0
    call newline
    ret

read_password:
    mov di, cmd_buf
    xor cx,cx
.rp_loop:
    mov ah,0x00
    int 0x16
    cmp al,0x0D
    je .rp_done
    cmp al,0x08
    je .rp_handle_bs
    cmp al,0x00
    je .rp_loop
    cmp al,0x20
    jb .rp_loop
    cmp cx,31
    jae .rp_beep
    mov [di],al
    inc di
    inc cx
    mov ah,0x0E
    mov al,'*'
    int 0x10
    jmp .rp_loop
.rp_handle_bs:
    cmp cx,0
    je .rp_loop
    dec di
    dec cx
    mov ah,0x0E
    mov al,0x08
    int 0x10
    mov al,' '
    int 0x10
    mov al,0x08
    int 0x10
    jmp .rp_loop
.rp_beep:
    mov ah,0x0E
    mov al,7
    int 0x10
    jmp .rp_loop
.rp_done:
    mov byte [di],0
    call newline
    ret

strcmp:
.cmp_loop:
    mov al,[si]
    mov bl,[di]
    cmp al,bl
    jne .not_equal
    cmp al,0
    je .equal
    inc si
    inc di
    jmp .cmp_loop
.not_equal:
    mov al,1
    ret
.equal:
    xor al,al
    ret

strcpy:
.copy_loop:
    lodsb
    stosb
    cmp al,0
    jne .copy_loop
    ret

set_password:
    mov si, setpass_msg
    call print
    call newline
    call read_password
    mov si, cmd_buf
    mov di, password_buf
    call strcpy
    mov byte [password_set],1
    mov si, pass_set_ok
    call print
    call newline
    ret

; -----------------------
; Data
; -----------------------
welcome_msg db "Welcome to tudifyOS",0x0D,0x0A
            db "[##########] 100%",0
login_msg db "Enter a root username: ",0
prompt_suffix db ">",0
change_user_msg db "Enter new root username: ",0

onlyfire_msg db "Fuck it up",0
unk_msg db "Unknown command",0
shutting_msg db "Shutting down...",0

shutdown_str db "shutdown",0
onlyfire_str db "onlyfire",0
credits_str db "credits",0
help_str db "help",0
echo_str db "echo",0
time_str db "time",0
cls_str db "cls",0
info_str db "info",0
ls_str db "ls",0
cat_str db "cat",0
run_str db "run",0
touch_str db "touch",0
rm_str db "rm",0
setuser_str db "setuser",0
setpass_str db "setpass",0
lock_str db "lock",0


credits_msg db "====CREDITS====",0x0D,0x0A
        db "~~~~Coding Lead~~~~",0x0D,0x0A
        db "me",0x0D,0x0A
        db "~~~~Official User(R)~~~~",0x0D,0x0A
        db "You",0


help_msg db "Commands: help, echo, time, cls, info, ls, cat, run, touch, rm, setuser, setpass, lock, shutdown, onlyfire, credits",0
time_msg db "Time: 12:34:56 (dummy)",0
info_msg db "tudifyOS v0.1",0x0D,0x0A
         db "tudifyOS is in Beta.",0x0D,0x0A
         db "Expect bugs and broken features.",0

setpass_boot_prompt db "Set a root password now? (y/n): ",0
setpass_msg db "Enter new password: ",0
pass_set_ok db "Password set.",0

locked_msg db "System locked.",0
enter_pass_prompt db "Enter password to unlock: ",0
bad_pass_msg db "Incorrect password.",0
no_pass_msg db "No password set. Use setpass to create one.",0
unlocked_msg db "Unlocked.",0

user_name times 16 db 0
cmd_buf times 32 db 0

password_buf times 16 db 0
password_set db 0

fs_files:
    db "hello", "Hello world app!",0
    db "test", "This is a test.",0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

times 2048-($-$$) db 0