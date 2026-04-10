%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int yylex();
void yyerror(const char *s);
extern int line;

/* FLAGS  */
int syntaxErrorFlag = 0;

/*  ERROR STORAGE  */
typedef struct {
    int line;
    char msg[100];
} Error;
 
Error lexErrors[100], synErrors[100], semErrors[100];
int lexCount=0, synCount=0, semCount=0;
int errorCount = 0;

/*  ERROR FUNCTIONS  */
void addLexError(int l, const char *msg){
    lexErrors[lexCount].line=l;
    strcpy(lexErrors[lexCount++].msg,msg);
    errorCount++;
}

void addSynError(int l, const char *msg){
    synErrors[synCount].line=l;
    strcpy(synErrors[synCount++].msg,msg);
    errorCount++;
    syntaxErrorFlag = 1;
}

void addSemError(int l, const char *msg){
    semErrors[semCount].line=l;
    strcpy(semErrors[semCount++].msg,msg);
    errorCount++;
}

/*  SYMBOL TABLE  */
typedef struct {
    char name[50];
    char type[10];
    int initialized;
} Symbol;

Symbol symtab[100];
int symcount=0;

int lookup(char *s){
    for(int i=0;i<symcount;i++)
        if(strcmp(symtab[i].name,s)==0) return i;
    return -1;
}

void insert(char *name,char *type){
    // Do not insert corrupted identifiers into the symbol table
    for(int i = 0; name[i] != '\0'; i++) {
        if(!((name[i] >= 'a' && name[i] <= 'z') || 
             (name[i] >= 'A' && name[i] <= 'Z') || 
             (name[i] >= '0' && name[i] <= '9') || 
             name[i] == '_')) {
            return;
        }
    }

    if(lookup(name)!=-1){
        if(!syntaxErrorFlag)
            addSemError(line,"Redeclaration of variable");
        return;
    }
    strcpy(symtab[symcount].name,name);
    strcpy(symtab[symcount].type,type);
    symtab[symcount].initialized=0;
    symcount++;
}

/*  TYPE CHECK  */
char* checkType(char* t1,char* t2){
    if(!t1 || !t2) return NULL;

    if(strcmp(t1,t2)==0) return t1;

    if((strcmp(t1,"int")==0 && strcmp(t2,"float")==0) ||
       (strcmp(t1,"float")==0 && strcmp(t2,"int")==0))
        return "float";

    if(!syntaxErrorFlag)
        addSemError(line,"Type mismatch in expression");

    return t1;
}

/*  PRINT  */
void printSymbolTable(){
    printf("\n SYMBOL TABLE \n");
    printf("%-20s %-15s %-15s\n", "Name", "Type", "Initialized");
    printf("----------------------------------------------------\n");
    for(int i=0;i<symcount;i++){
        printf("%-20s %-15s %-15d\n",
            symtab[i].name,
            symtab[i].type,
            symtab[i].initialized);
    }
}

void printErrors(){
    printf("\nLEXICAL ERRORS\n");
    if(lexCount == 0) printf("No lexical error found\n");
    for(int i=0;i<lexCount;i++)
        printf("Line %d : LEXICAL ERROR : %s\n",lexErrors[i].line,lexErrors[i].msg);

    printf("\n SYNTAX ERRORS \n");
    if(synCount == 0) printf("No syntax error found\n");
    for(int i=0;i<synCount;i++)
        printf("Line %d : SYNTAX ERROR : %s\n",synErrors[i].line,synErrors[i].msg);

    if(!syntaxErrorFlag){
        printf("\n SEMANTIC ERRORS \n");
        if(semCount == 0) printf("No semantic error found\n");
        for(int i=0;i<semCount;i++)
            printf("Line %d : SEMANTIC ERROR : %s\n",semErrors[i].line,semErrors[i].msg);
    }
}
%}

%union { char* str; }

/*  TOKENS  */
%token <str> IDENTIFIER NUMBER STRING_LITERAL CHAR_LITERAL
%token INT FLOAT CHAR STRING
%token IF ELSE WHILE FOR PRINTF SCANF
%token PLUS MINUS MUL DIV ASSIGN RELOP
%token SEMI LPAREN RPAREN LBRACE RBRACE
%token LBRACKET RBRACKET COMMA AMPERSAND

%type <str> expr type opt_expr

/*  PRECEDENCE (FIXES CONFLICTS)  */
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%nonassoc RELOP
%left PLUS MINUS
%left MUL DIV

%%

program:
    program stmt
    | stmt
;

stmt:
      decl
    | assign
    | if_stmt
    | while_stmt
    | for_stmt
    | print_stmt
    | scan_stmt
    | block
    | error SEMI { addSynError(line,"Invalid statement"); yyerrok; }
;

block:
    LBRACE program RBRACE
;

decl:
    type IDENTIFIER SEMI {
        insert($2,$1);
    }

    | type IDENTIFIER LBRACKET NUMBER RBRACKET SEMI {
        insert($2,$1); 
    }

    | type IDENTIFIER ASSIGN expr SEMI {
        insert($2,$1);
        int i=lookup($2);
        if(i!=-1 && !syntaxErrorFlag){
            if($4 && strcmp(symtab[i].type,$4)!=0)
                addSemError(line,"Type mismatch in initialization");
            else
                symtab[i].initialized=1;
        }
    }

    | type IDENTIFIER ASSIGN error SEMI {
        addSynError(line,"Missing expression in declaration");
        yyerrok;
    }
;

type:
      INT { $$="int"; }
    | FLOAT { $$="float"; }
    | CHAR { $$="char"; }
    | STRING { $$="string"; }
;

assign:
    IDENTIFIER ASSIGN expr SEMI {
        int i=lookup($1);
        if(i==-1 && !syntaxErrorFlag){
            addSemError(line,"Undeclared variable");
        } 
        else if(i!=-1 && !syntaxErrorFlag){
            if($3 && strcmp(symtab[i].type,$3)!=0)
                addSemError(line,"Type mismatch in assignment");
            else
                symtab[i].initialized=1;
        }
    }

    | IDENTIFIER LBRACKET expr RBRACKET ASSIGN expr SEMI {
        int i=lookup($1);
        if(i==-1 && !syntaxErrorFlag){
            addSemError(line,"Undeclared array");
        } 
        else if(i!=-1 && !syntaxErrorFlag){
            if($6 && strcmp(symtab[i].type,$6)!=0)
                addSemError(line,"Type mismatch in array assignment");
            else
                symtab[i].initialized=1;
        }
    }

    | IDENTIFIER ASSIGN error SEMI {
        addSynError(line,"Missing expression after '='");
        yyerrok;
    }
;

if_stmt:
    IF LPAREN expr RPAREN stmt %prec LOWER_THAN_ELSE
    | IF LPAREN expr RPAREN stmt ELSE stmt
    | IF LPAREN error RPAREN {
        addSynError(line,"Invalid condition in if");
        yyerrok;
    }
;

while_stmt:
    WHILE LPAREN expr RPAREN stmt
;

for_stmt:
    FOR LPAREN opt_assign SEMI opt_expr SEMI opt_assign RPAREN stmt
;

opt_assign:
      /* empty */
    | assign_expr
;

assign_expr:
    IDENTIFIER ASSIGN expr {
        int i=lookup($1);
        if(i==-1 && !syntaxErrorFlag){
            addSemError(line,"Undeclared variable");
        } else if(i!=-1 && !syntaxErrorFlag) {
            if($3 && strcmp(symtab[i].type,$3)!=0)
                addSemError(line,"Type mismatch in assignment");
            else
                symtab[i].initialized=1;
        }
    }
    | IDENTIFIER LBRACKET expr RBRACKET ASSIGN expr {
        int i=lookup($1);
        if(i==-1 && !syntaxErrorFlag){
            addSemError(line,"Undeclared array");
        } else if(i!=-1 && !syntaxErrorFlag) {
            if($6 && strcmp(symtab[i].type,$6)!=0)
                addSemError(line,"Type mismatch in array assignment");
            else
                symtab[i].initialized=1;
        }
    }
;

opt_expr:
      /* empty */ { $$ = NULL; }
    | expr { $$ = $1; }
;

print_stmt:
      PRINTF LPAREN STRING_LITERAL RPAREN SEMI
    | PRINTF LPAREN STRING_LITERAL COMMA expr_list RPAREN SEMI
;

scan_stmt:
    SCANF LPAREN STRING_LITERAL COMMA AMPERSAND IDENTIFIER RPAREN SEMI {
        int i=lookup($6);
        if(i==-1 && !syntaxErrorFlag){
            addSemError(line,"Undeclared variable in scanf");
        }
    }
;

expr_list:
      expr
    | expr_list COMMA expr
;

expr:
      expr PLUS expr { $$=checkType($1,$3); }
    | expr MINUS expr { $$=checkType($1,$3); }
    | expr MUL expr { $$=checkType($1,$3); }
    | expr DIV expr { $$=checkType($1,$3); }

    | expr RELOP expr { $$="int"; }

    | IDENTIFIER {
        int i = lookup($1);

        if(i == -1 && !syntaxErrorFlag){
            addSemError(line,"Undeclared variable");
            $$ = NULL;
        } else {
            $$ = (i==-1) ? NULL : symtab[i].type;
        }
    }

    | IDENTIFIER LBRACKET expr RBRACKET {
        int i = lookup($1);

        if(i == -1 && !syntaxErrorFlag){
            addSemError(line,"Undeclared array");
            $$ = NULL;
        } else {
            $$ = (i==-1) ? NULL : symtab[i].type; // Treating array element seamlessly
        }
    }

    | NUMBER { $$=$1; }
    | STRING_LITERAL { $$="string"; }
    | CHAR_LITERAL { $$="char"; }

    | LPAREN expr RPAREN { $$=$2; }
;

%%

extern FILE *yyin;
extern int autocorrect_count;

int main(int argc, char **argv){
    char *input_file = NULL;
    if (argc > 1) {
        input_file = argv[1];
        yyin = fopen(input_file, "r");
        if (!yyin) {
            perror("Error opening input file");
            return 1;
        }
    }

    if (argc == 1) {
        printf("Note: Running from standard input. To auto-correct a file directly, run with: ./compiler <filename>\n");
    }

    yyparse();
    if (yyin && yyin != stdin) {
        fclose(yyin);
        yyin = NULL;
    }

    if (input_file && autocorrect_count > 0) {
        printf("\nSuccessfully auto-corrected %d typo(s) in %s\n", autocorrect_count, input_file);
    }

    printf("\nTotal Errors: %d\n",errorCount);
    printErrors();

    if(!syntaxErrorFlag){
        printSymbolTable();
    }

    return 0;
}

void yyerror(const char *s){}
