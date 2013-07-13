/* cardcat.c -- concatenate punched-card image files.
 *
 * operation:  run cardcat -help for information
 *
 * input  -- multiple card-image files, 12 bits/column, 80 columns/card.
 * output -- a card-image file, 12 bits/column, 80 columns/card.
 *
 * see the README file for details of the card image file format!
 *
 * author:  Douglas Jones, jones@cs.uiowa.edu
 * date:    Feb 18, 1997
 *
 */

#include <stdio.h>

main(argc,argv)
int argc;
char *argv[];
{
	FILE *in_fd;
	int inform = 80;/* input format 80 or 82 */
	int arg = 1;	/* argument being processed */
	int outhead = 0;/* has a header been output yet */
	int error = 0;  /* -1 if an error has been reported */
		
	if (argc < 2) { /* no arguments */
		fprintf( stderr, "%s: no input file(s) specified\n", argv[0] );
		exit(-1);
	} else if ((argc == 2) && (strcmp(argv[1],"-help") == 0)) {
		fprintf( stderr, "\n%s [inputs ...]\n\n", argv[0] );
		fprintf( stderr,
                        "In normal use, reads concatenates and deletes the\n"
                        "named files, where each file contains a string of\n"
                        "virtual punched cards.  Output is always to stdout.\n"
			"Files are deleted after successful concatenation in\n"
                        "order to assure conservation of punched cards.  This\n"
                        "may offend users used to more modern programming\n"
			"environments where file copying is the norm!\n"
		);
		fprintf( stderr, "\n%s -help\n\n", argv[0] );
		fprintf( stderr,
                        "The help option is a special case and suppresses\n"
                        "the normal function of the program.\n\n"
		);
		exit(-1);
	}
	while (arg < argc) { /* for each command line arg */
                in_fd = fopen( argv[arg], "r" );
                if ( in_fd == NULL ) {
                        fprintf( stderr, "%s %s: invalid card file\n",
                                argv[0], argv[arg] );
			error = -1;
                }

		/* check for prefix on input file */
		if ( in_fd != NULL ) {
			int char1 = fgetc( in_fd );
			int char2 = fgetc( in_fd );
			int char3 = fgetc( in_fd );
			if ((char1 == 'H')
			 && (char2 == '8')
			 && (char3 == '0')) {
				inform = 80;
			} else if ((char1 == 'H')
			 && (char2 == '8')
			 && (char3 == '2')) {
				inform = 82;
			} else {
				fprintf( stderr, "%s %s: not a card file\n",
					argv[0], argv[arg] );
				fclose( in_fd );
				in_fd = NULL;
				error = -1;
			}
		}

		/* put header on output file if not done already */
		if ((in_fd != NULL) && (outhead == 0)) { 
			/* output always in H82 format
			   in case any input in that format */
			fputc( 'H', stdout );
			fputc( '8', stdout );
			fputc( '2', stdout );
			outhead = 1;
		}
	
		/* ready to process one card deck from in_fd to stdout */
		if (in_fd != NULL) for (;;) {
			int headfirst, headsecond, headthird; /* card header */
			int line[82];  /* the 12-bit data columns */
			int cur_col, first_col, last_col;


			if (inform == 80) {
				first_col = 1;
				last_col = 80;
				line[0] = line[81] = 0;
			} else { /* inform == 82 */
				first_col = 0;
				last_col = 81;
			}

			/* check header on each card */
			headfirst = fgetc( in_fd );
			if (headfirst == EOF) break; /* normal EOF */
			headsecond = fgetc( in_fd );
			headthird = fgetc( in_fd );

			/* verify that we have a card */
			if ((headsecond == EOF)
			||  (headthird == EOF)
			||  ((headfirst & 0x80) == 0)
			||  ((headsecond & 0x80) == 0)
			||  ((headthird & 0x80) ==.0)) { /* not a card */
				fprintf( stderr,"%s %s: input corrupt\n",
					argv[0], argv[arg]);
				error = -1;
				break; /* abandon this file */
			}

			/* read the data from the card */
			for (cur_col = first_col; cur_col < last_col; ) {
				int first, second, third;

				/* get 3 bytes */
				first = fgetc( in_fd ) & 0377;
				second = fgetc( in_fd ) & 0377;
				third = fgetc( in_fd ) & 0377;

				/* convert to 2 columns */
				line[cur_col] = (first << 4) | (second >> 4);
				cur_col++;
				line[cur_col] = ((second & 017) << 8) | third;
				cur_col++;
			}

			/* write out the card header */
			fputc( headfirst, stdout);
			fputc( headsecond, stdout);
			fputc( headthird, stdout);

			/* write out the card data */
			for (cur_col = 0; cur_col < 81; ) {
				int first = line[cur_col] >> 4;
				int second = ((line[cur_col] & 017) << 4)
					   | (line[cur_col + 1] >> 8);
				int third = line[cur_col + 1] & 0377;
				cur_col += 2;
				fputc( first, stdout );
				fputc( second, stdout );
				fputc( third, stdout );
			}
		}
		/* done copying a card deck from in_fd to stdout */

		/* ready to clean up after copying one file */
		if (in_fd != NULL) {
			fflush( stdout ); /* insurance before unlink */
			fclose( in_fd );
			in_fd = NULL;

			/* cards are conserved, so cardcat consumes its input */
                	if (unlink( argv[arg] ) != 0) {
				fprintf( stderr, "%s %s: could not delete\n",
					argv[0], argv[arg] );
			error = -1;
			}
		}

		/* advance to the next */
		arg++;
	}
	/* done looping through command line args */

	/* normal exit, reports any error encountered in list of files */
	exit(error);
} 
