%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    
    #define bool int
    #define true 1
    #define false 0

    #define DEBUG_MODE 0
    #define TYPE_CHECKING_DEBUG_MODE 0
    #define SCOPE_STACK_DEBUG_MODE 1
    #define EXIT_WHEN_ERROR_IN_DEBUG_MODE 1
    
    #define HASH_NUMBER 5381
    #define MAX_SYMBOL_TABLE_SIZE 100
    #define MAX_SCOPE_STACK_SIZE 100

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
            ast_function, // function expr

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
            ast_function_ids,
            ast_function_call,
            ast_function_params,
            ast_function_name,
            ast_function_body,
            ast_function_define_in_body,

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
            bool bval;  // for boolean
            int ival;   // for number
            char* sval; // for id
        } value;
    } ASTNode;

    typedef struct Function {
        char* name;  // NULL for anonymous functions
        char** params;  // The parameter names as an array of ids
        int param_count;  // The number of parameters
        ASTNode* body;  // The function body as an ASTNode
    } Function;

    typedef struct SymbolEntry {
        char* name;
        union {
            int value;  // For variables
            Function* func;  // For functions
        };
        SymbolType type;
        struct SymbolEntry* next; // linked list to handle collisions
    } SymbolEntry;

    typedef struct SymbolTable {
        int size;
        struct SymbolEntry** table; // array of pointers to SymbolEntry
    } SymbolTable;

    typedef struct ScopeStack{
        SymbolTable** tables;
        int top;
        int capacity;
    } ScopeStack;

  
    ASTNode* root;
    // SymbolTable* table;
    ScopeStack* scope_stack; // store the symbol table for each scope

    /* AST */
    ASTNode* new_node(ASTType type, ASTNode* left, ASTNode* right);
    ASTNode* new_node_int(int ival, ASTNode* left, ASTNode* right);
    ASTNode* new_node_bool(bool bval, ASTNode* left, ASTNode* right);
    ASTNode* new_node_id(char* sval, ASTNode* left, ASTNode* right);
    void free_node(ASTNode* node);
    void traverse_ast(ASTNode* root, ASTType prev_type);
    ASTNode* clone_ast(ASTNode* node);
    /* Functions */
    char** extract_function_params(ASTNode* fun_ids, int param_count);
    Function* create_function(char* name, ASTNode* fun_ids, ASTNode* body);
    void bind_parameters_to_scope(char** params, ASTNode* args, ScopeStack* stack, int param_count);

    /* Helper functions to make the code more readable */
    void handle_arithmetic_operation(ASTNode* node, ASTType operation);
    void handle_logical_operation(ASTNode* node, ASTType operation);

    /* Type checking */
    // it could match the symbol type of ast_id (variable) to the ASTType (ast_number, ast_boolean, ast_function)
    void general_type_checking(ASTNode* node, ASTType correct_type); 

    /* Symbol table & Scope Stack */
    SymbolTable* create_symbol_table(int size);
    unsigned int hash(char* str, int size);
    void insert_symbol(ScopeStack* stack, char* name, void* symbol_value, SymbolType type);
    SymbolEntry* create_symbol_entry(char* name, void* symbol_value, SymbolType type);
    SymbolEntry* lookup_symbol(ScopeStack* stack, char* name);
    ASTNode* get_ast_node_from_symbol(ScopeStack* stack, char* name);
    void free_symbol_table(SymbolTable* table);

    ScopeStack* create_scope_stack(int capacity);
    void push_scope_stack(ScopeStack* stack, SymbolTable* table);
    SymbolTable* pop_scope_stack(ScopeStack* stack);
    void free_scope_stack(ScopeStack* stack);

    /* Others */
    char* get_ast_type(ASTType type);
    char* get_symbol_type(SymbolType type);
    char* get_raw_data_type_from_ast_type(ASTType type);
    void print_symbol_table(SymbolTable* table);
    void print_scope_stack(ScopeStack* stack);
    void print_ast_tree(ASTNode* node);
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
%type<nval> fun_exp fun_call fun_body fun_name params param  fun_ids ids
%type<nval> if_exp test_exp then_exp else_exp
/* %type<nval> last_exp  */ // don't know what is this for, so I comment it out

%%

program     : stmts                             { root = $1; }
            ;

stmts       : stmt stmts                        { $$ = new_node(ast_root, $1, $2); } 
            | stmt
            ;

stmt        : exp
            | def_stmt
            | print_stmt                        
            ;

print_stmt  : LPAREN PRINT_NUM exp RPAREN       { $$ = new_node(ast_print_num, $3, NULL); }
            | LPAREN PRINT_BOOL exp RPAREN      { $$ = new_node(ast_print_bool, $3, NULL); }
            ;

exps        : exp exps                          { $$ = new_node(ast_equals_to_parent, $1, $2); }
            | exp
            ;

exp         : BOOL_VAL                          { $$ = new_node_bool($1, NULL, NULL); }
            | NUMBER                            { $$ = new_node_int($1, NULL, NULL); }
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

plus        : LPAREN PLUS exp exps RPAREN       { $$ = new_node(ast_plus, $3, $4); }
            ;
    
minus       : LPAREN MINUS exp exps RPAREN      { $$ = new_node(ast_minus, $3, $4); }
            ;

multiply    : LPAREN MULTIPLY exp exps RPAREN   { $$ = new_node(ast_multiply, $3, $4); }
            ;

divide      : LPAREN DIVIDE exp exps RPAREN     { $$ = new_node(ast_divide, $3, $4); }
            ;

modulus     : LPAREN MODULUS exp exps RPAREN    { $$ = new_node(ast_modulus, $3, $4); }
            ;

greater     : LPAREN GREATER exp exps RPAREN    { $$ = new_node(ast_greater, $3, $4); }
            ;

smaller     : LPAREN SMALLER exp exps RPAREN    { $$ = new_node(ast_smaller, $3, $4); }
            ;

equal       : LPAREN EQUAL exp exps RPAREN      { $$ = new_node(ast_equal, $3, $4); }
            ;

/* Logical operations */
logical_op  : and_op
            | or_op
            | not_op
            ;  

and_op      : LPAREN AND exp exps RPAREN        { $$ = new_node(ast_and, $3, $4); }
            ;

or_op       : LPAREN OR exp exps RPAREN         { $$ = new_node(ast_or, $3, $4); }
            ;
            
not_op      : LPAREN NOT exp RPAREN             { $$ = new_node(ast_not, $3, NULL); }
            ;

/* Definition */
def_stmt    : LPAREN DEFINE variable exp RPAREN { $$ = new_node(ast_define, $3, $4); }
            ;

variable    : ID                                { $$ = new_node_id($1, NULL, NULL); }
            ;

/* Funtions */
fun_exp     : LPAREN FUN fun_ids fun_body RPAREN    { $$ = new_node(ast_function, $3, $4); }
            ;

fun_ids     : LPAREN ids RPAREN                 { $$ = $2; }
            ;

ids         : ID ids                            { $$ = new_node(ast_function_ids, new_node_id($1, NULL, NULL), $2); }
            |                                   { $$ = NULL; }
            ;

fun_body    : def_stmt fun_body                 { $$ = new_node(ast_function_define_in_body, $1, $2); }
            | exp                        
            ;

fun_call    : LPAREN fun_exp params RPAREN      { $$ = new_node(ast_function_call, $2, $3); }
            | LPAREN fun_name params  RPAREN    { $$ = new_node(ast_function_call, $2, $3); }
            ;

params      : param params                      { $$ = new_node(ast_function_params, $1, $2); }
            |                                   { $$ = NULL; }
            ;

param       : exp
            ;

/* last_exp    : exp
            ; */

fun_name    : ID                                { $$ = new_node_id($1, NULL, NULL); }
            ; 

/* If expression */
if_exp      : LPAREN IF test_exp then_exp else_exp RPAREN { $$ = new_node(ast_if_exp, $3, new_node(ast_if_body, $4, $5)); }
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
    if(DEBUG_MODE){
        printf("NEW NODE ID\n");
        printf("NODE VALUE (Name): %s\n", sval);
    }

    ASTNode* node = (ASTNode*)malloc(sizeof(struct ASTNode));
    node->type = ast_id;  // TODO: set boolean, number or function based on the symbol type here might be better
    node->value.sval = strdup(sval); // to prevent be affected by changes in the original string 
    node->left = left;
    node->right = right;

    if(DEBUG_MODE){
        printf("NODE TYPE: %s\n", get_ast_type(node->type));
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

ASTNode* clone_ast(ASTNode* node){
    if(node == NULL){
        return NULL;
    }

    ASTNode* new_node = (ASTNode*)malloc(sizeof(struct ASTNode));
    new_node->type = node->type;
    // if value is a string, strdup it to prevent be affected by changes in the original string
    if(node->type == ast_id){
        new_node->value.sval = strdup(node->value.sval);
    } else {
        new_node->value = node->value;
    }

    new_node->left = clone_ast(node->left);
    new_node->right = clone_ast(node->right);

    return new_node;
}

Function* create_function(char* name, ASTNode* fun_ids, ASTNode* body){
    if(DEBUG_MODE){
        printf("CREATE FUNCTION\n");
        printf("FUNCTION NAME: %s\n", name);
        printf("FIRST FUNCTION PARAM: %s\n", fun_ids == NULL ? "NULL" : fun_ids->left->value.sval);
    }

    int param_count = 0;
    ASTNode* current = fun_ids;
    while (current != NULL) {
        param_count++;
        current = current->right;
    }

    Function* func = (Function*)malloc(sizeof(Function));
    func->name = strdup(name);
    func->params = extract_function_params(fun_ids, param_count);
    func->param_count = param_count;
    func->body = body;
    return func;

}


char** extract_function_params(ASTNode* fun_ids_node, int param_count){
    if(fun_ids_node == NULL){
        return NULL;
    }

    char** params = malloc(sizeof(char*) * (param_count));
    ASTNode* current = fun_ids_node;
    int index = 0;
    while (current != NULL && current->left != NULL) {
        params[index++] = strdup(current->left->value.sval);
        current = current->right;
    }
    return params;
}

void bind_parameters_to_scope(char** params, ASTNode* args, ScopeStack* stack, int param_count){
    if(DEBUG_MODE){
        printf("BIND PARAMETERS TO SCOPE\n");
        printf("PARAM COUNT: %d\n", param_count);
    }

    if(param_count == 0){
        if(DEBUG_MODE){
            printf("PARAM COUNT IS 0. JUST RETURN\n");
        }
        return;
    }

    if(args == NULL){
        yyerror("Invalid number of arguments! Because args is NULL\n");
        exit(0);
    }

    // bind the parameters to the scope
    int index = 0;
    ASTNode* current = args;
    while (current != NULL && current->left != NULL && index < param_count) {
        // Evaluate the argument if it's a function
        // TODO: They way handle function call could be refactor, it's ugly now
        // The only difference is the scope is still the same, so we don't need to create a new scope 
        if(current->left->type == ast_function_call){
            if(DEBUG_MODE){
                printf("FUNCTION CALL in bind_parameters_to_scope: %s\n", current->left->left->value.sval);
            }
            SymbolEntry* func_entry = lookup_symbol(scope_stack, current->left->left->value.sval);
            if(func_entry != NULL && func_entry->type == symbol_function){
                Function* func = func_entry->func;
                ASTNode* function_body_node = clone_ast(func->body);

                // bind the parameters to the scope
                bind_parameters_to_scope(func->params, current->left->right, scope_stack, func->param_count);

                current->type = function_body_node->type;
                current->value = function_body_node->value;

                current->left = clone_ast(function_body_node->left);
                current->right = clone_ast(function_body_node->right);

                // bind the result to the scope
                if(function_body_node->type == ast_number){
                    insert_symbol(scope_stack, params[index++], &(function_body_node->value.ival), symbol_number);
                } else if(function_body_node->type == ast_boolean){
                    insert_symbol(scope_stack, params[index++], &(function_body_node->value.bval), symbol_boolean);
                } else if(function_body_node->type == ast_function){ // function 
                    insert_symbol(scope_stack, params[index++], &(function_body_node->value.sval), symbol_function);
                } else {
                    yyerror("Invalid argument type!1");
                }

            } else {
                yyerror("Function not defined! In bind_parameters_to_scope\n");
            }

        } else {
            if(current->left->type == ast_number){
                insert_symbol(scope_stack, params[index++], &(current->left->value.ival), symbol_number);
            } else if(current->left->type == ast_boolean){
                insert_symbol(scope_stack, params[index++], &(current->left->value.bval), symbol_boolean);
            } else if (current->left->type == ast_function){
                insert_symbol(scope_stack, params[index++], &(current->left->value.sval), symbol_function);
            } else if (current->left->type == ast_id) {
                // get value from symbol table
                ASTNode* tmp_node = get_ast_node_from_symbol(scope_stack, current->left->value.sval);
                if(tmp_node != NULL){
                    if(tmp_node->type == ast_number){
                        insert_symbol(scope_stack, params[index++], &(tmp_node->value.ival), symbol_number);
                    } else if(tmp_node->type == ast_boolean){
                        insert_symbol(scope_stack, params[index++], &(tmp_node->value.bval), symbol_boolean);
                    } else if(tmp_node->type == ast_function){
                        insert_symbol(scope_stack, params[index++], &(tmp_node->value.sval), symbol_function);
                    } else {
                        yyerror("Invalid argument type!3");
                    }
                } else {
                    char* error_message = (char*)malloc(sizeof(char) * 100);
                    sprintf(error_message, "Variable not defined! In bind_parameters_to_scope. name: %s\n", current->left->value.sval);
                    yyerror(error_message);
                }
            } else {
                yyerror("Invalid argument type!2");
            }
        }
        current = current->right;
    }

    if(DEBUG_MODE){
        printf("BIND PARAMETERS TO SCOPE DONE\n");
    }
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

  
    /* traverse_ast(node->left, node->type);
    traverse_ast(node->right, node->type); */

    switch(node->type){
        case ast_root:
            if(DEBUG_MODE){
                printf("AST ROOT\n");
            }
            traverse_ast(node->left, node->type);
            traverse_ast(node->right, node->type);
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
                printf("AST OPERATION (PLUS/MINUS/MULTIPLY/DIVIDE/MODULUS/GREATER/SMALLER/EQUAL)\n");
            }
            traverse_ast(node->left, node->type);
            traverse_ast(node->right, node->type);
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
            traverse_ast(node->left, node->type);
            traverse_ast(node->right, node->type);
            handle_logical_operation(node, node->type);
            break;


        /**
         * ----------------------------- Print Functions -----------------------------
         */
        case ast_print_bool:
            if(DEBUG_MODE){
                printf("AST PRINT BOOL\n");
            }
            traverse_ast(node->left, node->type);
            ASTNode* print_bool_node = node->left->type == ast_id ? 
                                        get_ast_node_from_symbol(scope_stack, node->left->value.sval) : node->left;
            
            general_type_checking(print_bool_node, ast_boolean);
            printf("%s\n", print_bool_node->value.bval ? "#t" : "#f");
            free_node(node);
            break;
        
        case ast_print_num:
            if(DEBUG_MODE){
                printf("AST PRINT NUM\n");
            }
            traverse_ast(node->left, node->type);
            ASTNode* print_num_node = node->left->type == ast_id ?
                                        get_ast_node_from_symbol(scope_stack, node->left->value.sval) : node->left;

            general_type_checking(print_num_node, ast_number);
            printf("%d\n", print_num_node->value.ival);
            /* free_node(node); */
            break;
        
        /**
         * ----------------------------- If -----------------------------
         */

        case ast_if_exp:
            if(DEBUG_MODE){
                printf("AST IF EXP\n");
            }
            traverse_ast(node->left, node->type);

            ASTNode* if_condition_node = node->left;
            general_type_checking(if_condition_node, ast_boolean);

            ASTNode* if_body_node = node->right;
            general_type_checking(if_body_node, ast_if_body);

            if(if_condition_node->value.bval) {
                if(DEBUG_MODE){
                    printf("IF CONDITION IS TRUE\n");
                }
                traverse_ast(if_body_node->left, if_body_node->left->type);
                node->type = if_body_node->left->type;
                node->value = if_body_node->left->value;
            } else {
                if(DEBUG_MODE){
                    printf("IF CONDITION IS FALSE\n");
                }
                traverse_ast(if_body_node->right, if_body_node->right->type);
                node->type = if_body_node->right->type;
                node->value = if_body_node->right->value;
            }

            break;

        /**
         * ----------------------------- Definition -----------------------------
         */
        case ast_define:
            if(DEBUG_MODE){
                printf("AST DEFINE\n"); 
                printf("VARIABLE NAME: %s\n", node->left->value.sval);
                printf("AST TYPE: %s\n", get_ast_type(node->right->type));
            }

            if(node->right->type == ast_function){
            } else {
                traverse_ast(node->left, node->type);
                traverse_ast(node->right, node->type);
            }
           
            // check if variable is already defined
            // if it is, return with error (not in project requirements, but I think it should be)
            // if not, insert it in the symbol table
            ASTNode* variable_name_node = node->left;
            general_type_checking(variable_name_node, ast_id);

            ASTNode* value_node = node->right;

            if(lookup_symbol(scope_stack, variable_name_node->value.sval) != NULL){
                yyerror("Variable already defined!");
            } else {
                // get the type of the value
                SymbolType value_type;
                switch(value_node->type){
                    case ast_number:
                        value_type = symbol_number;
                        insert_symbol(scope_stack, variable_name_node->value.sval, &(value_node->value.ival), value_type);
                        break;
                    case ast_boolean:
                        value_type = symbol_boolean;
                        insert_symbol(scope_stack, variable_name_node->value.sval, &(value_node->value.bval), value_type);
                        break;
                    case ast_function:
                        value_type = symbol_function;
                        // copy node and create a new function, this is to prevent the function body from being affected by the changes in the original function
                        ASTNode* function_ids_node = clone_ast(value_node->left);
                        ASTNode* function_body_node = clone_ast(value_node->right);

                        // create a function structure
                        Function* func = create_function(variable_name_node->value.sval, function_ids_node, function_body_node);

                        // insert the function in the symbol table
                        insert_symbol(scope_stack, variable_name_node->value.sval, func, value_type);
                        break;
                    default:
                        yyerror("Invalid value type!");
                }
            }
            
            break;
        
        case ast_function_define_in_body:
            if(DEBUG_MODE){
                printf("AST FUNCTION DEFINE IN BODY\n");
            }
            traverse_ast(node->left, node->type);
            traverse_ast(node->right, node->type);

            node->type = node->right->type;
            node->value = node->right->value;
        
            break;
        /**
         * ----------------------------- Functions -----------------------------
         */
        case ast_function_call:
            if(DEBUG_MODE){
                printf("AST FUNCTION CALL");
            }

            // the left of ast_function_call node is either a ast_function_exp or a ast_function_name
            // the right of ast_function_call node is a ast_function_params
            
            // the left of ast_function_exp is a ast_function_ids
            // the right of ast_function_exp is a ast_function_body

            if(node->left->type == ast_function){
                // 1. anonymous function

                if(DEBUG_MODE){
                    printf(" - ANONYMOUS FUNCTION\n");
                }

                ASTNode* function_exp_node = clone_ast(node->left);
                ASTNode* function_ids_node = clone_ast(function_exp_node->left);
                ASTNode* function_body_node = clone_ast(function_exp_node->right);

                // create a function structure
                Function* func = create_function(" ", function_ids_node, function_body_node);

                // insert the function in the symbol table
                insert_symbol(scope_stack, func->name, func, symbol_function);

                // extract the function from the symbol table (it's the last inserted anonymous function)
                SymbolEntry* func_entry = lookup_symbol(scope_stack, " ");
                if(func_entry != NULL && func_entry->type == symbol_function){
                    Function* func = func_entry->func;
                    ASTNode* function_body_node = func->body;

                    // create a new symbol table for the function
                    SymbolTable* new_scope_table = create_symbol_table(MAX_SYMBOL_TABLE_SIZE);
                    push_scope_stack(scope_stack, new_scope_table);

                    // traverse the function parameters
                    traverse_ast(node->right, node->type);

                    // bind the parameters to the scope
                    bind_parameters_to_scope(func->params, node->right, scope_stack, func->param_count);

                    // traverse the function body
                    traverse_ast(function_body_node, function_body_node->type);
                    
                    node->type = function_body_node->type;
                    node->value = function_body_node->value;                    

                    // pop the symbol table from the scope stack
                    pop_scope_stack(scope_stack);

                    // free the symbol table
                    free_symbol_table(new_scope_table);

                    // free the function
                    free(func);
                } else {
                    yyerror("Function not defined! In ast_function_call\n");
                }
            } else if(node->left->type == ast_id) { 
                // 2. function with name

                if(DEBUG_MODE){
                    printf(" - FUNCTION WITH NAME: %s\n", node->left->value.sval);
                }

                // get the function name
                char* function_name = node->left->value.sval;

                // get the function from the symbol table
                SymbolEntry* func_entry = lookup_symbol(scope_stack, function_name);

                if(func_entry != NULL && func_entry->type == symbol_function){
                    Function* func = func_entry->func;
                    ASTNode* function_body_node = clone_ast(func->body);

                    // create a new symbol table for the function
                    SymbolTable* new_scope_table = create_symbol_table(MAX_SYMBOL_TABLE_SIZE);
                    push_scope_stack(scope_stack, new_scope_table);

                    if(DEBUG_MODE && SCOPE_STACK_DEBUG_MODE){
                        printf("PUSH SCOPE STACK\n");
                        print_scope_stack(scope_stack);
                    }

                    // traverse the function parameters
                    traverse_ast(node->right, node->type);

                    if(DEBUG_MODE){
                        printf("node->right->left->type: %s\n", get_ast_type(node->right->left->type));
                        if(get_ast_type(node->right->left->type) == "ast_id"){
                            printf("node->right->left->value.sval: %s\n", node->right->left->value.sval);
                        }
                    }

                    // bind the parameters to the scope
                    bind_parameters_to_scope(func->params, node->right, scope_stack, func->param_count);
                   
                    // traverse the function body
                    traverse_ast(function_body_node, function_body_node->type);

                    // TODO: Truely ugly.. Might be refactor after the project is done
                    if(function_body_node->type == ast_id){
                        ASTNode* tmp_node = get_ast_node_from_symbol(scope_stack, function_body_node->value.sval);
                        if(tmp_node != NULL){
                            node->type = tmp_node->type;
                            node->value = tmp_node->value;
                            free_node(tmp_node);
                        } else {
                            char* error_message = (char*)malloc(sizeof(char) * 100);
                            sprintf(error_message, "Variable not defined! In ast_function_call. name: %s\n", function_body_node->value.sval);
                            yyerror(error_message);
                        }
                    } else {
                        node->type = function_body_node->type;
                        node->value = function_body_node->value;
                    }


                    node->left = clone_ast(function_body_node->left);
                    node->right = clone_ast(function_body_node->right);

                    if(DEBUG_MODE){
                        printf("FUNCTION BODY TYPE: %s\n", get_ast_type(function_body_node->type));
                        printf("FUNCTION BODY VALUE: %d\n", function_body_node->value.ival);
                        printf("NODE TYPE: %s\n", get_ast_type(node->type));
                        printf("NODE VALUE: %d\n", node->value.ival);
                    }

                    // pop the symbol table from the scope stack
                    pop_scope_stack(scope_stack);

                    if(DEBUG_MODE && SCOPE_STACK_DEBUG_MODE){
                        printf("POP SCOPE STACK\n");
                        print_scope_stack(scope_stack);
                    }

                    // free the symbol table
                    free_symbol_table(new_scope_table);

                } else {
                    yyerror("Function not defined! In ast_function_call\n");
                }

            } else {
                yyerror("Invalid function call!");
            }

            break;
        default:
            if(DEBUG_MODE){
                /* printf("AST DEFAULT CASE: %s\n", get_ast_type(node->type));
                printf("AST TYPE: %s\n", get_ast_type(node->type)); */
            }
            traverse_ast(node->left, node->type);
            traverse_ast(node->right, node->type);
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

    if(DEBUG_MODE){
        printf("HANDLE ARITHMETIC OPERATION: %s\n", get_ast_type(operation));
        printf("LEFT NODE TYPE: %s, RIGHT NODE TYPE: %s\n", get_ast_type(node->left->type), get_ast_type(node->right->type));
    }

    ASTNode* left_node = (node->left->type == ast_id) ? get_ast_node_from_symbol(scope_stack, node->left->value.sval) : node->left;
    ASTNode* right_node = (node->right->type == ast_id) ? get_ast_node_from_symbol(scope_stack, node->right->value.sval) : node->right;

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
        
        default:
            break;   
    }

    /* free_node(left_node);
    free_node(right_node); */
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
        default:
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
            char* error_message = (char*)malloc(sizeof(char) * 100);
            sprintf(error_message, "Type Error: Expect '%s' but got '%s'", get_raw_data_type_from_ast_type(correct_type), get_raw_data_type_from_ast_type(actual_type));
            yyerror(error_message);
        }
    } else {
        // if node->type is ast_id, convert the actual_type based on the symbol type
        if(node->type == ast_id){
            ASTNode* tmp_node = get_ast_node_from_symbol(scope_stack, node->value.sval);
            if(tmp_node != NULL){
                actual_type = tmp_node->type;
                free_node(tmp_node);
            } else {
                yyerror("Variable not defined! In general_type_checking\n");
                exit(0);
            }
        }

        if(DEBUG_MODE && TYPE_CHECKING_DEBUG_MODE){
            printf("ACTUAL TYPE: %s\n", get_ast_type(actual_type));
            printf("CORRECT TYPE: %s\n", get_ast_type(correct_type));
        }

        if(actual_type != correct_type){
            char* error_message = (char*)malloc(sizeof(char) * 100);
            sprintf(error_message, "Type Error: Expect '%s' but got '%s'", get_raw_data_type_from_ast_type(correct_type), get_raw_data_type_from_ast_type(actual_type));
            yyerror(error_message);
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

    while(c == *str++){
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

SymbolEntry* lookup_symbol(ScopeStack* stack, char* name) {
    for (int i = stack->top; i >= 0; i--) {
        SymbolTable* table = stack->tables[i];
        unsigned int index = hash(name, table->size);
        SymbolEntry* entry = table->table[index];
        while (entry != NULL) {
            if (strcmp(entry->name, name) == 0) {
                return entry;
            }
            entry = entry->next;
        }
    }
    return NULL;
}

void insert_symbol(ScopeStack* stack, char* name, void* value, SymbolType type) {
    if(DEBUG_MODE){
        printf("INSERT SYMBOL\n");
        printf("SYMBOL NAME: %s\n", name);
        printf("SYMBOL VALUE: %d\n", *(int*)value);
        printf("SYMBOL TYPE: %s\n", get_symbol_type(type));
    }

    SymbolTable* table = stack->tables[stack->top];
    unsigned int index = hash(name, table->size);
    SymbolEntry* new_entry = create_symbol_entry(name, value, type);
    new_entry->next = table->table[index];
    table->table[index] = new_entry;
}

SymbolEntry* create_symbol_entry(char* name, void* value, SymbolType type){
    SymbolEntry* entry = malloc(sizeof(SymbolEntry));
    entry->name = strdup(name);
    if (type == symbol_function) {
        entry->func = (Function*)value;
    } else {
        entry->value = *(int*)value;
    }
    entry->type = type;
    entry->next = NULL;
    return entry;
}

ASTNode* get_ast_node_from_symbol(ScopeStack* stack, char* name){
    SymbolTable* table = stack->tables[stack->top];
    SymbolEntry* entry = lookup_symbol(stack, name);
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
            default:
                break;
        }
    } else {
        if(DEBUG_MODE){
            printf("variable name not fount: %s\n", name);
            print_scope_stack(stack);
        }
        yyerror("Variable not defined! In get_ast_node_from_symbol\n");
    }

    return NULL;
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

/**
 * ==================================================================================================
 *
 * Scope Stack
 *
 * ==================================================================================================   
 */
ScopeStack* create_scope_stack(int capacity){
    ScopeStack* stack = malloc(sizeof(ScopeStack));
    stack->tables = malloc(sizeof(SymbolTable*) * capacity);
    stack->top = -1;
    stack->capacity = capacity;
    return stack;
}

void push_scope_stack(ScopeStack* stack, SymbolTable* table){
    if(stack->top == stack->capacity - 1){
        yyerror("Scope stack overflow");
    }

    stack->tables[++stack->top] = table;
}

SymbolTable* pop_scope_stack(ScopeStack* stack){
    if(stack->top == -1){
        yyerror("Scope stack underflow");
    }

    return stack->tables[stack->top--];
}

void free_scope_stack(ScopeStack* stack){
    free(stack->tables);
    free(stack);
}


/**
 * ==================================================================================================
 * 
 * Others
 *
 * ==================================================================================================   
 */
char* get_ast_type(ASTType type){
    switch(type){
        case ast_root:
            return "ast_root";
        case ast_plus:
            return "ast_plus";
        case ast_minus:
            return "ast_minus";
        case ast_multiply:
            return "ast_multiply";
        case ast_divide:
            return "ast_divide";
        case ast_modulus:
            return "ast_modulus";
        case ast_greater:
            return "ast_greater";
        case ast_smaller:
            return "ast_smaller";
        case ast_equal:
            return "ast_equal";
        case ast_and:
            return "ast_and";
        case ast_or:
            return "ast_or";
        case ast_not:
            return "ast_not";
        case ast_boolean:
            return "ast_boolean";
        case ast_number:
            return "ast_number";
        case ast_function:
            return "ast_function";
        case ast_print_num:
            return "ast_print_num";
        case ast_print_bool:
            return "ast_print_bool";
        case ast_if_exp:
            return "ast_if_exp";
        case ast_if_body:
            return "ast_if_body";
        case ast_define:
            return "ast_define";
        case ast_id:
            return "ast_id";
        case ast_function_call:
            return "ast_function_call";
        case ast_function_params:
            return "ast_function_params";
        case ast_function_name:
            return "ast_function_name";
        case ast_function_body:
            return "ast_function_body";
        case ast_equals_to_parent:
            return "ast_equals_to_parent";
        case ast_function_ids:
            return "ast_function_ids";
        default:
            printf("type: %d\n", type);
            return "NOT_FOUND_TYPE";
    }
}

char* get_symbol_type(SymbolType type){
    switch(type){
        case symbol_number:
            return "symbol_number";
        case symbol_boolean:
            return "symbol_boolean";
        case symbol_function:
            return "symbol_function";
        default:
            return "NOT_FOUND_TYPE";
    }
}
char* get_raw_data_type_from_ast_type(ASTType type){
    switch(type){
        case ast_number:
            return "number";
        case ast_boolean:
            return "boolean";
        case ast_function:
            return "function";
        default:
            printf("type: %d\n", type);
            return "NOT_FOUND_TYPE";
    }
}


void print_symbol_table(SymbolTable* table){
    printf("========== SYMBOL TABLE ==========\n");
    bool is_empty = true;
    for(int i = 0; i < table->size; i++){
        SymbolEntry* entry = table->table[i];
        while(entry != NULL){
            printf("NAME: %s\n", entry->name);
            printf("VALUE: %d\n", entry->value);
            printf("SYMBOL TYPE: %d\n", entry->type);
            printf("\n");
            entry = entry->next;
            is_empty = false;
        }
    }
    if(is_empty){
        printf("EMPTY TABLE\n");
    }
}
void print_scope_stack(ScopeStack* stack){
    printf("\n========== SCOPE STACK ==========\n");
    for(int i = 0; i <= stack->top; i++){
        printf("SCOPE STACK INDEX: %d\n", i);
        print_symbol_table(stack->tables[i]);
    }
    printf("==================================\n\n");

}

void print_ast_tree(ASTNode* node){
    if(node == NULL){
        return;
    }

    // print in tree format
    printf("AST TYPE: %s\n", get_ast_type(node->type));
    printf("AST VALUE: %d\n", node->value.ival);
    // if left is not null, print left
    if(node->left != NULL){
        printf("LEFT\n");
        print_ast_tree(node->left);
    } else {
        printf("LEFT NULL\n");
    }

    // if right is not null, print right
    if(node->right != NULL){
        printf("RIGHT\n");
        print_ast_tree(node->right);
    } else {
        printf("RIGHT NULL\n");
    }

}

    
/**
 * ==================================================================================================
 *
 * Main and error handling
 *
 * ==================================================================================================   
 */
void yyerror(const char* message){
    fprintf(stderr, "%s\n", message);
    
    if(!DEBUG_MODE || (DEBUG_MODE && EXIT_WHEN_ERROR_IN_DEBUG_MODE)){
        // free the memory
        free_symbol_table(scope_stack->tables[scope_stack->top]);
        free_scope_stack(scope_stack);
        free_node(root);

        exit(0);
    } 
}

int main(){
    scope_stack = create_scope_stack(MAX_SCOPE_STACK_SIZE);
    SymbolTable* table = create_symbol_table(MAX_SYMBOL_TABLE_SIZE);
    push_scope_stack(scope_stack, table);

    yyparse();

    traverse_ast(root, ast_root);

    if(DEBUG_MODE){
        printf("\nAFTER TRAVERSE AST\n");
        print_scope_stack(scope_stack);
    }

    free_symbol_table(table);
    free_scope_stack(scope_stack);

    return 0;
}