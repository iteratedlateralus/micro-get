all: socket.o args.o url.o
	nasm -f elf main.asm -o micro-get.o
	gcc url.o socket.o micro-get.o args.o
socket.o:
	nasm -f elf socket.asm 
args.o:
	nasm -f elf args.asm 
url.o:
	nasm -f elf url.asm 
