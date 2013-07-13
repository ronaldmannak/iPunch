/* cardmake.c -- convert ASCII text to punched-card image format.
 *
 * operation:  run cardmake -help for instructions
 *
 * input  -- an ASCII file, 8 bits per character
 * output -- a card-image file, 12 bits/column, 80 columns/card.
 *
 * see the README file for details of the card image file format!
 *
 * author:  Douglas Jones, jones@cs.uiowa.edu
 * date:    March 5, 1996
 *          Feb  18, 1997  -- added command line options and support.
 *
 */

#include <stdio.h>
#define ERROR 00404
#include "cardcode.i"

main(argc,argv)
int argc;
char *argv[];
{
	FILE *ascii_fd, *card_fd;
	int arg = 1;
	int format = 80;
	int color = 0;
	int corner = 0;
	int cut = 2;
	int interp = 0;
	int punch = 4;
	int table = 4;
	int form = 1;
	int logo = 0;

	while ((arg < argc) && (argv[arg][0] == '-')) { /* command line arg */
		if (strcmp(argv[arg],"-H80") == 0) {
			format = 80;
		} else if (strcmp(argv[arg],"-H82") == 0) {
			format = 82;
		} else if (strcmp(argv[arg],"-cream") == 0) {
			color |= 0;
		} else if (strcmp(argv[arg],"-white") == 0) {
			color |= 1;
		} else if (strcmp(argv[arg],"-yellow") == 0) {
			color |= 2;
		} else if (strcmp(argv[arg],"-pink") == 0) {
			color |= 3;
		} else if (strcmp(argv[arg],"-blue") == 0) {
			color |= 4;
		} else if (strcmp(argv[arg],"-green") == 0) {
			color |= 5;
		} else if (strcmp(argv[arg],"-orange") == 0) {
			color |= 6;
		} else if (strcmp(argv[arg],"-brown") == 0) {
			color |= 7;
		} else if (strcmp(argv[arg],"-stripe") == 0) {
			color |= 8;
		} else if (strcmp(argv[arg],"-round") == 0) {
			corner = 0;
		} else if (strcmp(argv[arg],"-square") == 0) {
			corner = 1;
		} else if (strcmp(argv[arg],"-uncut") == 0) {
			cut = 0;
		} else if (strcmp(argv[arg],"-right") == 0) {
			cut = 1;
		} else if (strcmp(argv[arg],"-left") == 0) {
			cut = 2;
		} else if (strcmp(argv[arg],"-both") == 0) {
			cut = 3;
		} else if (strcmp(argv[arg],"-interp") == 0) {
			interp = 1;
		} else if (strcmp(argv[arg],"-noprint") == 0) {
			punch = 0;
		} else if (strcmp(argv[arg],"-026comm") == 0) {
			punch = table = 1;
		} else if (strcmp(argv[arg],"-026ftn") == 0) {
			punch = table = 2;
		} else if (strcmp(argv[arg],"-029") == 0) {
			punch = table = 4;
		} else if (strcmp(argv[arg],"-EBCDIC") == 0) {
			punch = 0;
			table = 8;
		} else if (strcmp(argv[arg],"-blank") == 0) {
			form = 0; logo = 0;
		} else if (strcmp(argv[arg],"-5081") == 0) {
			form = 1; logo = 0;
		} else if (strcmp(argv[arg],"-507536") == 0) {
			form = 2; logo = 0;
		} else if (strcmp(argv[arg],"-5280") == 0) {
			form = 3; logo = 0;
		} else if (strcmp(argv[arg],"-327") == 0) {
			form = 4; logo = 0;
		} else if (strcmp(argv[arg],"-733727") == 0) {
			form = 5; logo = 0;
		} else if (strcmp(argv[arg],"-888157") == 0) {
			form = 6; logo = 0;
		} else if (strcmp(argv[arg],"-FORTRAN") == 0) {
			form = 6; logo = 0;
		} else if (strcmp(argv[arg],"-help") == 0) {
			fprintf( stderr, "\n%s [options] [input [output]]\n\n",
				 argv[0] );
			fprintf( stderr,
			"Make a virtual punched card deck from an ASCII file.\n"
			"If output is missing, output to stdout; if input is\n"
			"also missing, input from stdin.  The options are:\n\n"
			" -H80 -H82       columns per card (H80 default)\n\n"
 			" -cream -white -yellow -pink      card colors\n"
			" -blue  -green -orange -brown     (cream default)\n\n"
 			" -stripe         color stripe, cream card (common)\n\n"
 			" -round -square  corners on cards (round default)\n\n"
 			" -uncut -both    which top corner is cut\n"
 			" -left  -right   (left default, right common)\n\n"
 			" -interp         this card has been interpreted\n\n"
 			" -026comm        what keypunch to use\n"
			" -029 -026ftn    (029 default)\n"
			" -EBCDIC         (uninterpreted and rare!)\n\n"
 			" -noprint        turn off printing in the punch\n\n"
 			" -blank -5081	  what preprinted form to use\n"
 			" -507536 -5280   (blank default, all common)\n"
			" -327 -733737\n"
			" -888157\n\n"
			);
			exit(-1);
		} else {
			fprintf( stderr, "%s: unknown option %s;"
					 " -help available\n",
				 argv[0], argv[arg] );
			exit(-1);
		}
		arg++;
	}

	if ( (argc - arg) > 2 ) { /* too many arguments */
		fprintf( stderr, "%s: too many arguments\n",
			argv[0] );
		exit(-1);
	}

	if ( (argc - arg) < 1 ) { /* no arguments, program is a filter */
		ascii_fd = stdin;
		card_fd = stdout;
	} else { /* at least one argument */
		ascii_fd = fopen(argv[arg],"r");
		if ( ascii_fd == NULL ) {
			fprintf( stderr, "%s %s: invalid ascii file\n",
				argv[0], argv[arg] );
			exit(-1);
		}
		if ( (argc - arg) < 2 ) { /* only one arguments */
			card_fd = stdout;
		} else { /* at least two arguments */
			card_fd = fopen(argv[arg+1],"w");
			if ( card_fd == NULL ) {
				fprintf( stderr, "%s %s: invalid card file\n",
					argv[0], argv[arg+1] );
				exit(-1);
			}
		}
	}

	/* output file prefix */
	fputc( 'H', card_fd );
	fputc( '8', card_fd );
	if (format == 80) {
		fputc( '0', card_fd );
	} else {
		fputc( '2', card_fd );
	}
	
	/* ready to process from ascii_fd to card_fd */

	while( !feof(ascii_fd)) {
		char line[82]; /* size allows for H82 format */
		int src_col = 1;
		int max_col;
		line[0] = ' ';
		line[81] = ' ';
		while (src_col < 81) {
			int cur_char = fgetc(ascii_fd);
			if ((cur_char == EOF) && (src_col == 1)) break;
			if ((cur_char == EOF) || (cur_char == '\n')) {
				while (src_col < 81) { /* blank out card */
					line[src_col] = ' ';
					src_col++;
				}
			} else if (cur_char == '\t') {
				do {
					line[src_col] = ' ';
					src_col++;
				} while(((src_col & 07) != 1)&&(src_col < 81));
			} else {
				line[src_col] = cur_char;
				src_col++;
			}
		}
		if (src_col == 1) break; /* avoid blank card for early EOF */

		/* put out prefix on card */
		fputc( 0x80 | (color << 3) | (corner << 2) | cut, card_fd );
		fputc( 0x80 | (interp << 6) | (punch << 3) | form, card_fd );
		fputc( 0x80 | logo, card_fd );

		if (format == 80) {
			src_col = 1;
			max_col = 80;
		} else { /* H82 */
			src_col = 0;
			max_col = 81;
		}
		while (src_col <= max_col) {
			char even_ch, odd_ch; /* source characters */
			int even_col, odd_col; /* corresponding 12 bit codes */
			char first, second, third; /* packed for output */

			/* get two columns */
			even_ch = line[src_col];
			src_col++;
			odd_ch = line[src_col];
			src_col++;
			
			/* convert to card codes */
			if (table == 1) {
				even_col = o26_comm_code[ even_ch ];
				odd_col = o26_comm_code[ odd_ch ];
			} else if (table == 2) {
				even_col = o26_ftn_code[ even_ch ];
				odd_col = o26_ftn_code[ odd_ch ];
			} else if (table == 4) {
				even_col = o29_code[ even_ch ];
				odd_col = o29_code[ odd_ch ];
			} else { /* table == 8 */
				even_col = EBCDIC_code[ even_ch ];
				odd_col = EBCDIC_code[ odd_ch ];
			}

			/* divide 2 columns into 3 bytes */
			first = even_col >> 4;
			second = ((even_col & 017) << 4)
			       | (odd_col >> 8);
			third = odd_col & 00377;

			/* output 3 bytes */
			fputc( first, card_fd );
			fputc( second, card_fd );
			fputc( third, card_fd );
		}
	}

	fclose(ascii_fd);
	fclose(card_fd);
}
