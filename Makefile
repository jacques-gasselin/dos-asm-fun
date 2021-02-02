all: TEST.COM TEST2.COM SNAKE.COM

clean:
	rm -f *.COM

%.COM: %.ASM
	nasm -o $@ $<

