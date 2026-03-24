%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parser.tab.h"

extern void addLexError(int, const char*);
int line = 1;

FILE *temp_out = NULL;
int autocorrect_count = 0;

#define ECHO_YY if(temp_out) { fprintf(temp_out, "%s", yytext); }

char *keywords[] = {"int","float","char","string","if","else","while","for"};
int kw_count = 8;

/* Calculates true Levenshtein distance to handle insertions, deletions, and swaps reliably */
int levenshtein(const char *s1, const char *s2) {
    int len1 = strlen(s1), len2 = strlen(s2);
    int matrix[len1 + 1][len2 + 1];
    int i,j;

    for (i = 0; i <= len1; i++) matrix[i][0] = i;
    for (j = 0; j <= len2; j++) matrix[0][j] = j;

    for (i = 1; i <= len1; i++) {
        for (j = 1; j <= len2; j++) {
            int cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1;
            int del = matrix[i - 1][j] + 1;
            int ins = matrix[i][j - 1] + 1;
            int sub = matrix[i - 1][j - 1] + cost;
            
            int min = (del < ins) ? del : ins;
            matrix[i][j] = (min < sub) ? min : sub;
            
            /* Handle transpositions (swaps) like 'flota' -> 'float' */
            if (i > 1 && j > 1 && s1[i - 1] == s2[j - 2] && s1[i - 2] == s2[j - 1]) {
                int trans = matrix[i - 2][j - 2] + cost;
                matrix[i][j] = (matrix[i][j] < trans) ? matrix[i][j] : trans;
            }
        }
    }
    return matrix[len1][len2];
}

char* autocorrect(char *word){
    int min = 100, index = -1;
    for(int i=0;i<kw_count;i++){
        int d = levenshtein(word, keywords[i]);
        if(d < min){
            min = d;
            index = i;
        }
    }
    
    // Maximum distance 2 for long keywords, 1 for short. This prevents 
    // real variables (like 'data') from being "autocorrected" into keywords (like 'char').
    int threshold = (strlen(keywords[index]) <= 3) ? 1 : 2;
    
    // As a special feature for 'any spelling mistake' like repeated characters (e.g., floatttt)
    if (min > threshold && word[0] == keywords[index][0]) {
        // Just verify if all characters in word exist in the keyword roughly
        int is_extend = 1;
        for(int j=0; word[j]; j++) {
            if(!strchr(keywords[index], word[j])) { is_extend = 0; break; }
        }
        if(is_extend) threshold = min; // Allow if it is just a button spam like 'floatttt'
    }
    
    if(min <= threshold)
        return keywords[index];
    
    return NULL;
}

int keyword_token(const char *kw){
    if(strcmp(kw,"int")==0)    return INT;
    if(strcmp(kw,"float")==0)  return FLOAT;
    if(strcmp(kw,"char")==0)   return CHAR;
    if(strcmp(kw,"string")==0) return STRING;
    if(strcmp(kw,"if")==0)     return IF;
    if(strcmp(kw,"else")==0)   return ELSE;
    if(strcmp(kw,"while")==0)  return WHILE;
    if(strcmp(kw,"for")==0)    return FOR;
    return -1;
}
%}

%%

"//".* { ECHO_YY; }

"int"      { ECHO_YY; return INT; }
"float"    { ECHO_YY; return FLOAT; }
"char"     { ECHO_YY; return CHAR; }
"string"   { ECHO_YY; return STRING; }

"if"       { ECHO_YY; return IF; }
"else"     { ECHO_YY; return ELSE; }
"while"    { ECHO_YY; return WHILE; }
"for"      { ECHO_YY; return FOR; }

[0-9]*\.[0-9]*\.[0-9]*    { ECHO_YY; addLexError(line, "Malformed number"); }

[0-9]+\.[0-9]+            { ECHO_YY; yylval.str = strdup("float"); return NUMBER; }
[0-9]+                    { ECHO_YY; yylval.str = strdup("int"); return NUMBER; }

\"([^\"\n]*)$             { ECHO_YY; addLexError(line, "Unterminated string"); }
\"([^\"\n]*)\"            { ECHO_YY; yylval.str = strdup("string"); return STRING_LITERAL; }

\'([^\'\n]*)$             { ECHO_YY; addLexError(line, "Unterminated character"); }
\'([^\'\n])\'             { ECHO_YY; yylval.str = strdup("char"); return CHAR_LITERAL; }

[0-9][a-zA-Z_]+           { ECHO_YY; addLexError(line, "Invalid identifier"); }

[a-zA-Z_][a-zA-Z0-9_]*[^a-zA-Z0-9 \t\n\+\-\*/=;(){}<>!\"']+ {
    ECHO_YY;
    char msg[128];
    snprintf(msg, sizeof(msg), "Invalid identifier '%s'", yytext);
    addLexError(line, msg);
    yylval.str = strdup(yytext);
    return IDENTIFIER;
}

[a-zA-Z_][a-zA-Z0-9_]* {
    char *correct = autocorrect(yytext);
    if(correct != NULL && strcmp(correct, yytext) != 0){
        printf("Line %d : Auto-correcting typo '%s' to keyword '%s'\n", line, yytext, correct);
        if(temp_out) fprintf(temp_out, "%s", correct);
        autocorrect_count++;
        int tok = keyword_token(correct);
        if(tok != -1) return tok;
    } else {
        ECHO_YY;
    }
    
    yylval.str = strdup(yytext);
    return IDENTIFIER;
}

"=="|">="|"<="|"!="|">"|"<" { ECHO_YY; return RELOP; }

"+" { ECHO_YY; return PLUS; }
"-" { ECHO_YY; return MINUS; }
"*" { ECHO_YY; return MUL; }
"/" { ECHO_YY; return DIV; }
"=" { ECHO_YY; return ASSIGN; }

";" { ECHO_YY; return SEMI; }
"(" { ECHO_YY; return LPAREN; }
")" { ECHO_YY; return RPAREN; }
"{" { ECHO_YY; return LBRACE; }
"}" { ECHO_YY; return RBRACE; }

[ \t\r]+ { ECHO_YY; }
\n { ECHO_YY; line++; }

[^a-zA-Z0-9 \t\n\+\-\*/=;(){}<>!\"'] {
    ECHO_YY;
    addLexError(line, "Invalid character");
}

%%

int yywrap() { return 1; }