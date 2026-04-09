# 🚀 Error Diagnostic System for Lexical, Syntax, and Semantic Analysis

## 📌 Overview
This project implements a **compiler front-end error diagnostic system** that detects and reports errors during different phases of compilation:

- Lexical Analysis  
- Syntax Analysis  
- Semantic Analysis  

It is built using **Lex (Flex)** and **Yacc (Bison)** to simulate how real compilers identify and handle errors in source code.

---

## 🎯 Objectives
- Detect **lexical errors** (invalid tokens, illegal identifiers)
- Identify **syntax errors** (incorrect grammar, missing symbols)
- Perform **semantic analysis** (type checking, scope validation)
- Generate meaningful and user-friendly error messages
- Maintain a **symbol table** for tracking identifiers

---

## 🛠️ Tech Stack
- **C Programming Language**
- **Lex / Flex**
- **Yacc / Bison**
- **GCC Compiler**

---

## 🧠 Compiler Phases

### 1. Lexical Analysis
- Breaks input into tokens
- Identifies keywords, operators, identifiers

### 2. Syntax Analysis
- Validates structure using grammar rules
- Detects syntax errors

### 3. Semantic Analysis
- Type checking
- Scope resolution
- Symbol table management

---

## 📁 Project Structure
```
├── assgn3.l        # Lex file (Lexical Analyzer)
├── assgn3.y        # Yacc file (Syntax Analyzer)
├── lex.yy.c        # Generated file
├── a.out           # Executable file
├── test_doc.pdf    # Sample test cases
└── README.md
```

---

## ⚙️ How to Run

### Step 1: Generate Lex Code
```bash
lex assgn3.l
```

### Step 2: Compile
```bash
gcc lex.yy.c -lfl
```

### Step 3: Run
```bash
./a.out
```

---

## 🔍 Features
- ✔ Invalid token detection  
- ✔ Syntax validation using grammar rules  
- ✔ Semantic checks:
  - Type mismatch detection  
  - Undeclared variables  
  - Scope handling  
- ✔ Symbol Table with identifier details  

---

## 📊 Example Errors Detected
- Using undeclared variables  
- Type mismatch in expressions  
- Invalid syntax structures  
- Incorrect function usage  

---

## 📚 Learning Outcomes
- Understanding of compiler design basics  
- Hands-on experience with Lex & Yacc  
- Implementation of error detection system  
- Symbol table construction  

---

## 🚧 Future Improvements
- Better error recovery mechanisms  
- Line & column-based error reporting  
- Intermediate code generation  
- Optimization techniques  

---

## 🤝 Contributing
Contributions are welcome! Feel free to fork the repository and submit a pull request.

---

## 📜 License
This project is for educational purposes and free to use.
