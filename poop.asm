format ELF64 executable 3
entry start

segment readable

arg_err:	db	"Usage: ./prog <file>",10
arg_err_len	=	$ - arg_err

open_err:	db	"Error opening file with open()",10
open_err_len	=	$ - open_err

size_msg:	db	"now obtaining size",10
size_msg_len	=	$ - size_msg

fstat_err:	db	"Error obtaining file info with fstat()",10
fstat_err_len	=	$ - fstat_err

map_err:	db	"Error creating virtual page with mmap()",10
map_err_len 	=	$ - map_err

ARG_LIMIT = 2

SYS_WRITE = 0x1
SYS_EXIT = 0x3c
SYS_OPEN = 0x2
SYS_FSTAT = 0x5
SYS_MMAP = 0x9
SYS_UNMAP = 0x11
SYS_CLOSE = 0x3
PROT_READ = 0x1
MAP_PRIVATE = 0x2

;Structs
;================================================

struc ARGS {
	.argc	rq	1
	.argv	rq	1
	.arg1	rq	1
}
virtual at 0
	ARGS ARGS 
	sizeof.ARGS = $ - ARGS
end virtual


struc STAT {
	.st_dev		rq	1
	.st_ino		rq	1
	.st_nlink	rq	1
	.st_mode	rd	1
	.st_uid		rd	1
	.st_gid		rd	1
	.pad0		rb	4
	.st_rdev	rq	1
	.st_size	rq	1
	.st_blksize	rq	1
	.st_blocks	rq	1
	.st_atime	rq	1
	.st_atime_nsec	rq	1
	.st_mtime	rq	1
	.st_mtime_nsec	rq	1
	.st_ctime	rq	1
	.st_ctime_nsec	rq	1
}
virtual at 0
	STAT STAT
	sizeof.STAT = $ - STAT
end virtual

segment readable writeable

segment readable executable

;Macros
;=================================================
macro fail msg*,len {

	mov	rax,SYS_WRITE
	lea	rsi,[msg]
	mov	rdi,1
	mov	rdx,len
	syscall
	
	jmp	.epilogue
}

macro success jump_point {
	test	rax,rax
	jns	jump_point
}


start:
	mov	rbp,rsp

	mov	rax,[rbp+ARGS.argc]
	cmp	rax,ARG_LIMIT
	je	.open

	fail	arg_err,arg_err_len

	.open:
		mov	rdi,[rbp+ARGS.arg1]
		xor	rsi,rsi			;read only
		xor	rdx,rdx	
		mov	rax,SYS_OPEN
		syscall

		success	.obtain_size

		fail	open_err,open_err_len
	
	.obtain_size:
		sub	rsp,136
		mov	r12,rax
		mov	rax,SYS_FSTAT
		mov	rdi,r12
		lea	rsi,[rsp]
		syscall

		mov	r13,[rbp-136+STAT.st_size]
		add	rsp,136

		success	.map_file

		fail	fstat_err,fstat_err_len
				
	.map_file:
		mov	rax,SYS_MMAP
		xor	rdi,rdi	
		mov	rsi,r13		
		mov	rdx,PROT_READ	
		mov	r10,MAP_PRIVATE		
		mov	r8,r12		
		xor	r9,r9		
		syscall
		mov	r14,rax

		success	.output_file

		fail	map_err,map_err_len	
		
	.output_file:
		mov	rax,SYS_WRITE
		mov	rdi,1
		mov	rsi,r14
		mov	rdx,r13
		syscall

	.unmap_file:
		mov	rax,SYS_UNMAP
		mov	rdi,r14
		mov	rsi,r13
		syscall

	.close_fd:
		mov	rax,SYS_CLOSE
		mov	rdi,r12
		syscall


	.epilogue:
		mov	rax,SYS_EXIT
		syscall
