# asm-calc
10-digit calculator written in 8052 assembly for the CV-8052 soft processor, using a 16-key keypad for input and 7-segment displays on the DE0-CV boards for output.  It supports basic arithmetic, a right-triangle solver, persistent results, and error handling for invalid operations or overflow conditions.

# Overview
The calculator operates on unsigned 32-bit integers (decimal input/output) and supports:
- Addition (A)
- Subtraction (B)
- Multiplication (*)
- Division (D)
- Right Triangle Solver (C)
- Equals (#)
- Digit input (0–9)

It is designed to behave like a simple handheld calculator, with continuous calculations and persistent results.

# Hardware Setup
## Required Components
- DE0-CV with CV-8052
- 16-key membrane keypad

## Keypad Wiring
Keypad is connected to GPIO header JP2:
- P1.2, P1.4, P1.6
- P2.0, P2.2, P2.4, P2.6
- P3.0

# How to Build and Run
In the project folder:
- Assemble the 8052 assembly to machine code
  ```
  ./a51 -l calc.asm
  ```
- Upload the program to the CV-8052 soft processor
  ```
  ./pdex -p/dev/tty.[NAME OF USB SERIAL CONNECTION] calc.hex
  ```

# How to Use the Calculator
## Entering Numbers
- Press digits 0–9 to build a number
- Numbers are displayed on HEX0–HEX5 (right-aligned)
- Up to 10 digits total input

Example:
```
Input: 1234
Display: 0000_001234
```
If digits exceed display capacity, LEDR7 turns ON (overflow display indicator for digits beyond visible range)

## Selecting Operations
| Key | Operation             |
| --- | --------------------- |
| A   | Addition              |
| B   | Subtraction           |
| *   | Multiplication        |
| D   | Division              |
| C   | Right Triangle Solver |
| #   | Equals (=)            |

Example: Addition

To compute:
```
1234 + 5678
```

Input sequence:
```
1 2 3 4   (display: 0000_001234)
A         (display: 0000_000000)
5 6 7 8   (display: 0000_005678)
#         (display: 0000_006912)
```

## Chained Calculations

The result becomes the new stored value.

Example:
```
Result: 0000_006912
Press: B
Then: 1
Then: #
```
Behavior:
- Operator clears entry buffer
- New input overwrites display (not appended)
- Ensures correct calculator-style operation

## Right Triangle Solver (C)

Supports two modes controlled by SW1:

Mode A:
```
C = sqrt(A² + B²)
```

Mode B:
```
B = sqrt(C² - A²)
```

Triangle Solver Rules
- Inputs must be positive integers
- If computed value under square root is negative:
  - Display result as positive
  - Turn LEDR0 ON (error/invalid geometry flag)

## Error Handling
The calculator displays "Error" for:

1. Division by zero
    - Attempting x / 0
2. Decimal overflow (input too large)
    - Any number exceeding `2^32 - 1 = 4,294,967,295`
3. Arithmetic overflow
    - Addition overflow
    - Multiplication overflow
4. Invalid triangle condition
    - Hypotenuse < one of the sides

## Reset / New Input Behavior
After a calculation:
- Pressing any digit 0–9:
  - Clears previous result
  - Starts fresh input

Example:
```
Previous: 0000_000123
Press: 1
New:     0000_000001   (NOT appended)
```
