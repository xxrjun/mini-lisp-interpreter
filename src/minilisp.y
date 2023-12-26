%{
    #include <stdio.h>
    #include <stdlib.h>
    
    #define bool int
    #define true 1
    #define false 0
    #define DEBUG_MODE 0
    #define TYPE_CHECKING_DEBUG_MODE 0

    int yylex();
    void yyerror(const char* message);

    enum ASTType {
            ast_root,

            /**
             * parameter type: NUMBER(s)
             * ouput type: NUMBER
             */
            ast_plus,
            ast_minus,
            ast_multiply,
            ast_divide,
            ast_modulus,

            /**
             * parameter type: NUMBER(s)
             * ouput type: BOOLEAN
             */
            ast_greater,
            ast_smaller,
            ast_equal,

            /**
             * parameter type: BOOLEAN(s)
             * ouput type: BOOLEAN
             */
            ast_and,
            ast_or,
            ast_not,

            ast_boolean,
            ast_number,
            ast_function,

            ast_print_num,
            ast_print_bool,

            ast_if_exp,
            ast_if_body,

            /** 
             * others
             */
            ast_equals_to_parent,
    };

    struct ASTNode {
        enum ASTType type;        
        struct ASTNode* left;
        struct ASTNode* right;

        union {
            bool bval;
            int ival;
            char* sval;
        } value;
    };
    

    struct ASTNode* root;

    struct ASTNode* new_node(enum ASTType type, struct ASTNode* left, struct ASTNode* right);
    struct ASTNode* new_node_int(enum ASTType type, int ival, struct ASTNode* left, struct ASTNode* right);
    struct ASTNode* new_node_bool(enum ASTType type, bool bval, struct ASTNode* left, struct ASTNode* right);
    struct ASTNode* new_node_str(enum ASTType type, char* sval, struct ASTNode* left, struct ASTNode* right);
    void free_node(struct ASTNode* node);
    void traverse_ast(struct ASTNode* root, enum ASTType prev_type);


    void type_checking(struct ASTNode* node, enum ASTType correct_type);
%}

%union{
    int bval;
    int ival;
    char* sval;
    struct ASTNode* nval;
}

%token PLUS MINUS MULTIPLY DIVIDE MODULUS GREATER SMALLER EQUAL
%token AND OR NOT
%token PRINT_NUM PRINT_BOOL
%token DEFINE FUN IF
%token LPAREN RPAREN
%token<bval> BOOL_VAL
%token<ival> NUMBER 
%token<sval> ID

%type<nval> stmts stmt def_stmt print_stmt 
%type<nval> exps exp variable
%type<nval> num_op plus minus multiply divide modulus greater smaller equal
%type<nval> logical_op and_op or_op not_op
%type<nval> fun_exp fun_call fun_body fun_name params param last_exp fun_ids ids
%type<nval> if_exp test_exp then_exp else_exp

%%

program     : stmts                             { root = $1;}
            ;

stmts       : stmt stmts                        { $$ = new_node(ast_root , $1, $2);} 
            | stmt                              { $$ = new_node(ast_root , $1, NULL);} 
            ;

stmt        : exp
            | def_stmt
            | print_stmt                        
            ;

print_stmt  : LPAREN PRINT_NUM exp RPAREN      { $$ = new_node(ast_print_num, $3, NULL);}
            | LPAREN PRINT_BOOL exp RPAREN     { $$ = new_node(ast_print_bool, $3, NULL);}
            ;

exps        : exp exps                         { $$ = new_node(ast_equals_to_parent, $1, $2);}
            | exp
            ;

exp         : BOOL_VAL                         { $$ = new_node_bool(ast_boolean, $1, NULL, NULL);}
            | NUMBER                           { $$ = new_node_int(ast_number, $1, NULL, NULL);}
            | variable                  
            | num_op
            | logical_op
            | fun_exp
            | fun_call
            | if_exp
            ;

/* Numeric operations  */
num_op      : plus
            | minus
            | multiply
            | divide
            | modulus
            | greater
            | smaller
            | equal
            ;

plus        : LPAREN PLUS exp exps RPAREN       { $$ = new_node(ast_plus, $3, $4);}
            ;
    
minus       : LPAREN MINUS exp exps RPAREN      { $$ = new_node(ast_minus, $3, $4);}
            ;

multiply    : LPAREN MULTIPLY exp exps RPAREN   { $$ = new_node(ast_multiply, $3, $4);}
            ;

divide      : LPAREN DIVIDE exp exps RPAREN     { $$ = new_node(ast_divide, $3, $4);}
            ;

modulus     : LPAREN MODULUS exp exps RPAREN    { $$ = new_node(ast_modulus, $3, $4);}
            ;

greater     : LPAREN GREATER exp exps RPAREN    { $$ = new_node(ast_greater, $3, $4);}
            ;

smaller     : LPAREN SMALLER exp exps RPAREN    { $$ = new_node(ast_smaller, $3, $4);}
            ;

equal       : LPAREN EQUAL exp exps RPAREN      { $$ = new_node(ast_equal, $3, $4);}
            ;

/* Logical operations */
logical_op  : and_op
            | or_op
            | not_op
            ;  

and_op      : LPAREN AND exp exps RPAREN        { $$ = new_node(ast_and, $3, $4);}
            ;

or_op       : LPAREN OR exp exps RPAREN         { $$ = new_node(ast_or, $3, $4);}
            ;
            
not_op      : LPAREN NOT exp RPAREN             { $$ = new_node(ast_not, $3, NULL);}
            ;

/* Definition */
def_stmt    : LPAREN DEFINE variable exp RPAREN
            ;

variable    : ID
            ;

/* Funtions */
fun_exp     : LPAREN FUN fun_ids fun_body RPAREN
            ;

fun_ids     : LPAREN ids RPAREN
            ;

ids         : ID ids
            |
            ;

fun_body    : exp
            ;

fun_call    : LPAREN fun_exp params RPAREN 
            | LPAREN fun_name params  RPAREN
            ;

params      : param params
            | 
            ;

param       : exp
            ;

last_exp    : exp
            ;

fun_name    : ID
            ; 

/* If expression */
if_exp      : LPAREN IF test_exp then_exp else_exp RPAREN { $$ = new_node(ast_if_exp, $3, new_node(ast_if_body, $4, $5));}
            ;

test_exp    : exp
            ;

then_exp    : exp
            ;   

else_exp    : exp
            ;

%%


struct ASTNode* new_node(enum ASTType type, struct ASTNode* left, struct ASTNode* right){
    struct ASTNode* node = (struct ASTNode*)malloc(sizeof(struct ASTNode));

    node->type = type;
    node->left = left;
    node->right = right;

    return node;
}

struct ASTNode* new_node_int(enum ASTType type, int ival, struct ASTNode* left, struct ASTNode* right){
    struct ASTNode* node = (struct ASTNode*)malloc(sizeof(struct ASTNode));

    node->type = type;
    node->value.ival = ival;
    node->left = left;
    node->right = right;

    return node;

}

struct ASTNode* new_node_bool(enum ASTType type, bool bval, struct ASTNode* left, struct ASTNode* right){
    struct ASTNode* node = (struct ASTNode*)malloc(sizeof(struct ASTNode));

    node->type = type;
    node->value.bval = bval;
    node->left = left;
    node->right = right;

    return node;


}

struct ASTNode* new_node_str(enum ASTType type, char* sval, struct ASTNode* left, struct ASTNode* right){
    struct ASTNode* node = (struct ASTNode*)malloc(sizeof(struct ASTNode));

    node->type = type;
    node->value.sval = sval;
    node->left = left;
    node->right = right;

    return node;

}

void free_node(struct ASTNode* node){
    if(node == NULL){
        return;
    }

    free_node(node->left);
    free_node(node->right);

    free(node);
}

void traverse_ast(struct ASTNode* node, enum ASTType prev_type){
    if(node == NULL){
        return;
    }

    if (node->type == ast_equals_to_parent){
        node->type = prev_type;
        
        if(DEBUG_MODE){
            printf("AST EQUALS TO PARENT\n");
            printf("AST TYPE: %d\n", node->type);
        }
    }

    traverse_ast(node->left, node->type);
    traverse_ast(node->right, node->type);


    switch(node->type){
        case ast_root:
            if(DEBUG_MODE){
                printf("AST ROOT\n");
            }

            break;
        
        case ast_plus:
            if(DEBUG_MODE){
                printf("AST PLUS\n");
            }

            type_checking(node->left, ast_number);
            type_checking(node->right, ast_number);

            node->value.ival = node->left->value.ival + node->right->value.ival;
            node->type = ast_number;
            break;
        
        case ast_minus:        
            if(DEBUG_MODE){
                printf("AST MINUS\n");
            }

            type_checking(node->left, ast_number);
            type_checking(node->right, ast_number);

            node->value.ival = node->left->value.ival - node->right->value.ival;
            node->type = ast_number;
            break;
        
        case ast_multiply:
            if(DEBUG_MODE){
                printf("AST MULTIPLY\n");
            }

            type_checking(node->left, ast_number);
            type_checking(node->right, ast_number);

            node->value.ival = node->left->value.ival * node->right->value.ival;
            node->type = ast_number;
            break;

        case ast_divide:
            if(DEBUG_MODE){
                printf("AST DIVIDE\n");
            }

            /* WARNING: should I check for division by zero? */
            
            type_checking(node->left, ast_number);
            type_checking(node->right, ast_number);
            
            node->value.ival = node->left->value.ival / node->right->value.ival;
            node->type = ast_number;
            break;

        case ast_modulus:
            if(DEBUG_MODE){
                printf("AST MODULUS\n");
            }

            /* WARNING: should I check for modulus by zero? */

            type_checking(node->left, ast_number);
            type_checking(node->right, ast_number);

            node->value.ival = node->left->value.ival % node->right->value.ival;
            node->type = ast_number;
            break;
        
        case ast_greater:
            if(DEBUG_MODE){
                printf("AST GREATER\n");
            }

            type_checking(node->left, ast_number);
            type_checking(node->right, ast_number);

            node->value.bval = node->left->value.ival > node->right->value.ival;
            node->type = ast_boolean;
            break;
        
        case ast_smaller:
            if(DEBUG_MODE){
                printf("AST SMALLER\n");
            }

            type_checking(node->left, ast_number);
            type_checking(node->right, ast_number);

            node->value.bval = node->left->value.ival < node->right->value.ival;
            node->type = ast_boolean;
            break;
        
        case ast_equal:
            if(DEBUG_MODE){
                printf("AST EQUAL\n");
            }

            type_checking(node->left, ast_number);
            type_checking(node->right, ast_number);

            node->value.bval = node->left->value.ival == node->right->value.ival;
            node->type = ast_boolean;
            break;
        
        case ast_and:
            if(DEBUG_MODE){
                printf("AST AND\n");
            }

            type_checking(node->left, ast_boolean);
            type_checking(node->right, ast_boolean);

            node->value.bval = node->left->value.bval && node->right->value.bval;
            node->type = ast_boolean;
            break;
        
        case ast_or:
            if(DEBUG_MODE){
                printf("AST OR\n");
            }

            type_checking(node->left, ast_boolean);
            type_checking(node->right, ast_boolean);

            node->value.bval = node->left->value.bval || node->right->value.bval;
            node->type = ast_boolean;
            break;
        
        case ast_not:     
            if(DEBUG_MODE){
                printf("AST NOT\n");
            }

            type_checking(node->left, ast_boolean);
            type_checking(node->right, ast_boolean);

            node->value.bval = !node->left->value.bval;
            node->type = ast_boolean;
            break;    
        
        case ast_print_bool:
            if(DEBUG_MODE){
                printf("AST PRINT BOOL\n");
            }
            
            traverse_ast(node->left, node->type);
        
            type_checking(node->left, ast_boolean);

            printf("%s\n", node->left->value.bval ? "#t" : "#f");
            
            free_node(node);
            break;
        
        case ast_print_num:
            if(DEBUG_MODE){
                printf("AST PRINT NUM. NUM VALUE: %d\n", node->left->value.ival);
            }

            traverse_ast(node->left, node->type);
        
            type_checking(node->left, ast_number);

            printf("%d\n", node->left->value.ival);

            free_node(node);
            break;
        
        case ast_if_exp:
            if(DEBUG_MODE){
                printf("AST IF EXP. IF EXP VALUE: %s\n", node->left->value.bval ? "#t" : "#f");
            }
            
            struct ASTNode* if_condition_node = node->left;
            type_checking(if_condition_node, ast_boolean);

            struct ASTNode* if_body_node = node->right;
            type_checking(if_body_node, ast_if_body);

            if(if_condition_node->value.bval) {
                traverse_ast(if_body_node->left, if_body_node->type);
                node->value.ival = if_body_node->left->value.ival;
            }
            else {
                traverse_ast(if_body_node->right, if_body_node->type);
                node->value.ival = if_body_node->right->value.ival;
            } 

            node->type = ast_number;

            break;
    }
}


void yyerror(const char* message){
    fprintf(stderr, "%s\n", message);
    
    exit(0);
}

void type_checking(struct ASTNode* node, enum ASTType correct_type){
    if(node == NULL){
        return;
    }
    
    if(DEBUG_MODE && TYPE_CHECKING_DEBUG_MODE){
        printf("TYPE CHECKING\n");
        printf("NODE TYPE: %d\n", node->type);
        printf("CORRECT TYPE: %d\n", correct_type);
    }


    if(node->type != correct_type){
        yyerror("Type error!");
        exit(0);
    }
}


int main(){
    yyparse();

    traverse_ast(root, ast_root);

    return 0;
}