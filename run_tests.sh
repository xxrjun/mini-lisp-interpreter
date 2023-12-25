#!/bin/bash

IS_TEST_HIDENT=0 # TODO: 請修改成 1 以測試 hidden test
if [ "$IS_TEST_HIDDEN" -eq 1 ]; then
    TEST_DIR="./tests/hidden_test_data_2021"  # TODO: 請修改成你的測試資料夾路徑
    ANS_FILE="./tests/hidden_test_data_ans.txt" # TODO: 請修改成你的測試答案檔案路徑
else
    TEST_DIR="./tests/public_test_data"  # TODO: 請修改成你的測試資料夾路徑
    ANS_FILE="./tests/public_test_data_ans.txt" # TODO: 請修改成你的測試答案檔案路徑
fi
PROGRAM_NAME="minilisp"    # TODO: 請修改成你的執行檔名稱
INTERPRETER="./bin/$PROGRAM_NAME" # Interpreter 執行檔路徑
SRC="./src"
BIN="./bin"
PASSED=0
FAILED=0

# TODO: 可配置的編譯器和選項
CC="gcc" # 可以更改為 g++ 或其他編譯器
CFLAGS="-c -g -I.. -o"
LFLAGS="-ll" # link with flex library

# 顏色定義
COLOR_BRIGHT_BLUE="\033[36m"
COLOR_BLUE="\033[34m"
COLOR_RESET="\033[0m"
COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_YELLOW="\033[33m"

# 清屏
clear

# 顯示基本訊息
echo -e "${COLOR_BRIGHT_BLUE}+------------------------------------------------+${COLOR_RESET}"
echo -e "${COLOR_BRIGHT_BLUE}|                                                |${COLOR_RESET}"
echo -e "${COLOR_BRIGHT_BLUE}|     NCU Compilers Final Project, 2023 Fall     |${COLOR_RESET}"
echo -e "${COLOR_BRIGHT_BLUE}|  Mini-LISP Interpreter crafted by xxrjun       |${COLOR_RESET}"
echo -e "${COLOR_BRIGHT_BLUE}|                Running Tests                   |${COLOR_RESET}"
echo -e "${COLOR_BRIGHT_BLUE}|                                                |${COLOR_RESET}"
echo -e "${COLOR_BRIGHT_BLUE}|        Test Script created by @xxrjun          |${COLOR_RESET}"
echo -e "${COLOR_BRIGHT_BLUE}|                                                |${COLOR_RESET}"
echo -e "${COLOR_BRIGHT_BLUE}+------------------------------------------------+${COLOR_RESET}"

# 檢查 src 和 bin 目錄是否存在，若不存在則創建
mkdir -p $SRC
mkdir -p $BIN

# 選擇不同系統的指令
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux 系統的指令
    echo "Running on Linux"

    bison -d -o $SRC/${PROGRAM_NAME}.tab.c $SRC/${PROGRAM_NAME}.y
    $CC $CFLAGS $SRC/${PROGRAM_NAME}.tab.o $SRC/${PROGRAM_NAME}.tab.c
    lex -o $SRC/lex.yy.c $SRC/${PROGRAM_NAME}.l
    $CC $CFLAGS $SRC/lex.yy.o $SRC/lex.yy.c
    $CC -o $BIN/${PROGRAM_NAME} $SRC/${PROGRAM_NAME}.tab.o $SRC/lex.yy.o $LFLAGS
elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS 系統的指令
    echo "Running on macOS"
    
    bison -d -o $SRC/${PROGRAM_NAME}.tab.c $SRC/${PROGRAM_NAME}.y
    $CC $CFLAGS $SRC/${PROGRAM_NAME}.tab.o $SRC/${PROGRAM_NAME}.tab.c
    lex -o $SRC/lex.yy.c $SRC/${PROGRAM_NAME}.l
    $CC $CFLAGS $SRC/lex.yy.o $SRC/lex.yy.c
    $CC -o $BIN/${PROGRAM_NAME} $SRC/${PROGRAM_NAME}.tab.o $SRC/lex.yy.o $LFLAGS

elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]]; then
    # Windows 系統的指令 (使用 Cygwin 或 Git Bash)
    echo "Running on Windows (Cygwin or Git Bash)"

    bison -d -o $SRC/${PROGRAM_NAME}.tab.c $SRC/${PROGRAM_NAME}.y
    $CC $CFLAGS $SRC/${PROGRAM_NAME}.tab.o $SRC/${PROGRAM_NAME}.tab.c
    flex -o $SRC/lex.yy.c $SRC/${PROGRAM_NAME}.l
    $CC $CFLAGS $SRC/lex.yy.o $SRC/lex.yy.c
    $CC -o $BIN/${PROGRAM_NAME}.exe $SRC/${PROGRAM_NAME}.tab.o $SRC/lex.yy.o

else
    echo "Unknown operating system"
fi

# # 如果編譯失敗，則退出
# if [ $? -ne 0 ]; then
#     echo -e "${COLOR_RED}Failed to compile the program.${COLOR_RESET}"
#     exit 1
# fi

# 測試
for test_file in $TEST_DIR/*.lsp; do
    test_name=$(basename $test_file)

    # Extract the expected output from the answer file
    if [ "$IS_TEST_HIDDEN" == 1 ]; then
        expected_output=$(awk "/^$test_name$/{flag=1;next}/^[a-zA-Z0-9]+_[0-9]+_hidden\.lsp$/{flag=0}flag" "$HIDDEN_ANS_FILE") # hidden test
    else
        expected_output=$(awk "/^$test_name$/{flag=1;next}/^[a-zA-Z0-9]+_[0-9]+\.lsp$/{flag=0}flag" "$ANS_FILE")
    fi
    
    # Run the program
    if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
        actual_output=$($INTERPRETER < $test_file 2>&1)
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]]; then
        actual_output=$($INTERPRETER.exe < $test_file 2>&1)
    else
        echo "Unsupported operating system to run tests: $OSTYPE"
        exit 1
    fi

    expected_output=$(echo "$expected_output" | tr -d '\r')
    actual_output=$(echo "$actual_output" | tr -d '\r')

    echo -e "\033[36mTest: $test_name\033[0m"

    if [ "$expected_output" == "$actual_output" ]; then
        echo -e "\033[32mResult: PASS\033[0m"
        ((PASSED++))
    else
        echo -e "${COLOR_RED}Result: FAIL${COLOR_RESET}"
        echo "Expected Output:"
        echo -e "${COLOR_RED}$expected_output${COLOR_RESET}"
        echo "Actual Output:"
        echo -e "${COLOR_RED}$actual_output${COLOR_RESET}"
        ((FAILED++))
    fi

    echo -e "\033[35m-----------------------------------\033[0m"
done

echo -e "${COLOR_YELLOW}Tests completed.${COLOR_RESET} ${COLOR_GREEN}Passed: $PASSED${COLOR_RESET}, ${COLOR_RED}Failed: $FAILED${COLOR_RESET}"

# 清除除了執行檔外的所有生成檔案
rm -f $SRC/*.tab.c $SRC/*.tab.h $SRC/*.yy.c $SRC/*.output $SRC/*.o
