There are only around 40-50 free opcodes in CLC-INTERCAL, so it's good to try not to waste them. CLC-INTERCAL provides a mechanism to add new register types, but it's very limited. 
Nevertheless, I created a single opcode (78/DRT) which can handle up to 65535 register types including the base types.

# Installation
Put the files named like `DynamicRegTypes/[module].pm` into one of perl's `@INC` directories in `Language/INTERCAL/` (you can find out what these are by running `perl -E 'print "@INC";'` in your shell).
Then, to use the test register type, copy `reg_add` in the examples folder to your current directory, run `sick reg_add.iacc`, then `sick -Apreg_add your-program` to compile your program, or 
`sick -Apreg_add -lRun your-program` to run it immediately. (Version 1.0 generates a lot of warnings at this step that don't really matter; this version silences them so it doesn't clog up your terminal).


The examples directory shows various uses of the test register type.

Note that this was tested with the CLC-INTERCAL 32-bit Character Limit variation. It should work fine normally, but if it doesn't, try using that.

# How to add more types
`DynamicRegTypes/Extend.pm` is the main driver. You can load it in an extension by saying:
```
DO ?TYPE <- ?EXTENSION
DO ?LOAD_DynamicRegTypes <- ?DYNAMIC_REGISTER_TYPES
```
at the top of a .iacc file. `Extend.pm` has a line saying `my @imports = ("RegAddable");`. If you want to add more register types, add your module name (
implicitly prefixed with `Language::INTERCAL::DynamicRegTypes`) in a new pair of quotes inside the parentheses, separating it from other names with a comma. 
The module should contain a method called `setup`, taking in three arguments, an array reference containing array references (the index is the type on the 
left side of assignment) containing array references (the index is the type 
on the right side of assignment) containing subroutine references (custom code to run when assigning), an array
reference of array references (the index is the type) containing a single value (the default value for a new register
of the type), and a scalar reference to either 0 or 1 (default 1). The boolean determines whether the checks
for using arrays, classes, and compilers as values will NOT be bypassed. If this is set to 1, which is the default,
the only types you'll be able to use on the right side are spot, twospot, double-oh-seven (which is automatically
converted to spot), and custom types. Setting this to zero will enable you to use arrays, whirlpool, and crawling horror registers on the right side.

An example of all of this is provided in `DynamicRegTypes/RegAddable.pm`.

# Opcode
The opcode to access a custom register is a bit weird. The opcode number is 78 and the name is DRT. It takes either #0 or #1 as a constant, 
if #1, two expressions should follow, one for the type and one for the value. It then takes a count (which can be zero), then takes that
many statements. To determine the opcode, the default is type 1 value 1, or `.1`. Then, if the expressions are present, the type and value
are set to them, overwriting the `.1`. 
If statements are also present, they set the type and value based on the following process, overwriting both the initial `.1` and stuff
added by the expressions if they were there:
- `.1` and `.2` are STASHED
- The statements are run
- `.1` is taken as the type, `.2` as the value
- `.1` and `.2` are RETRIEVED.

These statements cannot contain labels, initial abstention, double-oh-seven execution, `ONCE`, or `AGAIN`. If you want/need a loop to calculate
a register, you can either call a lecture, NEXT to a label, or install [my looping module](https://github.com/kronosta/esolangs/blob/main/CLC-INTERCAL/Language/INTERCAL/Looping/Extend.pm) and use the 50/LOP opcode.

# Functionality
Here is what works with registers of custom types:
- Assignment
- BELONGing
- ENROLment and LEARNing
- The `+reg-reg` syntax for indirect registers
- Overloading
- Stashing and retrieving

Here is what doesn't work:
- READ OUT/WRITE IN
- IGNORE/REMEMBER
- TRICKLE DOWN/TRUSS UP
