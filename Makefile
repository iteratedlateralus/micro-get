all: socket.o args.o
	nasm -f elf test-socket.asm -o micro-get.o
	gcc socket.o micro-get.o args.o
socket.o:
	nasm -f elf socket.asm 
args.o:
	nasm -f elf args.asm 
