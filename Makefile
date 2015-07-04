all:
	nasm -f elf main.asm -o micro-get.o
	gcc micro-get.o
