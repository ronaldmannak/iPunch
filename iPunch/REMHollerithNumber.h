//
//  REMHollerithNumber.h
//  iPunch
//
//  Created by Ronald Mannak on 7/13/13.
//  Copyright (c) 2013 Ronald Mannak. All rights reserved.
//
//  Overview encoding schemes: http://homepage.cs.uiowa.edu/~jones/cards/codes.html

#import <Foundation/Foundation.h>

typedef enum {
    HollerithEncodingBCD,
    HollerithEncodingIBMModel026,
    HollerithEncodingIBMModel026Raporting,
    HollerithEncodingIBMModel026Fortran,
    HollerithEncodingIBMModel029,
    HollerithEncodingEBCDIC,
    HollerithEncodingDEC,
    HollerithEncodingGE,
    HollerithEncodingUNIVAC,
}HollerithEncoding;


@interface REMHollerithNumber : NSObject

@property (nonatomic, strong, readonly) NSString  *stringValue;
@property (nonatomic, strong, readonly) NSArray   *arrayValue;
@property (nonatomic) HollerithEncoding encoding;

+ (id)HollerithWithString:(NSString *)string
                 encoding:(HollerithEncoding)encoding;
+ (id)HollerithWithArray:(NSArray *)array
                encoding:(HollerithEncoding)encoding;

+ (BOOL)isValidArray:(NSArray *)array forEncoding:(HollerithEncoding)encoding;


@end

//    IBM Model 029
//
//    029  &-0123456789ABCDEFGHIJKLMNOPQR/STUVWXYZ:#@'="¢.<(+|!$*);¬ ,%_>?
//    IBME ¹-0123456789ABCDEFGHIJKLMNOPQR/STUVWXYZ:#²'="].<(+|[$*);¬³,%_>?
//    EBCD &-0123456789ABCDEFGHIJKLMNOPQR/STUVWXYZ:#@'="[.<(+|]$*);^\,%_>?
//         ________________________________________________________________
//        /&-0123456789ABCDEFGHIJKLMNOPQR/STUVWXYZb#@'>V?.¤[<§!$*];^±,%v\¶
//    12 / O           OOOOOOOOO                        OOOOOO
//    11|   O                   OOOOOOOOO                     OOOOOO
//     0|    O                           OOOOOOOOO                  OOOOOO
//     1|     O        O        O        O
//     2|      O        O        O        O       O     O     O     O
//     3|       O        O        O        O       O     O     O     O
//     4|        O        O        O        O       O     O     O     O
//     5|         O        O        O        O       O     O     O     O
//     6|          O        O        O        O       O     O     O     O
//     7|           O        O        O        O       O     O     O     O
//     8|            O        O        O        O OOOOOOOOOOOOOOOOOOOOOOOO
//     9|             O        O        O        O
//      |__________________________________________________________________

@interface REMHollerithNumberIBMModel029 : REMHollerithNumber
@end


//      BCD
//
//         ________________________________________________________________
//        / -0123456789ABCDEFGHIJKLMNOPQR/STUVWXYZ       .     $     ,
//    12 / O           OOOOOOOOO                        OOOOOO
//    11|   O                   OOOOOOOOO                     OOOOOO
//     0|    O                           OOOOOOOOO      ?     ?     OOOOOO
//     1|     O        O        O        O
//     2|      O        O        O        O       O     ?     ?     O
//     3|       O        O        O        O       O     O     O     O
//     4|        O        O        O        O       O     O     O     O
//     5|         O        O        O        O       O     O     O     O
//     6|          O        O        O        O       O     O     O     O
//     7|           O        O        O        O       O     O     O     O
//     8|            O        O        O        O OOOOOOOOOOOOOOOOOOOOOOOO
//     9|             O        O        O        O
//      |__________________________________________________________________

@interface REMHollerithNumberBCD : REMHollerithNumber
@end


//    IBM Model 26
//
//    FORT +-0123456789ABCDEFGHIJKLMNOPQR/STUVWXYZ ='    .)    $*    ,(
//    COMM &-0123456789ABCDEFGHIJKLMNOPQR/STUVWXYZ #@    .¤    $*    ,%
//         ________________________________________________________________
//        / -0123456789ABCDEFGHIJKLMNOPQR/STUVWXYZ       .     $     ,
//    12 / O           OOOOOOOOO                        OOOOOO
//    11|   O                   OOOOOOOOO                     OOOOOO
//    0 |    O                           OOOOOOOOO      ?     ?     OOOOOO
//    1 |     O        O        O        O
//    2 |      O        O        O        O       O     ?     ?     O
//    3 |       O        O        O        O       O     O     O     O
//    4 |        O        O        O        O       O     O     O     O
//    5 |         O        O        O        O       O     O     O     O
//    6 |          O        O        O        O       O     O     O     O
//    7 |           O        O        O        O       O     O     O     O
//    8 |            O        O        O        O OOOOOOOOOOOOOOOOOOOOOOOO
//    9 |             O        O        O        O
//      |__________________________________________________________________

@interface REMHollerithNumberIBMModel026 : REMHollerithNumber
@end


//    IBM Model 26 Reporting
//
//    REPT &-0123456789ABCDEFGHIJKLMNOPQR/STUVWXYZb#@'>V?.¤[<§!$*];^±,%v\¶
//    PROG +-0123456789ABCDEFGHIJKLMNOPQR/STUVWXYZb=':>V?.)[<§!$*];^±,(v\¶
//         ________________________________________________________________
//        / -0123456789ABCDEFGHIJKLMNOPQR/STUVWXYZ       .     $     ,
//    12 / O           OOOOOOOOO                        OOOOOO
//    11|   O                   OOOOOOOOO                     OOOOOO
//    0 |    O                           OOOOOOOOO      O     O     OOOOOO
//    1 |     O        O        O        O
//    2 |      O        O        O        O       O                 O
//    3 |       O        O        O        O       O     O     O     O
//    4 |        O        O        O        O       O     O     O     O
//    5 |         O        O        O        O       O     O     O     O
//    6 |          O        O        O        O       O     O     O     O
//    7 |           O        O        O        O       O     O     O     O
//    8 |            O        O        O        O OOOOOO OOOOOOOOOOOOOOOOO
//    9 |             O        O        O        O
//      |__________________________________________________________________

@interface REMHollerithNumberIBMModel026Reporting : REMHollerithNumber
@end


//    IBM Model 26 Fortran
//
//    1401 &-0123456789ABCDEFGHIJKLMNOPQR/STUVWXYZ #@:>V?.¤(<§!$*);^±,%='"
//         ________________________________________________________________
//        /&-0123456789ABCDEFGHIJKLMNOPQR/STUVWXYZb#@'>V?.¤[<§!$*];^±,%v\¶
//    12 / O           OOOOOOOOO                        OOOOOO
//    11|   O                   OOOOOOOOO                     OOOOOO
//    0 |    O                           OOOOOOOOO      O     O     OOOOOO
//    1 |     O        O        O        O
//    2 |      O        O        O        O       O                 O
//    3 |       O        O        O        O       O     O     O     O
//    4 |        O        O        O        O       O     O     O     O
//    5 |         O        O        O        O       O     O     O     O
//    6 |          O        O        O        O       O     O     O     O
//    7 |           O        O        O        O       O     O     O     O
//    8 |            O        O        O        O OOOOOO OOOOOOOOOOOOOOOOO
//    9 |             O        O        O        O
//      |__________________________________________________________________

@interface REMHollerithNumberIBMModel026Fortran : REMHollerithNumber
@end


//    EBCDIC
//
//      00  10  20  30  40  50  60  70  80  90  A0  B0  C0  D0  E0  F0
//     ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___ ___
//    0|NUL|   |DS |   |SP | & | - |   |   |   |   |   |   |   |   | 0 |0
//     |__1|___|__2|___|__3|__4|__5|___|___|___|___|___|___|___|___|___|
//    1|   |   |SOS|   |   |   | / |   | a | j |   |   | A | J |   | 1 |1
//     |___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|
//    2|   |   |FS |   |   |   |   |   | b | k | s |   | B | K | S | 2 |2
//     |___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|
//    3|   |TM |   |   |   |   |   |   | c | l | t |   | C | L | T | 3 |3
//     |___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|
//    4|PF |RES|BYP|PN |   |   |   |   | d | m | u |   | D | M | U | 4 |4
//     |___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|
//    5|HT |NL |LF |RS |   |   |   |   | e | n | v |   | E | N | V | 5 |5
//     |___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|
//    6|LC |BS |EOB|UC |   |   |   |   | f | o | w |   | F | O | W | 6 |6
//     |___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|
//    7|DEL|IL |PRE|EOT|   |   |   |   | g | p | x |   | G | P | X | 7 |7
//     |___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|
//    8|   |   |   |   |   |   |   |   | h | q | y |   | H | Q | Y | 8 |8
//     |___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|
//    9|   |   |   |   |   |   |   |   | i | r | z |   | I | R | Z | 9 |9
//     |___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|
//    A|   |   |   |   | ¢ | ! |   | : |   |   |   |   |   |   |   |   |2-8
//     |___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|
//    B|   |   |   |   | . | $ | , | # |   |   |   |   |   |   |   |   |3-8
//     |___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|
//    C|   |   |   |   | < | * | % | @ |   |   |   |   |   |   |   |   |4-8
//     |___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|
//    D|   |   |   |   | ( | ) | _ | ' |   |   |   |   |   |   |   |   |5-8
//     |___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|
//    E|   |   |   |   | + | ; | > | = |   |   |   |   |   |   |   |   |6-8
//     |___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|
//    F|   |   |   |   | | | ¬ | ? | " |   |   |   |   |   |   |   |   |7-8
//     |___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|___|
//      12  11  10      12  11  10      12  11  10      12  11  10
//      9   9   9                       10  12  11

@interface REMHollerithNumberEBCDIC : REMHollerithNumber
@end

@interface REMHollerithNumberDEC : REMHollerithNumber
@end

@interface REMHollerithNumberGE : REMHollerithNumber
@end

@interface REMHollerithNumberUNIVAC : REMHollerithNumber
@end
