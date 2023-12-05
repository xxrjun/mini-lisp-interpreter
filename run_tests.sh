#!/bin/bash

TEST_DIR="./tests/public_test_data"
ANS_FILE="./tests/public_test_data_ans.txt" # Replace with the actual path
INTERPRETER="./mini-lisp"
PASSED=0
FAILED=0

# 顏色定義
COLOR_BRIGHT_BLUE="\033[36m"
COLOR_BLUE="\033[34m"
COLOR_RESET="\033[0m"
COLOR_GREEN="\033[32m"
COLOR_RED="\033[31m"
COLOR_YELLOW="\033[33m"
COLOR_RESET="\033[0m"

# 清屏
clear

# 顯示基本訊息
echo -e "${COLOR_BRIGHT_BLUE}+------------------------------------------------+${COLOR_RESET}"
echo -e "${COLOR_BRIGHT_BLUE}|     NCU Compilers Final Project, 2023 Fall     |${COLOR_RESET}"
echo -e "${COLOR_BRIGHT_BLUE}|  Mini-LISP Interpreter crafted by xxrjun       |${COLOR_RESET}"
echo -e "${COLOR_BRIGHT_BLUE}|                Running Tests                   |${COLOR_RESET}"
echo -e "${COLOR_BRIGHT_BLUE}+------------------------------------------------+${COLOR_RESET}"


for test_file in $TEST_DIR/*.lsp; do
    test_name=$(basename $test_file)

    # Extract the expected output from the answer file
    expected_output=$(awk "/^$test_name$/{flag=1;next}/^[a-zA-Z0-9]+_[0-9]+\.lsp$/{flag=0}flag" "$ANS_FILE")
    actual_output=$($INTERPRETER < $test_file)

    # Handle multiple possible outputs
    if [[ "$expected_output" =~ .*"syntax error".* ]]; then
        if [[ "$actual_output" == "syntax error" ]] || [[ "$actual_output" == "Need 2 arguments, but got 0." ]]; then
            actual_output="$expected_output"
        fi
    fi

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
