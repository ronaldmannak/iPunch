/* cardlist.c -- convert punched-card image format to ASCII text.
 *
 * operation:  run cardlist -help for information
 *
 * input  -- a card-image file, 12 bits/column, 80 columns/card.
 * output -- an ASCII file, 8 bits per character.
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

char ascii_code[4096];

main(argc,argv)
int argc;
char *argv[];
{
	FILE *ascii_fd, *card_fd;
	int arg = 1;
	int format = 80;
	int table = 3;
	int dump = 0;
	while ((arg < argc) && (argv[arg][0] == '-')) { /* command line arg */
		if (strcmp(argv[arg],"-026comm") == 0) {
			table = 1;
		} else if (strcmp(argv[arg],"-026ftn") == 0) {
			table = 2;
		} else if (strcmp(argv[arg],"-029ftn") == 0) {
			table = 3;
		} else if (strcmp(argv[arg],"-EBCDIC") == 0) {
			table = 4;
		} else if (strcmp(argv[arg],"-d") == 0) {
			dump = 1;
		} else if (strcmp(argv[arg],"-help") == 0) {
                        fprintf( stderr, "\n%s [options] [input [output]]\n\n",
                                 argv[0] );
                        fprintf( stderr,
                        "List a virtual punched card deck as an ASCII file.\n"
                        "If output is missing, output to stdout; if input is\n"
                        "also missing, input from stdin.  The options are:\n\n"
                        " -026comm        what translation table to use\n"
                        " -029 -026ftn    (029 default)\n"
                        " -EBCDIC\n\n"
                        " -d              output card description to stderr\n\n"
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
                card_fd = stdin;
                ascii_fd = stdout;
        } else { /* at least one argument */
                card_fd = fopen(argv[arg],"r");
                if ( card_fd == NULL ) {
                        fprintf( stderr, "%s %s: invalid card file\n",
                                argv[0], argv[arg] );
                        exit(-1);
                }
                if ( (argc - arg) < 2 ) { /* only one arguments */
                        ascii_fd = stdout;
                } else { /* at least two arguments */
                        ascii_fd = fopen(argv[arg+1],"w");
                        if ( ascii_fd == NULL ) {
                                fprintf( stderr, "%s %s: invalid ascii file\n",
                                        argv[0], argv[arg+1] );
                                exit(-1);
                        }
                }
        }

	{ /* make appropriate card to ascii translation table */
		int i;
		for ( i = 0; i < 4096; i++ ) { /* mark illegal characters */
			ascii_code[i] = '~';
		}
		switch (table) {
			case 1:
				for ( i = ' '; i < '`'; i++ )
					ascii_code[ o26_comm_code[i] ] = i;
				break;
			case 2:
				for ( i = ' '; i < '`'; i++ )
					ascii_code[ o26_ftn_code[i] ] = i;
				break;
			case 3:
				for ( i = ' '; i < '`'; i++ )
					ascii_code[ o29_code[i] ] = i;
				break;
			case 4:
				for ( i = 0; i <= 0177; i++ )
					ascii_code[ EBCDIC_code[i] ] = i;
				break;
		}
	}

	/* check for prefix on input */
	{
		int char1 = fgetc( card_fd );
		int char2 = fgetc( card_fd );
		int char3 = fgetc( card_fd );
		if ((char1 == 'H') && (char2 == '8') && (char3 == '0')) {
			format = 80;
		} else if ((char1 == 'H') && (char2 == '8') && (char3 == '2')) {
			format = 82;
		} else {
			fprintf( stderr, "%s: input not a card file\n",
				argv[0] );
			exit(-1);
		}
	}
	
        /* ready to process from card_fd to ascii_fd */
	
	while( !feof( card_fd ) ) {
		unsigned char line[83];
		int cur_col, max_col;

		{ /* check header on each card */
                        int first, second, third;
			first = fgetc( card_fd );
			second = fgetc( card_fd );
			third = fgetc( card_fd );

			/* normal check for EOF */
			if (first==EOF) break;

			/* verify that we have a card */
			if ((second==EOF)
			||  (third==EOF)
			||  ((first & 0x80)==0)
			||  ((second & 0x80)==0)
			||  ((third & 0x80)==0)) { /* not a card */
				fprintf( stderr,"%s: input corrupt\n",argv[0]);
			}

			if (dump) {
				int color = (first >> 3) & 017; 
				static char *colors[16] = {
					"-cream",  "-white",
					"-yellow", "-pink",
					"-blue",   "-green",
					"-orange", "-brown",
					"<color 8>", "<color 9>",
					"-yellow -stripe", "-pink -stripe",
					"-blue -stripe",   "-green -stripe",
					"-orange -stripe", "-brown -stripe"
				};
				int corner = (first >> 2) & 01; 
				static char *corners[2] = {
					" -round",  " -square"
				};
				int cut = first & 03; 
				static char *cuts[4] = {
					" -uncut", " -right",
					" -left",  " -both"
				};
				int interp = (second >> 6) & 01; 
				static char *interps[2] = {
					"",  " -interp"
				};
				int punch = (second >> 3) & 07; 
				static char *punches[8] = {
					" -noprint",
					" -026comm",
					" -026ftn",
					" <punch 3>",
					" -029",
					" <punch 5>",
					" <punch 6>",
					" <punch 7>"
				};
				int form = second & 07; 
				static char *forms[8] = {
					" -blank",
					" -5081",
					" -507536",
					" -5280",
					" -327",
					" -733727",
					" -888157",
					" <unknown form>"
				};
				int logo = third & 0177;

				fprintf( stderr, colors[color] );
				fprintf( stderr, corners[corner] );
				fprintf( stderr, cuts[cut] );
				fprintf( stderr, interps[interp] );
				fprintf( stderr, punches[punch] );
				fprintf( stderr, forms[form] );
				if (logo == 0) {
					fprintf( stderr,", no");
				} else {
					fprintf( stderr,", unknown");
				}
				fprintf( stderr," logo");
			}
		}

		if (format == 80) {
			cur_col = 1;
			max_col = 80;
		} else { /* format == 82 */
			cur_col = 0;
			max_col = 81;
		}
		while ( cur_col < max_col ) {
                        int even_col, odd_col;
                        int first, second, third;

			/* get 3 bytes */
			first = fgetc( card_fd );
			second = fgetc( card_fd );
			third = fgetc( card_fd );

			/* convert to 2 columns */
			even_col = (first << 4) | (second >> 4);
			odd_col = ((second & 0017) << 8) | third;

			/* pack result into line */
			line[cur_col] = ascii_code[even_col];
			cur_col++;
			line[cur_col] = ascii_code[odd_col];
			cur_col++;
		}
		line[cur_col] = (char)0;

		if (dump) {
			if (format == 82) {
				if (line[0] != ' ') {
					fprintf( stderr,", col 0");
				}
				if (line[81] != ' ') {
					fprintf( stderr,", col 81");
				}
			}
			fprintf( stderr,"\n");
		}

		/* truncate trailing blanks */
		cur_col = max_col;
		while ((cur_col >= 1) && (line[cur_col] == ' ')) {
			line[cur_col] = (char)0;
			cur_col--;
		}
		fputs( &line[1], ascii_fd );
		fputc( '\n', ascii_fd );
	}
}
