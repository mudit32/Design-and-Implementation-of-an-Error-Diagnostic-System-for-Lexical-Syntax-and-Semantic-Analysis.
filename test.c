// Test file 2: Basic declarations, assignments, and expressions
int x@; // Invalid character '@'
float y;
x = 5;
y = 3.14;
int z = x + 10;
float w = y * 2.0;

// Test variables with typos for Autocorrect
float myFloat = 1.23;
int myInt = 4;

// Testing Arrays
int arr[10];
arr[0] = 5;
arr[1] = x + arr[0];

// Testing 'while' loops
while(x < 10) {
    x = x + 1;
}

// Testing 'for' loops
int i;
for(i = 0; i < 10; i = i + 1) {
    arr[i] = i * 2;
}

// Testing if-else logic inside blocks
if (x == 10) {
    x = 0;
} else {
    x = 1;
}

// Testing print and input statements
printf("Enter a number: ");
int userInput;
scanf("%d", &userInput);
printf("You entered:", userInput);

// Invalid: undeclared variable
undeclared = 10;

// Invalid: type mismatch
int num;
num = "string";