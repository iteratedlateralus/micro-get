bitdown:
	nasm -f elf main.asm -o flood.o
	gcc errno.o flood.o
