bison -d -o src/minilisp.tab.c src/minilisp.y
gcc -c -g -I. -o src/minilisp.tab.o src/minilisp.tab.c
flex -o src/lex.yy.c src/minilisp.l
gcc -c -g -I. -o src/lex.yy.o  src/lex.yy.c
gcc -o bin/minilisp src/minilisp.tab.o src/lex.yy.o