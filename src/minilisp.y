%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    
    #define bool int
    #define true 1
    #define false 0

    #define DEBUG_MODE 0
    #define TYPE_CHECKING_DEBUG_MODE 0
    
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
    void traverse_ast(ASTNode* root, ASTType prev_type, bool is_in_function); // 多一個參數，用來判斷是否在function裡面
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
%type<nval> fun_exp fun_call fun_body fun_name params param last_exp fun_ids ids
%type<nval> if_exp test_exp then_exp else_exp

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

fun_body    : exp
            ;

fun_call    : LPAREN fun_exp params RPAREN      { $$ = new_node(ast_function_call, $2, $3); }
            | LPAREN fun_name params  RPAREN    { $$ = new_node(ast_function_call, $2, $3); }
            ;

params      : param params                      { $$ = new_node(ast_function_params, $1, $2); }
            | 
            ;

param       : exp
            ;

last_exp    : exp
            ;

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
        printf("NODE VALUE: %s\n", sval);
    }

    ASTNode* node = (ASTNode*)malloc(sizeof(struct ASTNode));
    node->type = ast_id; 
    node->value.sval = strdup(sval); // to prevent be affected by changes in the original string 
    node->left = left;
    node->right = right;

    if(DEBUG_MODE){
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
        printf("FUNCTION PARAMS: %s\n", fun_ids->left->value.sval);
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
        return;
    }

    if(args == NULL){
        yyerror("Invalid number of arguments!");
        exit(0);
    }

    // bind the parameters to the scope
    int index = 0;
    ASTNode* current = args;
    while (current != NULL && current->left != NULL && index < param_count) {
        insert_symbol(stack, params[index++], &(current->left->value.ival), symbol_number);
        current = current->right;
    }

    if(DEBUG_MODE){
        printf("BIND PARAMETERS TO SCOPE DONE\n");
    }
}


void traverse_ast(ASTNode* node, ASTType prev_type, bool is_in_function){
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

  
    /* traverse_ast(node->left, node->type, is_in_function);
    traverse_ast(node->right, node->type, is_in_function); */

    switch(node->type){
        case ast_root:
            if(DEBUG_MODE){
                printf("AST ROOT\n");
            }
            traverse_ast(node->left, node->type, is_in_function);
            traverse_ast(node->right, node->type, is_in_function);
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
            traverse_ast(node->left, node->type, is_in_function);
            traverse_ast(node->right, node->type, is_in_function);
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
            traverse_ast(node->left, node->type, is_in_function);
            traverse_ast(node->right, node->type, is_in_function);
            handle_logical_operation(node, node->type);
            break;


        /**
         * ----------------------------- Print Functions -----------------------------
         */
        case ast_print_bool:
            if(DEBUG_MODE){
                printf("AST PRINT BOOL\n");
            }
            traverse_ast(node->left, node->type, is_in_function);
            traverse_ast(node->right, node->type, is_in_function);
            ASTNode* print_bool_node = node->left->type == ast_id ? 
                                        get_ast_node_from_symbol(scope_stack, node->left->value.sval) : node->left;
            
            general_type_checking(print_bool_node, ast_boolean);
            printf("%s\n", print_bool_node->value.bval ? "#t" : "#f");
            free_node(node);
            break;
        
        case ast_print_num:
            if(DEBUG_MODE){
                printf("AST PRINT NUM.\n");
            }
            traverse_ast(node->left, node->type, is_in_function);
            traverse_ast(node->right, node->type, is_in_function);
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
                printf("AST IF EXP. IF EXP VALUE: %s\n", node->left->value.bval ? "#t" : "#f");
            }
            traverse_ast(node->left, node->type, is_in_function);
            traverse_ast(node->right, node->type, is_in_function);

            ASTNode* if_condition_node = node->left;
            general_type_checking(if_condition_node, ast_boolean);

            ASTNode* if_body_node = node->right;
            general_type_checking(if_body_node, ast_if_body);

            if(if_condition_node->value.bval) {
                node->value.ival = if_body_node->left->value.ival;
            }
            else {
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
            }
            traverse_ast(node->left, node->type, is_in_function);
            traverse_ast(node->right, node->type, is_in_function);
            // TODO: it will be able to handle functions and variables, but for now it only handles variables.
        
            // check if variable is already defined
            // if it is, return with error (not in project requirements, but I think it should be)
            // if not, insert it in the symbol table
            ASTNode* variable_name_node = node->left;
            general_type_checking(variable_name_node, ast_id);

            ASTNode* value_node = node->right;

            if(lookup_symbol(scope_stack, variable_name_node->value.sval) != NULL){
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
                int value = value_node->value.ival; // Store the integer value in a local variable
                insert_symbol(scope_stack, variable_name_node->value.sval, &value, value_type);

            }
            
            break;
        
        /**
         * ----------------------------- Functions -----------------------------
         */
        
        case ast_function:
            // create a function structure
            // push the function in the symbol table
            if(DEBUG_MODE){
                printf("AST FUNCTION\n");
            }

            ASTNode* function_ids_node = clone_ast(node->left);
            ASTNode* function_body_node = clone_ast(node->right);

            // create a function structure
            Function* func = create_function("", function_ids_node, function_body_node);

            // insert the function in the symbol table
            insert_symbol(scope_stack, func->name, func, symbol_function);

            break;
        
        case ast_function_call:
            if(DEBUG_MODE){
                printf("AST FUNCTION CALL\n");
            }

            // the left of ast_function_call node is either a ast_function_exp or a ast_function_name
            // the right of ast_function_call node is a ast_function_params
            
            // the left of ast_function_exp is a ast_function_ids
            // the right of ast_function_exp is a ast_function_body

            if(node->left->type == ast_function){
                if(DEBUG_MODE){
                    /* print_ast_tree(node->left); */
                }
                // 1. anonymous function
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

                    // bind the parameters to the scope
                    bind_parameters_to_scope(func->params, node->right, scope_stack, func->param_count);
                    // traverse the function body
                    traverse_ast(function_body_node, ast_root, true);


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
            } else {
                yyerror("Invalid function call!");
            }

            break;
        default:
            if(DEBUG_MODE){
                /* printf("AST DEFAULT: %s\n", get_ast_type(node->type)); */
            }
            traverse_ast(node->left, node->type, is_in_function);
            traverse_ast(node->right, node->type, is_in_function);
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
            yyerror("Type error!");
            exit(0);
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

/* SymbolEntry* lookup_symbol(SymbolTable* table, char* name){
    unsigned int index = hash(name, table->size);
    SymbolEntry* entry = table->table[index];
    while(entry != NULL){
        if(strcmp(entry->name, name) == 0){
            return entry;
        }
        entry = entry->next; // collision
    }
    return NULL;
} */


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
    SymbolEntry* entry = lookup_symbol(stack, name);
    if(entry != NULL){
        if (type == symbol_function) {
            entry->func = (Function*)value;
        } else {
            entry->value = *(int*)value;
        }
        entry->type = type;
    }
    else{
        unsigned int index = hash(name, table->size);
        SymbolEntry* new_entry = create_symbol_entry(name, value, type);
        new_entry->next = table->table[index];
        table->table[index] = new_entry;
    }
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


/* void insert_symbol(ScopeStack* stack, char* name, int value, SymbolType type) {
    SymbolTable* table = stack->tables[stack->top];
    SymbolEntry* entry = lookup_symbol(stack, name);
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

SymbolEntry* create_symbol_entry(char* name, int value, SymbolType type){
    SymbolEntry* entry = malloc(sizeof(SymbolEntry));
    entry->name = strdup(name);
    entry->value = value;
    entry->type = type;
    entry->next = NULL;
    return entry;
} */

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
        printf("name: %s\n", name);
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
        yyerror("Stacak overflow");
    }

    stack->tables[++stack->top] = table;
}

SymbolTable* pop_scope_stack(ScopeStack* stack){
    if(stack->top == -1){
        yyerror("stack underflow");
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


void print_symbol_table(SymbolTable* table){
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
void print_scope_stack(ScopeStack* stack){
    printf("========== SCOPE STACK ==========\n");
    for(int i = 0; i <= stack->top; i++){
        printf("SCOPE STACK INDEX: %d\n", i);
        print_symbol_table(stack->tables[i]);
    }
    printf("==================================\n");

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
    
    if(!DEBUG_MODE){
        exit(0);
    }
}

int main(){
    scope_stack = create_scope_stack(MAX_SCOPE_STACK_SIZE);
    SymbolTable* table = create_symbol_table(MAX_SYMBOL_TABLE_SIZE);
    push_scope_stack(scope_stack, table);

    yyparse();

    traverse_ast(root, ast_root, false);

    if(DEBUG_MODE){
        print_scope_stack(scope_stack);
    }

    free_symbol_table(table);

    return 0;
}