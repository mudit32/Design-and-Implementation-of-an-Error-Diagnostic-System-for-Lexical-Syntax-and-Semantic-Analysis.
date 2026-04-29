%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parser.tab.h"

extern void addLexError(int, const char*);
int line = 1;

int autocorrect_count = 0;
extern FILE *temp_out;

#define ECHO_YY if(temp_out) { fprintf(temp_out, "%s", yytext); }

char *keywords[] = {"int","float","char","string","if","else","for","while"};
int kw_count = 8;

/* Calculates true Levenshtein distance to handle insertions, deletions, and swaps reliably */
int levenshtein(const char *s1, const char *s2) {
    int len1=strlen(s1), len2=strlen(s2);
    int matrix[len1+1][len2+1];

    for (int i=0; i<=len1; i++) matrix[i][0]=i;
    for (int j=0; j<=len2; j++) matrix[0][j]=j;

    for (int i=1; i<=len1; i++) {
        for (int j=1; j<=len2; j++) {
            int cost = (s1[i-1]==s2[j-1]) ? 0 : 1;
            int del=matrix[i-1][j]+1, ins=matrix[i][j-1]+1, sub=matrix[i-1][j-1]+cost;
            int min = (del<ins) ? del : ins;
            matrix[i][j] = (min<sub) ? min : sub;
            /* Handle transpositions (swaps) like 'flota' -> 'float' */
            if (i>1 && j>1 && s1[i-1]==s2[j-2] && s1[i-2]==s2[j-1]) {
                int trans = matrix[i-2][j-2]+cost;
                matrix[i][j] = (matrix[i][j]<trans) ? matrix[i][j] : trans;
            }
        }
    }
    return matrix[len1][len2];
}

char *autocorrect(char *word) {
    if (strlen(word) <= 1) return NULL;
    int min=100, index=-1;
    for (int i=0; i<kw_count; i++) {
        int d = levenshtein(word, keywords[i]);
        if (d < min) { min=d; index=i; }
    }
    /* Max distance 2 for long keywords, 1 for short — prevents real variables
       like 'data' being corrected into keywords like 'char' */
    int threshold = (strlen(keywords[index]) <= 3) ? 1 : 2;
    return (min <= threshold) ? keywords[index] : NULL;
}

int keyword_token(const char *kw) {
    if (!strcmp(kw,"int"))    return INT;
    if (!strcmp(kw,"float"))  return FLOAT;
    if (!strcmp(kw,"char"))   return CHAR;
    if (!strcmp(kw,"string")) return STRING;
    if (!strcmp(kw,"if"))     return IF;
    if (!strcmp(kw,"else"))   return ELSE;
    if (!strcmp(kw,"for"))    return FOR;
    if (!strcmp(kw,"while"))  return WHILE;
    return -1;
}
%}

%%

"//".* { ECHO_YY; }

"int"    { ECHO_YY; return INT;    }
"float"  { ECHO_YY; return FLOAT;  }
"char"   { ECHO_YY; return CHAR;   }
"string" { ECHO_YY; return STRING; }
"if"     { ECHO_YY; return IF;     }
"else"   { ECHO_YY; return ELSE;   }
"for"    { ECHO_YY; return FOR;    }
"while"  { ECHO_YY; return WHILE;  }

[0-9]*\.[0-9]*\.[0-9]*  { ECHO_YY; addLexError(line, "Malformed number"); }

[0-9]+\.[0-9]+  { ECHO_YY; yylval.str = strdup(yytext); return FNUM; }
[0-9]+          { ECHO_YY; yylval.str = strdup(yytext); return INUM; }

\"([^\"\n]*)$   { ECHO_YY; addLexError(line, "Unterminated string"); }
\"([^\"\n]*)\"  { ECHO_YY; yylval.str = strdup("string"); return STRING_LITERAL; }

\'([^\'\n]*)$   { ECHO_YY; addLexError(line, "Unterminated character"); }
\'([^\'\n])\'   { ECHO_YY; yylval.str = strdup("char"); return CHAR_LITERAL; }

[0-9][a-zA-Z_]+  { ECHO_YY; addLexError(line, "Invalid identifier"); }

[a-zA-Z_][a-zA-Z0-9_]*[^a-zA-Z0-9 \t\n\+\-\*/=;(){}\[\]<>,&!\"']+ {
    ECHO_YY;
    char msg[128];
    snprintf(msg, sizeof(msg), "Invalid identifier '%s'", yytext);
    addLexError(line, msg);
    yylval.str = strdup(yytext);
    return IDENTIFIER;
}

[a-zA-Z_][a-zA-Z0-9_]* {
    char *correct = autocorrect(yytext);
    if (correct && strcmp(correct, yytext) != 0) {
        printf("Line %d : Auto-correcting typo '%s' to keyword '%s'\n", line, yytext, correct);
        if (temp_out) fprintf(temp_out, "%s", correct);
        autocorrect_count++;
        int tok = keyword_token(correct);
        if (tok != -1) return tok;
    } else {
        ECHO_YY;
    }
    yylval.str = strdup(yytext);
    return IDENTIFIER;
}

"=="|">="|"<="|"!="|">"|"<"  { ECHO_YY; yylval.str = strdup(yytext); return RELOP; }

"+" { ECHO_YY; return PLUS;      }
"-" { ECHO_YY; return MINUS;     }
"*" { ECHO_YY; return MUL;       }
"/" { ECHO_YY; return DIV;       }
"=" { ECHO_YY; return ASSIGN;    }
";" { ECHO_YY; return SEMI;      }
"(" { ECHO_YY; return LPAREN;    }
")" { ECHO_YY; return RPAREN;    }
"{" { ECHO_YY; return LBRACE;    }
"}" { ECHO_YY; return RBRACE;    }
"," { ECHO_YY; return COMMA;     }
"&" { ECHO_YY; return AMPERSAND; }

[ \t\r]+ { ECHO_YY; }
\n       { ECHO_YY; line++; }

[^a-zA-Z0-9 \t\n\+\-\*/=;(){}\[\]<>,&!\"'] {
    ECHO_YY;
    addLexError(line, "Invalid character");
}

%%

int yywrap() { return 1; }