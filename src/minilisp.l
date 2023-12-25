%{
    #include "minilisp.tab.h"  
%}

%option noyywrap

/* Preliminary definitions */
seperator ['\t'|'\n'|'\r'|' ']
letter [a-z]
digit [0-9]

/* Token Definitions */
/* Only tree types in LISP */
numbers 0|[1-9]{digit}*|-[1-9]{digit}*
id {letter}({letter}|{digit}|'-')*
bool_val_t  #t
bool_val_f  #f

%%

"("            { return LPAREN; }
")"            { return RPAREN; }

"+"             { return PLUS; }
"-"             { return MINUS; }
"*"             { return MULTIPLY; }
"/"             { return DIVIDE; }
"mod"           { return MODULUS; }
">"             { return GREATER; }
"<"             { return SMALLER; }
"="             { return EQUAL; }

"and"           { return AND; }
"or"            { return OR; }
"not"           { return NOT; }

"print-num"     { return PRINT_NUM; }
"print-bool"    { return PRINT_BOOL; }

"define"        { return DEFINE; }
"fun"           { return FUN; }    
"if"            { return IF; }

{numbers}       { yylval.ival = atoi(yytext); return NUMBER; }
{id}            { yylval.sval = yytext; return ID; }
{bool_val_t}    { yylval.bval = 1; return BOOL_VAL; }
{bool_val_f}    { yylval.bval = 0; return BOOL_VAL; }


{seperator}     { /* ignore seperators */ }
.               {/* Do nothing */}


%%