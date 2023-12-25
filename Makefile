# Define compiler and other variables
CC = gcc
BISON = bison
FLEX = flex
CFLAGS = -g -I..
DEPFLAGS = -MMD -MP

# Define directory paths
SRC_DIR = src
BIN_DIR = bin

# Program Name
PROGRAM = minilisp

# Target executable
TARGET = $(BIN_DIR)/$(PROGRAM)

# Bison and Flex source and output files
BISON_SRC = $(SRC_DIR)/$(PROGRAM).y
BISON_OUT = $(SRC_DIR)/$(PROGRAM).tab.c
BISON_HEADER = $(SRC_DIR)/$(PROGRAM).tab.h
FLEX_SRC = $(SRC_DIR)/$(PROGRAM).l
FLEX_OUT = $(SRC_DIR)/lex.yy.c

# Object files
OBJECTS = $(BISON_OUT:.c=.o) $(FLEX_OUT:.c=.o)
DEPENDENCIES = $(OBJECTS:.o=.d)

# Default target
all: $(TARGET)

# Bison rule
$(BISON_OUT) $(BISON_HEADER): $(BISON_SRC)
	$(BISON) -d -o $(BISON_OUT) $<

# Flex rule
$(FLEX_OUT): $(FLEX_SRC) $(BISON_HEADER)
	$(FLEX) -o $@ $<

# Compile .c files
$(SRC_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) -c $(CFLAGS) $(DEPFLAGS) $< -o $@

# Generate executable
$(TARGET): $(OBJECTS)
	$(CC) -o $@ $^

# Clean generated files
clean:
	rm -rf $(OBJECTS) $(DEPENDENCIES) $(BISON_OUT) $(BISON_HEADER) $(FLEX_OUT)

# Include generated dependencies
-include $(DEPENDENCIES)

.PHONY: all clean
