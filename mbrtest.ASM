org 0x0600
xchg bx,bx
cli
  xor ax,ax
  mov ds, ax                  ; Set Data Segment to 0
  mov es, ax                  ; Set Extra Segment to 0
  mov ss, ax                  ; Set Stack Segment to 0
  mov sp, ax                  ; Set Stack Pointer to 0
  .CopyLower:
    mov cx, 0x0100            ; 256 WORDs in MBR
    mov si, 0x07c00           ; Current MBR Address
    mov di, 0x0600            ; New MBR Address
    rep movsw                 ; Copy MBR
  jmp 0:LowStart              ; Jump to new Address
 
LowStart:
  sti                         ; Start interrupts
  mov BYTE [bootDrive], dl    ; Save BootDrive
  .CheckPartitions:           ; Check Partition Table For Bootable Partition
    mov bx, PT1               ; Base = Partition Table Entry 1
    mov cx, 4                 ; There are 4 Partition Table Entries
    .CKPTloop:
      mov al, BYTE [bx]       ; Get Boot indicator bit flag
      test al, 0x80           ; Check For Active Bit
      jnz .ReadVBR          ; We Found an Active Partition
      add bx, 0x10            ; Partition Table Entry is 16 Bytes
      dec cx                  ; Decrement Counter
      jnz .CKPTloop           ; Loop
    jmp $                 ; ERROR!
  .ReadVBR:
    mov WORD [PToff], bx
    mov di,bx
    mov bx,0x07c00
    inc di
    mov dh,BYTE[di]
    inc di
    mov cx,WORD[di]
    mov ah,0x02
    mov al,0x01
    int 13h

    cmp WORD [0x7DFE], 0xAA55 ; Check Boot Signature
    jne $                 ; Error if not Boot Signature
    mov si, WORD [PToff]      ; Set DS:SI to Partition Table Entry
    mov dl, BYTE [bootDrive]  ; Set DL to Drive Number
    jmp 0x7C00                ; Jump To VBR
 
times (218 - ($-$$)) nop      ; Pad for disk time stamp
 
DiskTimeStamp db 8 dup 0    ; Disk Time Stamp
 
bootDrive db 0                ; Our Drive Number Variable
PToff dw 0                    ; Our Partition Table Entry Offset

 
times (430 - ($-$$)) nop    ; Pad For MBR Partition Table
 
UID  db 16 dup 0               ; Unique Disk ID
PT1  db 0x80,0x00,0x02,0x00,0x06,0x0F,0x11,0x40,0x01,0x00,0x00,0x00,0xFF,0xC0 ,0x00,0x00            ; First Partition Entry
PT2  db 16 dup 0              ; Second Partition Entry
PT3  db 16 dup 0             ; Third Partition Entry
PT4  db 16 dup 0             ; Fourth Partition Entry
 
dw 0xAA55