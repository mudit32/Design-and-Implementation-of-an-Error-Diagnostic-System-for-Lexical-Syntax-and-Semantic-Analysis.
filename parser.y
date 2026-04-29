%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

int yylex();
void yyerror(const char *s);
extern int line;

int syntaxErrorFlag = 0, errorCount = 0;

typedef struct { int line; char msg[100]; } Error;
Error lexErrors[100], synErrors[100], semErrors[100];
int   lexCount = 0,  synCount = 0,  semCount = 0;

void addLexError(int l, const char *m) { lexErrors[lexCount].line=l; strcpy(lexErrors[lexCount++].msg,m); errorCount++; }
void addSynError(int l, const char *m) { synErrors[synCount].line=l; strcpy(synErrors[synCount++].msg,m); errorCount++; syntaxErrorFlag=1; }
void addSemError(int l, const char *m) { semErrors[semCount].line=l; strcpy(semErrors[semCount++].msg,m); errorCount++; }

typedef struct { char name[50]; char type[10]; int initialized; } Symbol;
Symbol symtab[100];
int symcount = 0;

int lookup(char *s) {
    for (int i=0; i<symcount; i++)
        if (strcmp(symtab[i].name, s)==0) return i;
    return -1;
}

void insert(char *name, char *type) {
    for (int i=0; name[i]; i++)           /* reject corrupted identifiers */
        if (!isalnum((unsigned char)name[i]) && name[i]!='_') return;
    if (lookup(name) != -1) {
        if (!syntaxErrorFlag) addSemError(line, "Redeclaration of variable");
        return;
    }
    strcpy(symtab[symcount].name, name);
    strcpy(symtab[symcount].type, type);
    symtab[symcount++].initialized = 0;
}

char *checkType(char *t1, char *t2) {
    if (!t1 || !t2) return NULL;
    if (strcmp(t1,t2)==0) return t1;
    if ((strcmp(t1,"int")==0 && strcmp(t2,"float")==0) ||
        (strcmp(t1,"float")==0 && strcmp(t2,"int")==0)) return "float";
    if (!syntaxErrorFlag) addSemError(line, "Type mismatch in expression");
    return t1;
}

typedef enum { TAC_OP, TAC_ASSIGN, TAC_IF_FALSE, TAC_GOTO, TAC_LABEL } TACType;
typedef struct { TACType type; char res[20],arg1[20],op[10],arg2[20]; int deleted; char opt_info[100]; } TACInstr;

TACInstr tac[1000];
int tacCount=0, tempCount=0, labelCount=0;

char *newTemp()  { char *t=malloc(10); sprintf(t,"t%d",tempCount++); return t; }
int   newLabel() { return labelCount++; }

void emitOp     (const char*res,const char*a1,const char*op,const char*a2) {
    if(tacCount>=1000) return;
    tac[tacCount].type=TAC_OP;
    strcpy(tac[tacCount].res,res); strcpy(tac[tacCount].arg1,a1);
    strcpy(tac[tacCount].op,op);   strcpy(tac[tacCount].arg2,a2);
    tac[tacCount].deleted=0; tac[tacCount].opt_info[0]='\0'; tacCount++;
}
void emitAssign (const char*res,const char*a1) {
    if(tacCount>=1000) return;
    tac[tacCount].type=TAC_ASSIGN;
    strcpy(tac[tacCount].res,res); strcpy(tac[tacCount].arg1,a1);
    tac[tacCount].op[0]=tac[tacCount].arg2[0]='\0';
    tac[tacCount].deleted=0; tac[tacCount].opt_info[0]='\0'; tacCount++;
}
void emitIfFalse(const char*cond,int lbl) {
    if(tacCount>=1000) return;
    tac[tacCount].type=TAC_IF_FALSE;
    strcpy(tac[tacCount].arg1,cond); sprintf(tac[tacCount].arg2,"%d",lbl);
    tac[tacCount].deleted=0; tac[tacCount].opt_info[0]='\0'; tacCount++;
}
void emitGoto   (int lbl) {
    if(tacCount>=1000) return;
    tac[tacCount].type=TAC_GOTO;
    sprintf(tac[tacCount].arg1,"%d",lbl);
    tac[tacCount].deleted=0; tac[tacCount].opt_info[0]='\0'; tacCount++;
}
void emitLabel  (int lbl) {
    if(tacCount>=1000) return;
    tac[tacCount].type=TAC_LABEL;
    sprintf(tac[tacCount].res,"%d",lbl);
    tac[tacCount].deleted=0; tac[tacCount].opt_info[0]='\0'; tacCount++;
}

int isNumeric(const char *s) {
    if (!s || !*s) return 0;
    if (*s=='-'||*s=='+') s++;
    int dot=0;
    for (; *s; s++) {
        if (*s=='.') { if(dot) return 0; dot=1; }
        else if (!isdigit((unsigned char)*s)) return 0;
    }
    return 1;
}

void optimizeTAC() {
    int changed = 1;
    while(changed) {
        changed = 0;
        for (int i=0; i<tacCount; i++) {
            if (tac[i].deleted) continue;

            if (tac[i].type == TAC_OP) {
                int isNum1 = isNumeric(tac[i].arg1);
                int isNum2 = isNumeric(tac[i].arg2);
                
                if (isNum1 && isNum2) {
                    float v1 = atof(tac[i].arg1), v2 = atof(tac[i].arg2), res = 0;
                    if (!strcmp(tac[i].op, "+")) res = v1 + v2;
                    else if (!strcmp(tac[i].op, "-")) res = v1 - v2;
                    else if (!strcmp(tac[i].op, "*")) res = v1 * v2;
                    else if (!strcmp(tac[i].op, "/")) res = v2 != 0 ? v1 / v2 : 0;
                    else if (!strcmp(tac[i].op, ">")) res = v1 > v2;
                    else if (!strcmp(tac[i].op, "<")) res = v1 < v2;
                    else if (!strcmp(tac[i].op, ">=")) res = v1 >= v2;
                    else if (!strcmp(tac[i].op, "<=")) res = v1 <= v2;
                    else if (!strcmp(tac[i].op, "==")) res = v1 == v2;
                    else if (!strcmp(tac[i].op, "!=")) res = v1 != v2;
                    
                    sprintf(tac[i].arg1, "%g", res);
                    tac[i].op[0] = tac[i].arg2[0] = '\0';
                    tac[i].type = TAC_ASSIGN;
                    strcpy(tac[i].opt_info, "Constant Folding");
                    changed = 1;
                }
            }
            
            if (tac[i].type == TAC_ASSIGN) {
                int isTemp = (tac[i].res[0] == 't' && isdigit((unsigned char)tac[i].res[1]));
                int canPropagate = isTemp || isNumeric(tac[i].arg1);
                
                if (canPropagate) {
                    for (int j=i+1; j<tacCount; j++) {
                        if (tac[j].deleted) continue;
                        if (!isTemp && tac[j].type == TAC_LABEL) break;
                        if ((tac[j].type == TAC_OP || tac[j].type == TAC_ASSIGN) && !strcmp(tac[j].res, tac[i].res)) break;
                        if (!isNumeric(tac[i].arg1) && (tac[j].type == TAC_OP || tac[j].type == TAC_ASSIGN) && !strcmp(tac[j].res, tac[i].arg1)) break;
                        
                        if (tac[j].type != TAC_LABEL && tac[j].type != TAC_GOTO) {
                            if (!strcmp(tac[j].arg1, tac[i].res)) {
                                strcpy(tac[j].arg1, tac[i].arg1);
                                strcpy(tac[j].opt_info, "Constant Propagation");
                                changed = 1;
                            }
                            if (tac[j].type == TAC_OP && !strcmp(tac[j].arg2, tac[i].res)) {
                                strcpy(tac[j].arg2, tac[i].arg1);
                                strcpy(tac[j].opt_info, "Constant Propagation");
                                changed = 1;
                            }
                        }
                    }
                    if (isTemp) {
                        tac[i].deleted = 1;
                        strcpy(tac[i].opt_info, "Dead Code Elimination (Temp)");
                        changed = 1;
                    }
                }
                
                if (!isTemp) {
                    int nextInstrIdx = -1;
                    for (int j=i+1; j<tacCount; j++) {
                        if (!tac[j].deleted) {
                            nextInstrIdx = j;
                            break;
                        }
                    }
                    if (nextInstrIdx != -1) {
                        int usedInNext = 0;
                        if ((tac[nextInstrIdx].type == TAC_ASSIGN || tac[nextInstrIdx].type == TAC_OP) && !strcmp(tac[nextInstrIdx].arg1, tac[i].res)) usedInNext = 1;
                        if (tac[nextInstrIdx].type == TAC_OP && !strcmp(tac[nextInstrIdx].arg2, tac[i].res)) usedInNext = 1;
                        
                        if (!usedInNext && (tac[nextInstrIdx].type == TAC_ASSIGN || tac[nextInstrIdx].type == TAC_OP) && !strcmp(tac[nextInstrIdx].res, tac[i].res)) {
                            tac[i].deleted = 1; 
                            strcpy(tac[i].opt_info, "Dead Store Elimination");
                            changed = 1;
                        }
                    }
                }
            }
            
            if (tac[i].type == TAC_IF_FALSE) {
                if (isNumeric(tac[i].arg1)) {
                    float cond = atof(tac[i].arg1);
                    if (cond != 0) {
                        tac[i].deleted = 1;
                        strcpy(tac[i].opt_info, "Dead Branch Elimination");
                        changed = 1;
                    } else {
                        tac[i].type = TAC_GOTO;
                        strcpy(tac[i].arg1, tac[i].arg2);
                        tac[i].arg2[0] = '\0';
                        strcpy(tac[i].opt_info, "Dead Branch Elimination");
                        changed = 1;
                    }
                }
            }
            
            if (tac[i].type == TAC_GOTO && !tac[i].deleted) {
                int nextLabelIdx = -1;
                for (int j=i+1; j<tacCount; j++) {
                    if (!tac[j].deleted) {
                        if (tac[j].type == TAC_LABEL && !strcmp(tac[j].res, tac[i].arg1)) {
                            nextLabelIdx = j;
                        }
                        break;
                    }
                }
                if (nextLabelIdx != -1) {
                    tac[i].deleted = 1;
                    strcpy(tac[i].opt_info, "Unreachable Code Elimination");
                    changed = 1;
                } else {
                    for (int j=i+1; j<tacCount; j++) {
                        if (tac[j].type == TAC_LABEL) break;
                        if (!tac[j].deleted) { 
                            tac[j].deleted = 1; 
                            strcpy(tac[j].opt_info, "Unreachable Code Elimination");
                            changed = 1; 
                        }
                    }
                }
            }

            if (tac[i].type == TAC_LABEL && !tac[i].deleted) {
                int used = 0;
                for (int j=0; j<tacCount; j++) {
                    if (tac[j].deleted) continue;
                    if (tac[j].type == TAC_GOTO && !strcmp(tac[j].arg1, tac[i].res)) used = 1;
                    if (tac[j].type == TAC_IF_FALSE && !strcmp(tac[j].arg2, tac[i].res)) used = 1;
                }
                if (!used) {
                    tac[i].deleted = 1;
                    strcpy(tac[i].opt_info, "Unused Label Elimination");
                    changed = 1;
                }
            }
        }
    }
}

void printSymbolTable() {
    printf("\n SYMBOL TABLE \n%-20s %-15s %-15s\n","Name","Type","Initialized");
    printf("----------------------------------------------------\n");
    for (int i=0; i<symcount; i++)
        printf("%-20s %-15s %-15d\n",symtab[i].name,symtab[i].type,symtab[i].initialized);
}

void printErrors() {
    printf("\nLEXICAL ERRORS\n");
    if (!lexCount) printf("No lexical error found\n");
    for (int i=0;i<lexCount;i++) printf("Line %d : LEXICAL ERROR : %s\n",lexErrors[i].line,lexErrors[i].msg);

    printf("\n SYNTAX ERRORS \n");
    if (!synCount) printf("No syntax error found\n");
    for (int i=0;i<synCount;i++) printf("Line %d : SYNTAX ERROR : %s\n",synErrors[i].line,synErrors[i].msg);

    if (!syntaxErrorFlag) {
        printf("\n SEMANTIC ERRORS \n");
        if (!semCount) printf("No semantic error found\n");
        for (int i=0;i<semCount;i++) printf("Line %d : SEMANTIC ERROR : %s\n",semErrors[i].line,semErrors[i].msg);
    }
}

void printTACArray(int optimized) {
    printf(optimized ? "\n------------- OPTIMIZED TAC -------------\n"
                     : "\n------------ UNOPTIMIZED TAC ------------\n");
    for (int i=0; i<tacCount; i++) {
        if (optimized && tac[i].deleted) continue;
        switch (tac[i].type) {
            case TAC_OP:       printf("%s = %s %s %s\n",tac[i].res,tac[i].arg1,tac[i].op,tac[i].arg2); break;
            case TAC_ASSIGN:   printf("%s = %s\n",tac[i].res,tac[i].arg1); break;
            case TAC_IF_FALSE: printf("if False %s goto L%s\n",tac[i].arg1,tac[i].arg2); break;
            case TAC_GOTO:     printf("goto L%s\n",tac[i].arg1); break;
            case TAC_LABEL:    printf("L%s:\n",tac[i].res); break;
        }
    }
}
%}

%union {
    char *str;
    int   intval;
    struct { char *type; char *addr; } expr_type;
}

%token <str> IDENTIFIER INUM FNUM STRING_LITERAL CHAR_LITERAL RELOP
%token INT FLOAT CHAR STRING IF ELSE FOR WHILE
%token PLUS MINUS MUL DIV ASSIGN
%token SEMI LPAREN RPAREN LBRACE RBRACE COMMA AMPERSAND

%type <expr_type> expr
%type <expr_type> for_cond_opt
%type <str>       type
%type <intval>    if_cond

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE
%nonassoc RELOP
%left PLUS MINUS
%left MUL DIV

%%

program : program stmt | stmt ;

stmt
    : decl | assign | if_stmt | while_stmt | for_stmt | block
    | error SEMI { addSynError(line,"Invalid statement"); yyerrok; }
    ;

block : LBRACE program RBRACE ;

decl
    : type IDENTIFIER SEMI                  { insert($2,$1); }
    | type IDENTIFIER ASSIGN expr SEMI      {
          insert($2,$1);
          int i=lookup($2);
          if(i!=-1 && !syntaxErrorFlag){
              if($4.type == NULL) { /* Do nothing, RHS had an error */ }
              else if(strcmp(symtab[i].type,$4.type)!=0)
                  addSemError(line,"Type mismatch in initialization");
              else { symtab[i].initialized=1; if($4.addr) emitAssign($2,$4.addr); }
          }
      }
    | type IDENTIFIER ASSIGN error SEMI     { addSynError(line,"Missing expression in declaration"); yyerrok; }
    ;
type : INT { $$="int"; } | FLOAT { $$="float"; } | CHAR { $$="char"; } | STRING { $$="string"; } ;

assign
    : IDENTIFIER ASSIGN expr SEMI {
          int i=lookup($1);
          if(i==-1 && !syntaxErrorFlag) addSemError(line,"Undeclared variable");
          else if(i!=-1 && !syntaxErrorFlag){
              if($3.type == NULL) { /* Do nothing, RHS had an error */ }
              else if(strcmp(symtab[i].type,$3.type)!=0) addSemError(line,"Type mismatch in assignment");
              else { symtab[i].initialized=1; if($3.addr) emitAssign($1,$3.addr); }
          }
      }
    | IDENTIFIER ASSIGN error SEMI { addSynError(line,"Missing expression after '='"); yyerrok; }
    ;

if_cond
    : IF LPAREN expr RPAREN {
          $$=newLabel();
          if($3.addr) emitIfFalse($3.addr,$$);
      }
    ;

if_stmt
    : if_cond stmt %prec LOWER_THAN_ELSE { emitLabel($1); }
    | if_cond stmt ELSE {
          $<intval>$=newLabel(); emitGoto($<intval>$); emitLabel($1);
      } stmt { emitLabel($<intval>4); }
    | IF LPAREN error RPAREN { addSynError(line,"Invalid condition in if"); yyerrok; }
    ;

while_stmt
    : WHILE LPAREN { $<intval>$ = newLabel(); emitLabel($<intval>$); } expr RPAREN {
          $<intval>$ = newLabel();
          if($4.addr) emitIfFalse($4.addr, $<intval>$);
      } stmt {
          emitGoto($<intval>3);
          emitLabel($<intval>6);
      }
    | WHILE LPAREN error RPAREN { addSynError(line,"Invalid condition in while"); yyerrok; }
    ;

for_init_opt
    : /* empty */
    | type IDENTIFIER {
          insert($2,$1);
      }
    | type IDENTIFIER ASSIGN expr {
          insert($2,$1);
          int i=lookup($2);
          if(i!=-1 && !syntaxErrorFlag){
              if($4.type == NULL) { /* Do nothing, RHS had an error */ }
              else if(strcmp(symtab[i].type,$4.type)!=0)
                  addSemError(line,"Type mismatch in initialization");
              else symtab[i].initialized=1;
          }
      }
    | IDENTIFIER ASSIGN expr {
          int i=lookup($1);
          if(i==-1 && !syntaxErrorFlag) addSemError(line,"Undeclared variable");
          else if(i!=-1 && !syntaxErrorFlag){
              if($3.type == NULL) { /* Do nothing, RHS had an error */ }
              else if(strcmp(symtab[i].type,$3.type)!=0) addSemError(line,"Type mismatch in assignment");
              else symtab[i].initialized=1;
          }
      }
    ;

for_cond_opt
    : /* empty */   { $$.type="int"; $$.addr=NULL; }
    | expr          { $$=$1; }
    ;

for_update_opt
    : /* empty */
    | IDENTIFIER ASSIGN expr {
          int i=lookup($1);
          if(i==-1 && !syntaxErrorFlag) addSemError(line,"Undeclared variable");
          else if(i!=-1 && !syntaxErrorFlag){
              if($3.type == NULL) { /* Do nothing, RHS had an error */ }
              else if(strcmp(symtab[i].type,$3.type)!=0) addSemError(line,"Type mismatch in assignment");
              else symtab[i].initialized=1;
          }
      }
    ;

for_stmt
    : FOR LPAREN for_init_opt SEMI 
      { $<intval>$ = newLabel(); emitLabel($<intval>$); }
      for_cond_opt SEMI 
      { $<intval>$ = newLabel(); if($6.addr) emitIfFalse($6.addr, $<intval>$); }
      { $<intval>$ = newLabel(); }
      { $<intval>$ = newLabel(); emitGoto($<intval>9); emitLabel($<intval>$); }
      for_update_opt RPAREN 
      { emitGoto($<intval>5); emitLabel($<intval>9); }
      stmt 
      { emitGoto($<intval>10); emitLabel($<intval>8); }
    | FOR LPAREN error RPAREN { addSynError(line,"Invalid for statement"); yyerrok; }
    ;

expr
    : expr PLUS  expr { $$.type=checkType($1.type,$3.type); if($$.type&&$1.addr&&$3.addr){$$.addr=newTemp();emitOp($$.addr,$1.addr,"+",$3.addr);}else $$.addr=NULL; }
    | expr MINUS expr { $$.type=checkType($1.type,$3.type); if($$.type&&$1.addr&&$3.addr){$$.addr=newTemp();emitOp($$.addr,$1.addr,"-",$3.addr);}else $$.addr=NULL; }
    | expr MUL   expr { $$.type=checkType($1.type,$3.type); if($$.type&&$1.addr&&$3.addr){$$.addr=newTemp();emitOp($$.addr,$1.addr,"*",$3.addr);}else $$.addr=NULL; }
    | expr DIV   expr { $$.type=checkType($1.type,$3.type); if($$.type&&$1.addr&&$3.addr){$$.addr=newTemp();emitOp($$.addr,$1.addr,"/",$3.addr);}else $$.addr=NULL; }
    | expr RELOP expr { $$.type="int"; if($1.addr&&$3.addr&&$2){$$.addr=newTemp();emitOp($$.addr,$1.addr,$2,$3.addr);}else $$.addr=NULL; }
    | IDENTIFIER {
          int i=lookup($1);
          if(i==-1&&!syntaxErrorFlag){ addSemError(line,"Undeclared variable"); $$.type=NULL; $$.addr=NULL; }
          else { $$.type=(i==-1)?NULL:symtab[i].type; $$.addr=strdup($1); }
      }
    | INUM           { $$.type="int";    $$.addr=strdup($1); }
    | FNUM           { $$.type="float";  $$.addr=strdup($1); }
    | STRING_LITERAL { $$.type="string"; $$.addr=strdup($1); }
    | CHAR_LITERAL   { $$.type="char";   $$.addr=strdup($1); }
    | LPAREN expr RPAREN { $$=$2; }
    ;

%%

extern FILE *yyin;
extern int   autocorrect_count;
FILE *temp_out = NULL;

int main(int argc, char **argv){
    if (argc > 1) {
        yyin = fopen(argv[1], "r");
        if (!yyin) { perror("Error opening input file"); return 1; }
        temp_out = fopen("temp_autocorrect.c", "w");
        if (!temp_out) { perror("Error opening temporary file"); return 1; }
    } else {
        printf("Note: Running from standard input. To auto-correct a file, run: ./compiler <filename>\n");
    }

    yyparse();

    if (temp_out) { fclose(temp_out); temp_out=NULL; }
    if (yyin && yyin!=stdin) { fclose(yyin); yyin=NULL; }

    if (argc>1 && autocorrect_count>0) {
        if (remove(argv[1])!=0) perror("Error removing original file");
        else if (rename("temp_autocorrect.c",argv[1])!=0) {
            perror("Error saving autocorrected file");
            printf("Auto-corrected output saved in 'temp_autocorrect.c'\n");
        } else printf("\nSuccessfully auto-corrected %d typo(s) in %s\n",autocorrect_count,argv[1]);
    } else if (argc>1) remove("temp_autocorrect.c");

    printf("\nTotal Errors: %d\n", errorCount);
    printErrors();
    if (!syntaxErrorFlag) {
        printSymbolTable();
        if (semCount==0 && errorCount==0) {
            printTACArray(0);
            optimizeTAC();
            printTACArray(1);
        }
    }
    return 0;
}

void yyerror(const char *s){}