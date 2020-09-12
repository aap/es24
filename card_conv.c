#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

// aufnahme	A (12)
// umkehr	U (11/12)
// minus 	- (11 signed overpunch on last digit)
// zähleranalyse Z
// Löschen	L

enum {
	Aufnahme = 1,
	Umkehr = 2,
	Minus = 4,
	Analyse = 8,
	Loeschen = 16
};

enum {
	// 12 digits starting here
	NumberCol = 0,
	AufnahmeCol = 20,
	UmkehrCol = 21,
	AnalyseCol = 22,
	LoeschenCol = 23
};

void
printcard(int flags, int64_t num)
{
	int i;
	char card[13][81];
	int64_t n;
	int d;

	// clear card
	for(i = 0; i < 13; i++){
		memset(card[i], ' ', 80);
		card[i][80] = '\0';
	}

	n = num;
	for(i = 0; i < 12; i++){
		d = n % 10;
		n /= 10;
		card[d][NumberCol+11 -i] = d + '0';
	}
	if(flags & Minus) card[11][NumberCol+11] = '_';
	if(flags & Aufnahme) card[12][AufnahmeCol] = 'A';
	if(flags & Umkehr) card[12][UmkehrCol] = 'U';
	if(flags & Analyse) card[12][AnalyseCol] = 'Z';
	if(flags & Loeschen) card[12][LoeschenCol] = 'L';

	printf("; %X %ld\n", flags, num);
	printf("%s\n", card[12]);
	printf("%s\n", card[11]);
	for(i = 0; i <= 9; i++)
		printf("%s\n", card[i]);
	printf(";------------------\n");
}

int
main()
{
	int flags;
	int64_t num;
	char line[80], *s;

nextline:
	while(fgets(line, 80, stdin)){
		flags = 0;
		s = line;
		while(*s){
			switch(*s){
			case 'a': case 'A': flags |= Aufnahme; break;
			case 'u': case 'U': flags |= Umkehr; break;
			case 'z': case 'Z': flags |= Analyse; break;
			case 'l': case 'L': flags |= Loeschen; break;
			case '0': case '1':
			case '2': case '3':
			case '4': case '5':
			case '6': case '7':
			case '8': case '9':
			case '-': case ' ': goto num;
			default:
				fprintf(stderr, "unknown char '%c', skipping line: %s", *s, line);
				goto nextline;
			}
			s++;
		}
num:
		num = strtoll(s, NULL, 10);
		if(num < -999999999999 || num > 999999999999)
			fprintf(stderr, "warning: %ld has more than 12 digits\n", num);
		if(num < 0){
			num = -num;
			flags |= Minus;
		}
		printcard(flags, num);
	}
	
	return 0;
}
