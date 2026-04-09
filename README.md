# 🚀 Error Diagnostic System for Lexical, Syntax, and Semantic Analysis

## 📌 Overview
This project implements a compiler front-end error diagnostic system using Lex and Yacc to detect errors in:
- Lexical Analysis  
- Syntax Analysis  
- Semantic Analysis  

---

## 🛠️ Tech Stack
- C Programming Language  
- Lex / Flex  
- Yacc / Bison  
- GCC Compiler  

---

## 📁 Project Structure
├── lexer.l      # Lex file (Lexical Analyzer)

├── parser.y     # Yacc file (Syntax Analyzer)

├── test.c       # Input test program

├── compiler     # Executable

└── README.md

---

## ⚙️ How to Run

### Generate parser
yacc -d parser.y

### Generate lexer
lex lexer.l

### Compile
gcc lex.yy.c y.tab.c -o compiler -lfl

### Run
./compiler < test.c

---

## 🔍 Features
- Lexical error detection  
- Syntax validation  
- Basic semantic analysis  
- Symbol table handling  

---

## 📚 Learning Outcomes
- Compiler design basics  
- Working with Lex & Yacc  
- Error detection techniques  

---

## 📜 License
For educational use.
