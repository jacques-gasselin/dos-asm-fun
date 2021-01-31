all: TEST.COM TEST2.COM

clean:
	rm -f *.COM

%.COM: %.ASM
	nasm -o $@ $<

