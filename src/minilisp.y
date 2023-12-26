%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    
    #define bool int
    #define true 1
    #define false 0

    #define DEBUG_MODE 0
    #define TYPE_CHECKING_DEBUG_MODE 1
    
    #define HASH_NUMBER 5381
    #define SYMBOL_TABLE_SIZE 100

    int yylex();
    void yyerror(const char* message);

    typedef enum ASTType {
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
            ast_or, // 10
            ast_not,

            /**
             * types 
             */
            ast_boolean,
            ast_number,
            ast_function,

            ast_print_num,
            ast_print_bool,

            /**
             * if expression
             */
            ast_if_exp,
            ast_if_body,

            /**
             * definition
             */
            ast_define,
            ast_id, // 20

            /**
             * functions
             */
            ast_function_call,
            ast_funtiona_params,
            ast_function_name,
            ast_function_body,

            /** 
             * others
             */
            ast_equals_to_parent,
    } ASTType;
    
    typedef enum SymbolType {
        symbol_number,
        symbol_boolean,
        symbol_function,
    } SymbolType;

    typedef struct ASTNode {
        ASTType type;        
        struct ASTNode* left;
        struct ASTNode* right;

        union {
            bool bval;
            int ival;
            char* sval; // for id
        } value;
    } ASTNode;

    typedef struct SymbolEntry {
        char* name;
        int value;
        SymbolType type;
        struct SymbolEntry* next; // linked list to handle collisions
    } SymbolEntry;

    typedef struct {
        int size;
        struct SymbolEntry** table; // array of pointers to SymbolEntry
    } SymbolTable;
    

    ASTNode* root;
    SymbolTable* table;

    /* AST */
    ASTNode* new_node(ASTType type, ASTNode* left, ASTNode* right);
    ASTNode* new_node_int(int ival, ASTNode* left, ASTNode* right);
    ASTNode* new_node_bool(bool bval, ASTNode* left, ASTNode* right);
    ASTNode* new_node_id(char* sval, ASTNode* left, ASTNode* right);
    void free_node(ASTNode* node);
    void traverse_ast(ASTNode* root, ASTType prev_type);

    /* Helper functions to make the code more readable */
    void handle_arithmetic_operation(ASTNode* node, ASTType operation);
    void handle_logical_operation(ASTNode* node, ASTType operation);

    /* Type checking */
    // it could match the symbol type of ast_id (variable) to the ASTType (ast_number, ast_boolean, ast_function)
    void general_type_checking(ASTNode* node, ASTType correct_type); 

    /* Symbol table */
    SymbolTable* create_symbol_table(int size);
    unsigned int hash(char* str, int size);
    SymbolEntry* lookup_symbol(SymbolTable* table, char* name);
    SymbolEntry* create_symbol_entry(char* name, int value, SymbolType type);
    void insert_symbol(SymbolTable* table, char* name, int value, SymbolType type);
    ASTNode* get_ast_node_from_symbol(SymbolTable* table, char* name);
    
    void free_symbol_table(SymbolTable* table);
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
            | stmt
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

exp         : BOOL_VAL                         { $$ = new_node_bool($1, NULL, NULL);}
            | NUMBER                           { $$ = new_node_int($1, NULL, NULL);}
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
def_stmt    : LPAREN DEFINE variable exp RPAREN { $$ = new_node(ast_define, $3, $4);}
            ;

variable    : ID                                { $$ = new_node_id($1, NULL, NULL);}
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

/**
 * ==================================================================================================
 *
 * Abstract Syntax Tree (AST)
 *
 * ==================================================================================================   
 */

ASTNode* new_node(ASTType type, ASTNode* left, ASTNode* right){
    ASTNode* node = (ASTNode*)malloc(sizeof(struct ASTNode));

    node->type = type;
    node->left = left;
    node->right = right;

    return node;
}

ASTNode* new_node_int(int ival, ASTNode* left, ASTNode* right){
    ASTNode* node = (ASTNode*)malloc(sizeof(struct ASTNode));

    node->type = ast_number;
    node->value.ival = ival;
    node->left = left;
    node->right = right;

    return node;

}

ASTNode* new_node_bool(bool bval, ASTNode* left, ASTNode* right){
    ASTNode* node = (ASTNode*)malloc(sizeof(struct ASTNode));

    node->type = ast_boolean;
    node->value.bval = bval;
    node->left = left;
    node->right = right;

    return node;


}

ASTNode* new_node_id(char* sval, ASTNode* left, ASTNode* right){
    ASTNode* node = (ASTNode*)malloc(sizeof(struct ASTNode));

    node->type = ast_id; 
    node->value.sval = strdup(sval); // to prevent be affected by changes in the original string 
    node->left = left;
    node->right = right;

    if(DEBUG_MODE){
        printf("NEW NODE ID\n");
        printf("NODE TYPE: %d\n", node->type);
        printf("NODE VALUE: %s\n", node->value.sval);
    }

    return node;

}

void free_node(ASTNode* node){
    if(node == NULL){
        return;
    }

    free_node(node->left);
    free_node(node->right);

    free(node);
}

void traverse_ast(ASTNode* node, ASTType prev_type){
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

        /**
         * ----------------------------- Numeric operations -----------------------------
         */
         
        case ast_plus:
        case ast_minus:
        case ast_multiply:
        case ast_divide:
        case ast_modulus:
        case ast_greater:
        case ast_smaller:
        case ast_equal:
            if(DEBUG_MODE){
                printf("AST OPERATION (PLUS/MINUS/MULTIPLY/DIVIDE/MODULUS)\n");
            }

            handle_arithmetic_operation(node, node->type);
            break;

        /**
         * ----------------------------- Logical operations -----------------------------
         */
        case ast_and:
        case ast_or:
        case ast_not:     
            if(DEBUG_MODE){
                printf("AST OPERATION (AND/OR/NOT)\n");
            }

            handle_logical_operation(node, node->type);
            break;


        /**
         * ----------------------------- Print Functions -----------------------------
         */
        case ast_print_bool:
            if(DEBUG_MODE){
                printf("AST PRINT BOOL\n");
            }

            ASTNode* print_bool_node = node->left;
            
            // check is the print_bool_node is a variable
            // if it is, get the value from the symbol table
            // if not, just print the value
            if(print_bool_node->type == ast_id){
                SymbolEntry* entry = lookup_symbol(table, print_bool_node->value.sval);
                if(entry != NULL) {
                    print_bool_node->value.bval = entry->value;
                } else {
                    // check if the variable is defined
                    // WANRING: this is not in the project requirements, but I think it should be
                    yyerror("Variable not defined! You can't print it!");
                    exit(0);
                }
            }

            /* general_type_checking(print_bool_node, ast_boolean); */

            printf("%s\n", print_bool_node->value.bval ? "#t" : "#f");
            
            free_node(node);
            break;
        
        case ast_print_num:
            if(DEBUG_MODE){
                printf("AST PRINT NUM.\n");
            }

            ASTNode* print_num_node = node->left;
        
            // check is the print_num_node is a variable
            // if it is, get the value from the symbol table
            if(print_num_node->type == ast_id){
                print_num_node = get_ast_node_from_symbol(table, print_num_node->value.sval);
            }

            general_type_checking(print_num_node, ast_number);

            if(DEBUG_MODE){
                printf("PRINT NUM NODE TYPE: %d\n", print_num_node->type);
                printf("PRINT NUM NODE VALUE: %d\n", print_num_node->value.ival);
            }

            printf("%d\n", print_num_node->value.ival);

            free_node(node);
            break;
        
        /**
         * ----------------------------- If -----------------------------
         */

        case ast_if_exp:
            if(DEBUG_MODE){
                printf("AST IF EXP. IF EXP VALUE: %s\n", node->left->value.bval ? "#t" : "#f");
            }
            
            ASTNode* if_condition_node = node->left;
            general_type_checking(if_condition_node, ast_boolean);

            ASTNode* if_body_node = node->right;
            general_type_checking(if_body_node, ast_if_body);

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

        /**
         * ----------------------------- Definition -----------------------------
         */
        case ast_define:
            if(DEBUG_MODE){
                printf("AST DEFINE\n"); 
                printf("VARIABLE NAME: %s\n", node->left->value.sval);
                printf("VARIABLE VALUE: %d\n", node->right->value.ival);
            }

            // TODO: it will be able to handle functions and variables, but for now it only handles variables.
        
            // check if variable is already defined
            // if it is, return with error (not in project requirements, but I think it should be)
            // if not, insert it in the symbol table
            ASTNode* variable_name_node = node->left;
            general_type_checking(variable_name_node, ast_id);

            ASTNode* value_node = node->right;

            if(lookup_symbol(table, variable_name_node->value.sval) != NULL){
                yyerror("Variable already defined!");
                exit(0);
            } else {
                // get the type of the value
                SymbolType value_type;
                switch(value_node->type){
                    case ast_number:
                        value_type = symbol_number;
                        break;
                    case ast_boolean:
                        value_type = symbol_boolean;
                        break;
                    case ast_function:
                        value_type = symbol_function; // TODO: check if this would be handled here.
                        break;
                    default:
                        yyerror("Invalid value type!");
                        exit(0);
                }

                // insert the variable in the symbol table
                insert_symbol(table, variable_name_node->value.sval, value_node->value.ival, value_type);
            }
            
            break;
    }
}

/**
 * ==================================================================================================
 *
 * Helper functions to make the code more readable
 *
 * ==================================================================================================   
 */

void handle_arithmetic_operation(ASTNode* node, ASTType operation) {
    if (node == NULL) return;

    ASTNode* left_node = (node->left->type == ast_id) ? get_ast_node_from_symbol(table, node->left->value.sval) : node->left;
    ASTNode* right_node = (node->right->type == ast_id) ? get_ast_node_from_symbol(table, node->right->value.sval) : node->right;

    general_type_checking(left_node, ast_number);
    general_type_checking(right_node, ast_number);

    switch (operation) {
        case ast_plus:
            node->value.ival = left_node->value.ival + right_node->value.ival;
            node->type = ast_number;
            break;
        case ast_minus:
            node->value.ival = left_node->value.ival - right_node->value.ival;
            node->type = ast_number;
            break;
        case ast_multiply:
            node->value.ival = left_node->value.ival * right_node->value.ival;
            node->type = ast_number;
            break;
        case ast_divide:
            node->value.ival = left_node->value.ival / right_node->value.ival;
            node->type = ast_number;
            break;
        case ast_modulus:
            node->value.ival = left_node->value.ival % right_node->value.ival;
            node->type = ast_number;
            break;
        case ast_greater:
            node->value.bval = left_node->value.ival > right_node->value.ival;
            node->type = ast_boolean;
            break;
        case ast_smaller:
            node->value.bval = left_node->value.ival < right_node->value.ival;
            node->type = ast_boolean;
            break;
        case ast_equal:
            node->value.bval = left_node->value.ival == right_node->value.ival;
            node->type = ast_boolean;
            break;
        
    }
}

void handle_logical_operation(ASTNode* node, ASTType operation) {
    if (node == NULL) return;

    ASTNode* left_node = node->left;
    ASTNode* right_node = operation != ast_not ? node->right : NULL;

    general_type_checking(left_node, ast_boolean);

    // ugly special case for ast_not
    if(operation != ast_not){
        general_type_checking(right_node, ast_boolean);
    }

    switch (operation) {
        case ast_and:
            node->value.bval = left_node->value.bval && right_node->value.bval;
            node->type = ast_boolean;
            break;
        case ast_or:
            node->value.bval = left_node->value.bval || right_node->value.bval;
            node->type = ast_boolean;
            break;
        case ast_not:
            node->value.bval = !left_node->value.bval;
            node->type = ast_boolean;
            break;
    }
}


/**
 * Type checking TODO: Should be modify, ASTType should be SymbolType or one more function should be created
 */
void general_type_checking(ASTNode* node, ASTType correct_type){
    if(node == NULL){
        return;
    }
    
    if(DEBUG_MODE && TYPE_CHECKING_DEBUG_MODE){
        printf("TYPE CHECKING\n");
    }
    
    ASTType actual_type = node->type;

    // Special case for ast_id
    // TODO: Now it works, but it is ugly. Might be refactor after the project is done
    if(correct_type == ast_id){
        if(actual_type != correct_type){
            yyerror("Type error!");
            exit(0);
        }
    } else {
        // if node->type is ast_id, convert the actual_type based on the symbol type
        if(node->type == ast_id){
            ASTNode* tmp_node = get_ast_node_from_symbol(table, node->value.sval);
            if(tmp_node != NULL){
                actual_type = tmp_node->type;
                free_node(tmp_node);
            } else {
                yyerror("Variable not defined! In general_type_checking\n");
                exit(0);
            }
        }

        if(DEBUG_MODE && TYPE_CHECKING_DEBUG_MODE){
            printf("ACTUAL TYPE: %d\n", actual_type);
            printf("CORRECT TYPE: %d\n", correct_type);
        }

        if(actual_type != correct_type){
            yyerror("Type error!");
        }
    }
}

/**
 * ==================================================================================================
 *
 * Symbol table
 *
 * ==================================================================================================   
 */

/**
 * Hash function from http://www.cse.yorku.ca/~oz/hash.html
 * djb2 (k=33)
 */
unsigned int hash(char* str, int size){
    unsigned int hash = HASH_NUMBER;
    int c;

    while(c = *str++){
        hash = ((hash << 5) + hash) + c;
    }

    return hash % size;
}

SymbolTable* create_symbol_table(int size){
    SymbolTable* new_table = malloc(sizeof(SymbolTable));
    new_table->size = size;
    new_table->table = malloc(sizeof(SymbolEntry*) * size);
    for(int i = 0; i < size; i++){
        new_table->table[i] = NULL;
    }
    return new_table;
}

SymbolEntry* lookup_symbol(SymbolTable* table, char* name){
    unsigned int index = hash(name, table->size);
    SymbolEntry* entry = table->table[index];
    while(entry != NULL){
        if(strcmp(entry->name, name) == 0){
            return entry;
        }
        entry = entry->next; // collision
    }
    return NULL;
}

SymbolEntry* create_symbol_entry(char* name, int value, SymbolType type){
    SymbolEntry* entry = malloc(sizeof(SymbolEntry));
    entry->name = malloc(sizeof(char) * strlen(name));
    strcpy(entry->name, name);
    entry->value = value;
    entry->type = type;
    entry->next = NULL;
    return entry;
}


void insert_symbol(SymbolTable* table, char* name, int value, SymbolType type){
    SymbolEntry* entry = lookup_symbol(table, name);
    if(entry != NULL){
        entry->value = value;
        entry->type = type;
    }
    else{
        unsigned int index = hash(name, table->size);
        SymbolEntry* new_entry = create_symbol_entry(name, value, type);
        new_entry->next = table->table[index];
        table->table[index] = new_entry;
    }
}

ASTNode* get_ast_node_from_symbol(SymbolTable* table, char* name){
    SymbolEntry* entry = lookup_symbol(table, name);
    if(entry != NULL){

        if(DEBUG_MODE){
            printf("GET AST NODE FROM SYMBOL\n");
            printf("SYMBOL NAME: %s\n", entry->name);
            printf("SYMBOL VALUE: %d\n", entry->value);
            printf("SYMBOL TYPE: %d\n", entry->type);
        }

        switch(entry->type){
            case symbol_number:
                return new_node_int(entry->value, NULL, NULL);
            case symbol_boolean:
                return new_node_bool(entry->value, NULL, NULL);
            /* case symbol_function:
                return; // TODO: handle this case */
        }
    } else {
        yyerror("Variable not defined! In get_ast_node_from_symbol\n");
    }
}


void free_symbol_table(SymbolTable* table){
    for(int i = 0; i < table->size; i++){
        SymbolEntry* entry = table->table[i];
        while(entry != NULL){
            SymbolEntry* next = entry->next;
            free(entry->name);
            free(entry);
            entry = next;
        }
    }
    free(table->table);
    free(table);
}



void yyerror(const char* message){
    fprintf(stderr, "%s\n", message);
    
    /* if(!DEBUG_MODE){ */
        exit(0);
    /* } */
}

int main(){
    table = create_symbol_table(SYMBOL_TABLE_SIZE);

    yyparse();

    traverse_ast(root, ast_root);


    if(DEBUG_MODE){
        // print symbol table
        printf("\n");
        printf("========== SYMBOL TABLE ==========\n");
        for(int i = 0; i < table->size; i++){
            SymbolEntry* entry = table->table[i];
            while(entry != NULL){
                printf("NAME: %s\n", entry->name);
                printf("VALUE: %d\n", entry->value);
                printf("SYMBOL TYPE: %d\n", entry->type);
                printf("\n");
                entry = entry->next;
            }
        }
        printf("==================================\n");
    }

    free_symbol_table(table);

    return 0;
}