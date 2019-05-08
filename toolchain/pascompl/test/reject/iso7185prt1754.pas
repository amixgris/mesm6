{

PRT test 1754: On reading an integer from a textfile, after skipping preceding
               spaces and end-of-lines, it is an error if the rest of the 
               sequence does not form a signed-integer.

               ISO 7185 reference: 6.9.1

}

program iso7185prt1754(output);

var a: text;
    b: integer;

begin

   rewrite(a);
   writeln(a, '      five       ');
   reset(a);
   read(a, b)

end.
